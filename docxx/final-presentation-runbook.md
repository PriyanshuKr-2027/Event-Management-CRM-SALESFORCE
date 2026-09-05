# Final Presentation & Demonstration Runbook
## Salesforce Final-Year Project: Event Management & Ticketing CRM

This runbook gives you a complete, step-by-step presentation script designed to satisfy every item on the **Final Presentation Checklist (§10)** of the project specification.

---

## 1. Business Problem & Solution Overview (2–3 Minutes Pitch)
**Speaker Script:**
> *"Good morning/afternoon everyone. Today, modern event management companies struggle with fragmented operations: event budgets get approved via disconnected email chains, attendee bookings suffer from overselling during ticket spikes, payment verifications are slow, and post-event analytics are scattered.*
> 
> *To solve this, we designed and built the **Event Management & Ticketing CRM** on Salesforce. It is an end-to-end solution delivering:*
> 1. *Strict financial approval governance using an automated Approval Process for event budgets.*
> 2. *High-concurrency ticket locking and capacity guards using bulk-safe Apex triggers.*
> 3. *A consumer-grade Attendee Portal and Organizer Command Center built on Lightning Web Components.*
> 4. *Automated lifecycle communications via Flow (instant ticket generation, daily event reminders, and feedback surveys).*
> 5. *Full role-based security across Event Managers, Organizers, Registration Teams, Finance, and Attendees.*
> 6. *Real-time executive decision-making via native Reports, Dashboards, and printable Visualforce tickets."*

---

## 2. Data Model & Architecture (ERD Walkthrough)
**Talking Points:**
- **Core Master Objects**: `Venue__c`, `Event__c`, `Speaker__c`, `Attendee__c`.
- **Ticketing & Transaction Objects**:
  - `Ticket_Type__c`: Master-Detail to `Event__c` (Tiered pricing: VIP, Early Bird, General Admission).
  - `Registration__c`: Master-Detail to `Event__c`, Lookup to `Attendee__c`.
  - `Ticket__c`: Master-Detail to `Registration__c` (stores barcode and active check-in status).
  - `Payment__c`: Master-Detail to `Registration__c` (tracks UPI/Card transactions and amount pinning).
  - `Feedback__c`: Master-Detail/Lookup to `Event__c` and `Registration__c` for ratings.
- **Rollups & Formulas**: Roll-up summaries on `Event__c` calculate `Total_Capacity__c`, `Booked_Seats__c`, `Available_Seats__c`, and `Realized_Revenue__c`.
- **Validation Rules**: 17 Validation Rules prevent premature publishing, negative venue capacities, post-close modifications, and unpermitted feedback.

---

## 3. End-to-End Business Demonstration Sequence

### Step A: Event Creation & Budget Approval
1. Open the **Event Management App** (`/lightning/app/06mdL00000b6MRxQAM`).
2. Navigate to **Organizer Dashboard** tab.
3. Click the **Create New Event** button to launch the Screen Flow.
4. Input event details (Name, Venue, Dates, Proposed Budget).
   - If Budget $\le ₹2,00,000$ (2 Lakhs INR), show auto-approval.
   - If Budget $> ₹2,00,000$, show the event automatically route to the **Event Manager** for approval.
5. In the next flow screen, dynamically add ticket tiers (VIP, Regular) using the embedded `ticketTypeCollector` component.

### Step B: Attendee Booking & Payment Simulation
1. Switch to the **Event Portal App** (`/lightning/app/06mdL00000b6MRyQAM`).
2. On the **Event Booking** tab, browse available events using category filters (Conference, Workshop).
3. Select an event (e.g. *Global Tech Summit 2026*).
4. Click **Register**, choose a ticket type, and fill in attendee details in the embedded screen flow.
5. Watch the **Payment QR Verification LWC** modal open:
   - Live scannable QR code generated from a fresh session reference.
   - Price pinned directly to the ticket price in ₹.
   - Click "I have completed the payment" and click Next.
   - Watch the unskippable 10-second verification countdown tick down.
   - Success state triggers automated Apex confirmation (`confirmPayment`).
6. Switch to the **My Tickets** tab on the Attendee Booking Portal:
   - View the active ticket card showing ticket number, status badge, booked price in ₹, and attendee name.
   - Click "View / Print Pass" to launch the printable admission ticket.

### Step C: Record-Triggered Automation & Ticket Generation
1. Show that upon payment confirmation, `Registration_Status__c` transitions to `Confirmed`.
2. The `Post_Registration_Automation` record-triggered flow immediately:
   - Generates an active `Ticket__c` record.
   - Creates a confirmation `Task` on the Event.
   - Sends a confirmation email to the attendee.

### Step D: Printable Visualforce Admission Pass
1. Open the created `Ticket__c` record or navigate to `/apex/PrintableTicket?id=<Ticket_Id>`.
2. Demonstrate the styled printable PDF pass with barcode, event times, venue details, and the one-click print button.

---

## 4. Security & Access Model
- **OWD**: `Event__c`, `Payment__c`, `Attendee__c`, `Speaker__c`, `Feedback__c` set to **Private**; `Venue__c` set to **Public Read Only**; child objects set to **ControlledByParent**.
- **Role Hierarchy**: 3-tier structure: `Event_Manager` > `Event_Organizer` & `Event_Finance`; `Event_Organizer` > `Event_Registration_Team` & `Event_Speaker_Coordinator`.
- **Criteria-Based Sharing Rules**: 
  - Published events shared with read-only access to all internal staff.
  - Pending approval events automatically shared with edit access to Event Managers.
- **Permission Sets & Groups**:
  - `Event_Organizer_Permissions`: CRUD on Events, Venues, and Ticket Types.
  - `Event_Manager_Permissions`: Approval oversight and managerial access.
  - `Event_Registration_Team_Permissions`: Attendee check-ins and registration handling.
  - `Event_Finance_Permissions`: Payment records and financial oversight.
  - `Event_Speaker_Coordinator_Permissions`: Keynote and speaker management.
  - `Event_Operations_Staff`: Unified Permission Set Group bundling all operational roles.

---

## 5. Apex Automation & Bulk-Safety Proof
- Demonstrate unit test coverage:
  - **34 Unit & E2E Tests**.
  - **100% Pass Rate** (0 Failures).
  - **90–100% Code Coverage** across all controllers and triggers.
- Explain concurrency handling:
  - `TicketTypeTriggerHandler` and `RegistrationTriggerHandler` use `FOR UPDATE` SOQL locks to prevent overselling when multiple attendees click "Book" simultaneously.

---

## 6. Reports & Executive Dashboard
1. Open the **Dashboards** tab in the Event Management App.
2. Open the **Event Executive Dashboard**:
   - **Realized Revenue by Event**: Column chart showing ticket income.
   - **Approval Status Breakdown**: Donut chart showing Draft vs Approved events.
   - **Ticket Type Allocation**: Horizontal grouped bar chart comparing quotas and booked seats.
   - **Attendee Satisfaction**: Average rating metrics across completed events.
3. Drill down into the underlying reports in the **Event Reports** folder:
   - *My Events Revenue Summary*
   - *My Events by Approval Status*
   - *Event Ticket Types Allocation*
   - *Event Feedback Analysis*

---

## 7. Key Challenges, Solutions & Future Enhancements
- **Challenge 1**: Real-time ticket inventory concurrency without race conditions.
  - *Solution*: Implemented SOQL row-level locking (`FOR UPDATE`) and atomic quota deduction in Apex triggers.
- **Challenge 2**: Preventing premature feedback submissions.
  - *Solution*: Cross-object validation rule (`No_Feedback_Before_Event_Ends`) ensuring `End_Date_Time__c <= NOW()`.
- **Future Enhancements**:
  - WhatsApp integration for instant mobile ticket dispatch.
  - AI-driven event attendance forecasting using Salesforce Einstein.
