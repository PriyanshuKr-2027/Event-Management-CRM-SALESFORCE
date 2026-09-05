# Event Organizer Workflow & Dashboard Architecture

> **Module:** Event Organizer Experience & Operational Lifecycle  
> **Source of Truth:** `classes/OrganizerDashboardController.cls`, `flows/Event_Creation_Screen_Flow.flow-meta.xml`, `classes/EventApprovalService.cls`, `objects/Event__c/`, `objects/Ticket_Type__c/`  
> **Target Audience:** Technical Reviewers, Evaluators, and Viva Examiners

---

## 1. Executive Summary & Flow Diagram

The **Event Organizer** persona is responsible for the core operational lifecycle of events: creating events, selecting venues, establishing dynamic pricing tiers, requesting budget approvals, publishing approved events, and monitoring ticket sales in real-time.

```
                         EVENT ORGANIZER
                                │
                                ▼
                       SALESFORCE LOGIN
                                │
                                ▼
                      ORGANIZER DASHBOARD
             (LWC: organizerDashboard / with sharing)
                                │
                         [+ CREATE EVENT]
                                │
                                ▼
                   EVENT CREATION SCREEN FLOW
                (Event_Creation_Screen_Flow)
                                │
     ┌──────────────────────────┼──────────────────────────┐
     ▼                          ▼                          ▼
  Step 1: Details            Step 2: Dates              Step 3: Venue
  - Event Name               - Start Date/Time          - Select Facility
  - 9 Categories Picklist    - End Date/Time            - Venue Capacity Limit
  - Description              - Future Date Guard        - Physical Safety Check
     │                          │                          │
     └──────────────────────────┼──────────────────────────┘
                                │
                                ▼
                 Step 4: Dynamic Ticket Tiers
               (LWC: ticketTypeCollector in Flow)
                                │
              ┌─────────────────┴─────────────────┐
              ▼                                   ▼
        Add Ticket Type                    Add Another Tier
        - Tier Name (VIP/General)          - Quota & Price
        - Price (₹)                        - Dynamic Totals
        - Quota Allocation                 - Live Capacity Calculation
                                │
                                ▼
                 Step 5: Proposed Budget Entry
             (Captures Proposed_Budget__c for routing)
                                │
                                ▼
                  Step 6: Review & Final Submit
                                │
                                ▼
            DYNAMIC MULTI-TIER APPROVAL ENGINE EVALUATION
             (Approval_Matrix__mdt / EventApprovalService)
                                │
          ┌─────────────────────┼─────────────────────┐
          ▼                     ▼                     ▼
      [TIER 1]              [TIER 2]              [TIER 3]
  Budget <= Auto_Limit   Auto < Budget <=      Budget > Manager_Limit
  (e.g. Meetup <= ₹50K,  Manager_Limit         (Requires Finance
   Concert <= ₹3L)       (Routed to Manager)    Executive Signoff)
          │                     │                     │
          ▼                     ▼                     ▼
    AUTO-APPROVED        PENDING APPROVAL      PENDING APPROVAL
          │              (Manager Review)     (Finance Exec Review)
          │                     │                     │
          │              ┌──────┴──────┐       ┌──────┴──────┐
          │              ▼             ▼       ▼             ▼
          │           APPROVE       REJECT  APPROVE       REJECT
          │              │             │       │             │
          │              └──────┬──────┘       └──────┬──────┘
          │                     │                     │
          │                     ▼                     ▼
          │         ┌─────────────────────┐           │
          │         │ Rejection Reason    │           │
          │         │ Mandatory Feedback  │           │
          │         └──────────┬──────────┘           │
          │                    │                      │
          │             ┌──────┴──────┐               │
          │             ▼             ▼               │
          │      EDIT & RESUBMIT  CANCEL EVENT        │
          │             │             │               │
          │             ▼             ▼               │
          │      Modify Budget   [CANCELLED]          │
          │      & Re-evaluate                        │
          │             │                             │
          └─────────────┼─────────────────────────────┘
                        │
                        ▼
              [APPROVED FOR PUBLICATION]
                        │
                        ▼
              ORGANIZER PUBLISHES EVENT
            (Publication_Status__c = 'Published')
            (Registration_Status__c = 'Open')
                        │
                        ▼
          PRICING & QUOTA LOCKED (Validation Rules)
                        │
                        ▼
           PUBLIC PORTAL DISCOVERY & BOOKING
```

---

## 2. Event Creation Screen Flow (`Event_Creation_Screen_Flow`)

Organizers initiate event creation directly from the **Organizer Dashboard** by clicking the primary action **`[+ Create Event]`**, which launches the guided Screen Flow.

### Step 1: Basic Event Information
- **Event Name:** Required text field (e.g. *AWS Community Day India 2026*).
- **Category:** Picklist supporting **9 enterprise categories**:
  - `Conference`, `Workshop`, `Training`, `Hackathon`, `Concert`, `Executive Summit`, `Webinar`, `Meetup`, `Other`.
  - The selected category directly determines the budget threshold routing in the dynamic approval engine.
- **Description:** Rich long text area detailing agenda, keynotes, and prerequisites.

### Step 2: Date & Time Scheduling
- **Start Date/Time:** Must be scheduled in the future (`ISNEW() && Start_Date_Time__c < NOW()` validation guard).
- **End Date/Time:** Must be strictly after Start Date/Time (`Start_Date_Time__c >= End_Date_Time__c` validation rule).

### Step 3: Venue Reservation
- Lookup to active `Venue__c` facilities.
- Displays venue address, city, and **physical venue capacity** (`Venue_Capacity__c`).
- Acts as the safety ceiling for total ticket allocations.

### Step 4: Dynamic Ticket Tier Collector (Embedded LWC)
Embedded inside the Screen Flow using custom Lightning Web Component `ticketTypeCollector`:
- Allows the organizer to add $N$ dynamic ticket tiers (e.g. *Early Bird ₹1,200*, *Standard ₹2,500*, *VIP Pass ₹6,000*).
- For each tier, captures:
  - **Tier Name** (`Name`)
  - **Ticket Price** (`Price__c` in ₹)
  - **Quota Allocation** (`Quota__c`)
  - **Description** (`Description__c`)
- **Live Aggregation Guard:** The component dynamically aggregates the sum of quotas. If `SUM(Quotas) > Venue_Capacity__c`, an immediate warning prevents over-allocation.

### Step 5: Proposed Budget
- Captures `Proposed_Budget__c` in ₹.
- Mandatory field required before submission (`Budget_Required_On_Submit` validation rule).

### Step 6: Confirmation & Creation
- Creates the `Event__c` record and atomic child `Ticket_Type__c` records.
- Automatically calculates `Total_Capacity__c` via declarative Roll-Up Summary on `Event__c`.

---

## 3. Dynamic Multi-Tier Category Approval Engine

Rather than relying on a single static threshold, the system evaluates the proposed event using **`Approval_Matrix__mdt`** via `EventApprovalService.cls`:

### Category Threshold Matrix:

| Category | Auto-Approve Ceiling | Manager Approval Limit | Executive / Finance Escalation |
| :--- | :---: | :---: | :---: |
| **Concert** | $\le$ ₹3,00,000 | $\le$ ₹15,00,000 | > ₹15,00,000 *(Requires Finance Signoff)* |
| **Conference** | $\le$ ₹2,50,000 | $\le$ ₹10,00,000 | > ₹10,00,000 *(Requires Finance Signoff)* |
| **Hackathon** | $\le$ ₹1,50,000 | $\le$ ₹5,00,000 | > ₹5,00,000 *(Requires Finance Signoff)* |
| **Workshop** | $\le$ ₹1,00,000 | $\le$ ₹3,00,000 | > ₹3,00,000 *(Requires Finance Signoff)* |
| **Training** | $\le$ ₹1,00,000 | $\le$ ₹3,00,000 | > ₹3,00,000 *(Requires Finance Signoff)* |
| **Meetup** | $\le$ ₹50,000 | $\le$ ₹1,50,000 | > ₹1,50,000 *(Requires Finance Signoff)* |
| **Webinar** | $\le$ ₹30,000 | $\le$ ₹1,00,000 | > ₹1,00,000 *(Requires Finance Signoff)* |
| **Executive Summit** | ₹0 *(Always Review)* | $\le$ ₹5,00,000 | > ₹5,00,000 *(Requires Finance Signoff)* |
| **Other** | $\le$ ₹50,000 | $\le$ ₹2,00,000 | > ₹2,00,000 *(Requires Finance Signoff)* |

### Routing Outcomes:
1. **Tier 1 (Zero-Touch Auto-Approval):**
   - If Budget $\le$ `Auto_Approve_Limit__c`, status is immediately set to `Approved`.
   - The organizer can proceed to publish the event without managerial delay.
2. **Tier 2 (Manager Approval Required):**
   - Status set to `Pending Approval`.
   - Routed to the **Event Manager** via the standard Salesforce Approval Process.
   - Event record is locked against modifications during review.
3. **Tier 3 (Finance Executive Escalation):**
   - High-budget events automatically flag `Requires_Finance_Signoff__c = true`.
   - Routed to Senior Management / Finance for financial risk assessment.
4. **Rejection Handling:**
   - If rejected, the approver must supply a mandatory `Rejection_Reason__c` (`Rejection_Reason_Required` validation rule).
   - The organizer receives an alert with the feedback.
   - The organizer can modify the budget/details and resubmit, or cancel the event (`Approval_Status__c = 'Cancelled'`).

---

## 4. Publication & Inventory Protection

### 1. Separation of Approved vs. Published
In enterprise Salesforce governance, **Approved $\ne$ Published**:
- An event can be `Approved` internally while logistics, speaker arrangements, and sponsorship deals are finalized.
- When ready, the organizer clicks **"Publish Event"**, setting `Publication_Status__c = 'Published'` and `Registration_Status__c = 'Open'`.
- Enforced by validation rule: `No_Publish_Before_Approved`.

### 2. Lockout on Ticket Types Once Registration Opens
To protect registered consumers from bait-and-switch pricing or sudden seat cancellations:
- **Price Locked:** `No_Price_Change_After_Registration_Open` blocks changes to `Price__c`.
- **Quota Locked:** `No_Quota_Change_After_Registration_Open` blocks changes to `Quota__c`.
- **Floor Protection:** `Quota_Not_Below_Booked_Seats` blocks lowering quotas below tickets already booked.

---

## 5. Organizer Dashboard Architecture (`OrganizerDashboardController.cls`)

The **Organizer Dashboard** (`lwc/organizerDashboard`) provides an all-in-one command center for organizers:

```
+-------------------------------------------------------------------------+
|                           ORGANIZER DASHBOARD                           |
+-------------------+-------------------+-------------------+-------------+
|   TOTAL EVENTS    |   ACTIVE BOOKINGS |   TOTAL REVENUE   |  OCCUPANCY  |
|        12         |        842        |    ₹18,45,000     |     88%     |
+-------------------+-------------------+-------------------+-------------+
| [+ Create Event]  [Filter by Category: All | Conference | Workshop ...] |
+-------------------------------------------------------------------------+
| EVENT NAME       | CATEGORY   | DATES       | STATUS    | BOOKED / CAP  |
| AI Summit 2026   | Conference | Oct 12-14   | Published | 450 / 500     |
| Cloud Bootcamp   | Workshop   | Nov 05-06   | Approved  | 0 / 100       |
| FinTech Summit   | Summit     | Dec 01-02   | Pending   | 0 / 200       |
+-------------------------------------------------------------------------+
```

### Controller Security & Data Isolation:
- `OrganizerDashboardController.cls` is defined as **`public with sharing class`**.
- Because the Organization-Wide Default (OWD) on `Event__c` is **Private**, the SOQL query automatically scopes strictly to records **owned by the logged-in organizer**.
- If an Event Manager logs in, Salesforce Role Hierarchy automatically grants visibility across all organizers' events.

### Real-Time Analytics Calculations:
- **`Total_Capacity__c`:** Roll-up Summary summing all ticket tier quotas.
- **`Booked_Seats__c`:** Roll-up Summary summing all confirmed attendee tickets.
- **`Available_Seats__c`:** Formula field (`Total_Capacity__c - Booked_Seats__c`).
- **Occupancy Rate (%):** Computed client-side as `(Booked_Seats__c / Total_Capacity__c) * 100`.

---

## 6. Viva & Technical Defense Q&A for Organizer Flow

### Q1: "Why did you embed the ticket tier collector inside the Screen Flow instead of letting organizers create ticket types separately?"
> **Answer:** *"Sir, creating an event and defining its ticket tiers is an atomic business process. If an organizer created an event record first without ticket tiers, the event would have 0 total capacity and could not open for registration. Embedding the `ticketTypeCollector` LWC inside the Screen Flow guarantees that ticket tiers are configured alongside the event in one seamless user journey."*

### Q2: "Can an organizer approve their own high-budget event?"
> **Answer:** *"No, Sir. We implemented defense-in-depth on two layers:  
> 1. In the Approval Process routing, the submitter is prevented from being the assigned approver.  
> 2. On the database level, validation rule `No_Self_Approval` evaluates `ISPICKVAL(Approval_Status__c, 'Approved') && Approved_By__c = Organizer__c` and throws an error if an organizer attempts to approve their own record."*

### Q3: "What prevents an organizer from creating more ticket quotas than the venue can physically hold?"
> **Answer:** *"Sir, our Apex trigger `TicketTypeTriggerHandler` queries the parent venue's `Venue_Capacity__c` and aggregates the quotas of all sibling ticket types. If the total exceeds the venue capacity, it adds an error via `addError()`, preventing the transaction from committing."*

### Q4: "What happens if an organizer tries to increase ticket prices after registration opens?"
> **Answer:** *"Validation rule `No_Price_Change_After_Registration_Open` fires if `ISCHANGED(Price__c)` is true while `Event__r.Registration_Status__c = 'Open'`. The database rejects the update to protect consumer pricing integrity."*
