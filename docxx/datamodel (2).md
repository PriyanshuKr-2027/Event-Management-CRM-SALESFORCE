# Data Model — Objects, Fields, Types & Architecture Reference

> **Module:** Data Model & Relational Schema Dictionary  
> **Source of Truth:** `objects/` directory & `ROLE_1_DATA_MODEL_AND_WORKFLOW.md`  
> **Schema Summary:** **9 Custom Objects** + **3 Custom Metadata Types**  
> **Legend:** **(R)** = Universally Required, **(O)** = Optional, **(System)** = System-Controlled / Automation-Calculated

---

## 1. Executive Summary

The Event Management CRM data model is built following Salesforce standard data normalization practices, decoupling master entities (Venues, Attendees, Users) from transient transactional entities (Registrations, Tickets, Payments, Feedback).

```
+-------------------------------------------------------------------------------------------------+
|                                        DATA ARCHITECTURE                                        |
+------------------------------------+------------------------------------+-----------------------+
|          CORE ENTITIES             |       BOOKING & TRANSACTIONS       |  METADATA & ENGINE    |
| - Event__c                         | - Registration__c                  | - Approval_Matrix__mdt|
| - Venue__c                         | - Ticket_Type__c                   | - Approval_Settings   |
| - Attendee__c                      | - Ticket__c                        | - Payment_Gateway     |
| - Speaker__c                       | - Payment__c                       |                       |
|                                    | - Feedback__c                      |                       |
+------------------------------------+------------------------------------+-----------------------+
```

---

## 2. Detailed Custom Objects Dictionary (9 Objects)

### 1. `Event__c` (Master Event Record)
The central operational object storing event lifecycle stages, dates, venue allocation, capacity, and approval metrics.

| Field API Name | Label | Data Type | Req? | Picklist Values / Formula / Details |
|---|---|---|:---:|---|
| `Name` | Event Name | Text (255) | **(R)** | Descriptive name of the event (e.g. *Apex & AI World Tour 2026*). |
| `Category__c` | Category | Picklist | **(R)** | `Conference`, `Workshop`, `Training`, `Hackathon`, `Concert`, `Executive Summit`, `Webinar`, `Meetup`, `Other`. Drives dynamic multi-tier approval thresholds. |
| `Start_Date_Time__c` | Start Date/Time | DateTime | **(R)** | Must be in the future at creation; validated against `End_Date_Time__c`. |
| `End_Date_Time__c` | End Date/Time | DateTime | **(R)** | Must be strictly greater than `Start_Date_Time__c`. |
| `Venue__c` | Venue | Lookup(`Venue__c`) | **(R)** | Associated hosting facility. |
| `Organizer__c` | Organizer | Lookup(`User`) | (O) | Designated event organizer user in charge. |
| `Approved_By__c` | Approved By | Lookup(`User`) | (O) | Manager or executive user who approved the event. |
| `Proposed_Budget__c` | Proposed Budget | Currency (18, 2) | (O) | Target operational budget. Evaluated against `Approval_Matrix__mdt`. |
| `Approval_Status__c` | Approval Status | Picklist | **(R)** | `Draft`, `Pending Approval`, `Approved`, `Rejected`. Default: `Draft`. |
| `Publication_Status__c`| Publication Status | Picklist | **(R)** | `Unpublished`, `Published`. Default: `Unpublished`. |
| `Registration_Status__c`| Registration Status| Picklist | **(R)** | `Not Open`, `Open`, `Closed`, `Sold Out`. Default: `Not Open`. |
| `Total_Capacity__c` | Total Capacity | Roll-Up Summary | (System)| `SUM(Ticket_Type__c.Quota__c)`. Live cumulative seat capacity across tiers. |
| `Booked_Seats__c` | Booked Seats | Roll-Up Summary | (System)| `SUM(Ticket_Type__c.Booked_Seats__c)`. Live cumulative booked seats. |
| `Available_Seats__c` | Available Seats | Formula (Number) | (System)| `Total_Capacity__c - Booked_Seats__c`. Real-time remaining event seats. |
| `Description__c` | Description | Long Text Area (32768) | (O) | Rich event agenda, target audience, and highlights. |
| `Rejection_Reason__c` | Rejection Reason | Long Text Area (1000) | (O) | Mandatory feedback entered by Manager when an event is rejected. |

---

### 2. `Venue__c` (Physical Facility)
Represents physical venues, auditoriums, conference centers, or arenas hosting events.

| Field API Name | Label | Data Type | Req? | Details |
|---|---|---|:---:|---|
| `Name` | Venue Name | Text (255) | **(R)** | Facility name (e.g. *Bangalore International Exhibition Centre*). |
| `City__c` | City | Text (100) | **(R)** | City where the venue is located. |
| `Venue_Capacity__c` | Venue Capacity | Number (18, 0) | **(R)** | Maximum physical safety capacity. Evaluated by `TicketTypeTriggerHandler`. |
| `Address__c` | Address | Text Area (255) | (O) | Full street address. |
| `Contact_Person__c` | Contact Person | Text (120) | (O) | Venue point of contact / operations manager. |
| `Contact_Phone__c` | Contact Phone | Phone | (O) | Contact mobile number. |
| `Status__c` | Status | Picklist | **(R)** | `Active`, `Inactive`. Default: `Active`. |

---

### 3. `Ticket_Type__c` (Pricing Tier Configuration)
Child object in Master-Detail relationship with `Event__c`. Defines pricing and quota tiers (e.g. VIP, Early Bird, General, Student).

| Field API Name | Label | Data Type | Req? | Details |
|---|---|---|:---:|---|
| `Name` | Ticket Type Name | Text (80) | **(R)** | Tier title (e.g. *VIP All-Access*, *General Admission*). |
| `Event__c` | Event | Master-Detail(`Event__c`)| **(R)** | Parent event. Enables roll-ups on `Event__c`. |
| `Price__c` | Price | Currency (18, 2) | **(R)** | Ticket price in ₹. Locked once `Registration_Status__c = 'Open'`. |
| `Quota__c` | Quota | Number (18, 0) | **(R)** | Allocated seats for this tier. Locked once registration opens. |
| `Booked_Seats__c` | Booked Seats | Number (18, 0) | (System)| Incrementally updated atomically by `RegistrationTriggerHandler`. |
| `Available_Seats__c` | Available Seats | Formula (Number) | (System)| `Quota__c - Booked_Seats__c`. Real-time remaining seats for this tier. |
| `Status__c` | Status | Picklist | **(R)** | `Available`, `Sold Out`, `Closed`. Default: `Available`. |
| `Description__c` | Description | Long Text Area (1000) | (O) | Included benefits (e.g. *Lunch, VIP lounge access, speaker meet*). |

---

### 4. `Attendee__c` (Customer / Participant Identity)
Stores customer identities independently of individual events, enabling multi-event booking history.

| Field API Name | Label | Data Type | Req? | Details |
|---|---|---|:---:|---|
| `Name` | Attendee Name | Text (255) | **(R)** | Full name of the participant. |
| `Email__c` | Email | Email | **(R)** | Primary contact email; validated by `Valid_Email_Format`. |
| `Phone__c` | Phone | Phone | (O) | 10-digit mobile number; validated by `Valid_Phone_Number`. |
| `Organization__c` | Organization | Text (120) | (O) | Company or university affiliation. |
| `Attendee_Status__c` | Attendee Status | Picklist | **(R)** | `Active`, `Inactive`. Default: `Active`. |
| `User__c` | User | Lookup(`User`) | (O) | Binds a community/portal user to their attendee identity for security checks. |

---

### 5. `Registration__c` (Booking Junction)
Junction record linking an Attendee, Event, and Ticket Type. Represents an individual ticket reservation.

| Field API Name | Label | Data Type | Req? | Details |
|---|---|---|:---:|---|
| `Name` | Registration Number| Auto Number | (System)| `REG-{00000}`. |
| `Event__c` | Event | Master-Detail(`Event__c`)| **(R)** | Parent event. |
| `Attendee__c` | Attendee | Lookup(`Attendee__c`) | **(R)** | The registered participant. |
| `Ticket_Type__c` | Ticket Type | Lookup(`Ticket_Type__c`)| **(R)** | Selected tier. Validated to belong to the same parent event. |
| `Booking_Group_Id__c` | Booking Group ID | Text (100) | (O) | External ID grouping multi-seat orders together (e.g. `GRP-1725530000-842`). |
| `Booked_Price__c` | Booked Price | Currency (18, 2) | **(R)** | Historical price snapshot at purchase time. |
| `Registration_Status__c`| Registration Status| Picklist | **(R)** | `Pending`, `Confirmed`, `Cancelled`, `Rejected`. Default: `Pending`. |
| `Confirmation_Status__c`| Confirmation Status| Picklist | (O) | `Not Sent`, `Sent`, `Failed`. Tracks notification dispatch. |
| `Feedback_Submitted__c` | Feedback Submitted | Checkbox | (System)| Set to `TRUE` upon review submission to enforce one-review rule. |
| `Registration_Date_Time__c`| Registration Date/Time | DateTime | (System)| Timestamp of booking inception. |

---

### 6. `Ticket__c` (Issued Entry Pass)
The physical/electronic entry ticket issued upon successful payment.

| Field API Name | Label | Data Type | Req? | Details |
|---|---|---|:---:|---|
| `Name` | Ticket Number | Auto Number | (System)| `TKT-{00000}`. Printed on barcode and PDF pass. |
| `Registration__c` | Registration | Master-Detail(`Registration__c`)| **(R)** | Master registration record. Only relationship field on this object. |
| `Ticket_Status__c` | Ticket Status | Picklist | **(R)** | `Active`, `Checked In`, `Cancelled`. Default: `Active`. |
| `Issue_Date_Time__c` | Issue Date/Time | DateTime | (System)| Generated automatically upon payment confirmation. |

---

### 7. `Payment__c` (Financial Transaction)
Stores payment gateway records and UPI transaction logs. Kept as Lookup to Registration for audit permanence.

| Field API Name | Label | Data Type | Req? | Details |
|---|---|---|:---:|---|
| `Name` | Payment Number | Auto Number | (System)| `PAY-{00000}`. |
| `Registration__c` | Registration | Lookup(`Registration__c`)| **(R)** | Associated registration. |
| `Amount__c` | Amount | Currency (18, 2) | **(R)** | Amount paid. Validated against `Registration__r.Booked_Price__c`. |
| `Payment_Method__c` | Payment Method | Picklist | **(R)** | `UPI`, `Card`, `Net Banking`, `Cash`. Default: `UPI`. |
| `Payment_Status__c` | Payment Status | Picklist | **(R)** | `Pending`, `Successful`, `Failed`, `Refunded`. Default: `Pending`. |
| `Payment_Date_Time__c`| Payment Date/Time | DateTime | **(R)** | Set server-side upon settlement. |
| `Transaction_Reference__c`| Transaction Reference| Text (100) | (O) | Unique gateway/UPI reference (e.g. `UPI-1725530000-9842`). |

---

### 8. `Speaker__c` (Keynote Presenters)
Stores speaker biographies, headshots, expertise, and contact details.

| Field API Name | Label | Data Type | Req? | Details |
|---|---|---|:---:|---|
| `Name` | Speaker Name | Text (120) | **(R)** | Full name of the presenter. |
| `Event__c` | Event | Lookup(`Event__c`) | (O) | Assigned event. Kept as Lookup to avoid cascade deletion. |
| `Bio__c` | Bio | Long Text Area (32768) | (O) | Professional background and achievements. |
| `Email__c` | Email | Email | (O) | Contact email. |
| `Phone__c` | Phone | Phone | (O) | Contact mobile number. |
| `Expertise__c` | Expertise | Text (255) | (O) | Key domains (e.g. *Apex Architecture, Generative AI*). |
| `Organization__c` | Organization | Text (120) | (O) | Sponsoring company or institution. |
| `Status__c` | Status | Picklist | **(R)** | `Active`, `Inactive`. Default: `Active`. |

---

### 9. `Feedback__c` (Post-Event Reviews)
Captures attendee ratings and qualitative comments post-event.

| Field API Name | Label | Data Type | Req? | Details |
|---|---|---|:---:|---|
| `Name` | Feedback Number | Auto Number | (System)| `FB-{00000}`. |
| `Event__c` | Event | Lookup(`Event__c`) | **(R)** | Event reviewed. |
| `Attendee__c` | Attendee | Lookup(`Attendee__c`) | **(R)** | Attendee providing review. |
| `Registration__c` | Registration | Lookup(`Registration__c`)| **(R)** | Booking record. Used to enforce `One_Feedback_Per_Registration`. |
| `Overall_Rating__c` | Overall Rating | Number (2, 0) | **(R)** | Integer score from 1 to 5. |
| `Event_Experience__c`| Event Experience | Number (2, 0) | (O) | Integer score from 1 to 5. |
| `Speaker_Rating__c` | Speaker Rating | Number (2, 0) | (O) | Integer score from 1 to 5. |
| `Venue_Rating__c` | Venue Rating | Number (2, 0) | (O) | Integer score from 1 to 5. |
| `Comments__c` | Comments | Long Text Area (2000) | (O) | Detailed feedback and testimonials. |
| `Submitted_Date_Time__c`| Submitted Date/Time| DateTime | (System)| Timestamp of review submission. |

---

## 3. Custom Metadata Types Dictionary (3 CMDTs)

### 1. `Approval_Matrix__mdt` (Category Approval Thresholds)
Drives the Dynamic Multi-Tier Approval Engine in `EventApprovalService.cls`.

| Field API Name | Label | Data Type | Req? | Details |
|---|---|---|:---:|---|
| `Category__c` | Category | Text (50) | **(R)** | Event category matching `Event__c.Category__c`. |
| `Auto_Approve_Limit__c` | Auto Approve Limit | Number (18, 2) | **(R)** | Ceiling for zero-touch auto-approval. |
| `Manager_Approve_Limit__c`| Manager Approve Limit| Number (18, 2) | **(R)** | Ceiling for Manager approval before escalating to Executive. |
| `Requires_Finance_Signoff__c`| Requires Finance Signoff| Checkbox | (O) | Flag requiring Finance sign-off for large budgets. |

---

### 2. `Approval_Settings__mdt` (Global Approval Configuration)
Stores global fallback thresholds and configuration flags.

| Field API Name | Label | Data Type | Req? | Details |
|---|---|---|:---:|---|
| `Budget_Threshold__c` | Budget Threshold | Number (18, 2) | **(R)** | Baseline fallback threshold (default: ₹2,00,000). |

---

### 3. `Payment_Gateway_Config__mdt` (Gateway & UPI Adapter Config)
Stores configuration for payment processing and simulated UPI QR generation.

| Field API Name | Label | Data Type | Req? | Details |
|---|---|---|:---:|---|
| `Gateway_Provider__c` | Gateway Provider | Text (50) | **(R)** | `Razorpay`, `Stripe`, `UPI_Sandbox`. |
| `Environment__c` | Environment | Text (20) | **(R)** | `Sandbox` or `Production`. |
| `UPI_VPA__c` | UPI VPA | Text (100) | (O) | Active merchant Virtual Payment Address (e.g. `events@upi`). |
| `Merchant_Key_Id__c` | Merchant Key ID | Text (100) | (O) | Gateway client ID or public API key. |
| `Merchant_Secret__c` | Merchant Secret | Text (100) | (O) | Secure API key. |
| `Webhook_Secret__c` | Webhook Secret | Text (100) | (O) | Cryptographic HMAC secret for verifying webhook payloads. |
| `Auto_Verify_Seconds__c`| Auto Verify Seconds | Number (3, 0) | (O) | Demo countdown duration for payment verification (default: 10s). |

---

## 4. Viva / Oral Defense Questions for Data Model

### Q1: "Why did you use Roll-Up Summary fields for Capacity and Booked Seats instead of calculating them in Apex?"
> **Answer:** *"Sir, Salesforce native Roll-Up Summary fields on Master-Detail relationships are declarative, real-time, and zero-maintenance. They calculate instantly without consuming Apex CPU execution time or SOQL query limits. On `Event__c`, `Total_Capacity__c` sums all `Ticket_Type__c.Quota__c` values, and `Available_Seats__c` is a formula field that recalculates automatically."*

### Q2: "How does your data model handle multi-seat ticket bookings?"
> **Answer:** *"When an attendee books multiple tickets (e.g., 3 seats for a team), our `EventBookingController` creates 3 individual `Registration__c` records, each linked to their respective `Attendee__c` details. All 3 records share a common `Booking_Group_Id__c` external ID. This ensures each attendee gets a unique barcode ticket (`Ticket__c`), while enabling group checkout and a unified receipt."*
