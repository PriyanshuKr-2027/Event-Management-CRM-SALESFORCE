# Validation Rules Reference Manual

> **Module:** Data Model & Schema Integrity  
> **Source of Truth:** `objects/*/validationRules/*.validationRule-meta.xml` & `ROLE_1_DATA_MODEL_AND_WORKFLOW.md`  
> **Total Active Declarative Validation Rules:** **20 Rules** across **7 Objects**  
> **Apex Trigger Guards:** **2 Architectural Checks** (`TicketTypeTriggerHandler`, `RegistrationTriggerHandler`)  
> **Controller Security & Idempotency Guards:** **2 Programmatic Checks** (`EventBookingController`)

---

## 1. Executive Summary & Defense Strategy

Salesforce validation rules represent the **declarative database gatekeepers**. They execute during the Salesforce Save Order of Execution **before** data commits to the database, ensuring bad data cannot be introduced via the UI, Lightning Web Components, Screen Flows, Data Loader, or SOAP/REST APIs.

For complex cross-record aggregations (e.g., total ticket quotas exceeding venue capacity) or high-concurrency race conditions (e.g., two users booking the last remaining VIP seat simultaneously), declarative validation rules are architecturally insufficient. In our implementation:
- **Single-record and direct parent-relationship constraints** are enforced using **Declarative Validation Rules**.
- **Multi-record aggregations and concurrency-critical capacity locks** are enforced using **Apex Triggers with `FOR UPDATE` row locking**.
- **User context and payment idempotency** are enforced at the **Apex Controller level**.

---

## 2. Complete Declarative Validation Rules Matrix (20 Rules)

| # | Object API Name | Rule API Name | Error Condition Formula | Error Message | Error Location |
|---|---|---|---|---|---|
| 1 | `Event__c` | **`End_After_Start`** | `Start_Date_Time__c >= End_Date_Time__c` | *End Date/Time must be strictly after Start Date/Time.* | `End_Date_Time__c` |
| 2 | `Event__c` | **`Budget_Required_On_Submit`** | `ISBLANK(Proposed_Budget__c) && ISPICKVAL(Approval_Status__c, "Pending Approval")` | *Proposed Budget is required before submitting an event for approval.* | `Proposed_Budget__c` |
| 3 | `Event__c` | **`No_Publish_Before_Approved`** | `ISPICKVAL(Publication_Status__c, "Published") && NOT(ISPICKVAL(Approval_Status__c, "Approved"))` | *An event cannot be published until its approval status is Approved.* | `Publication_Status__c` |
| 4 | `Event__c` | **`No_Booking_On_Rejected_Or_Cancelled`** | `(ISPICKVAL(Approval_Status__c, "Rejected") \|\| ISPICKVAL(Approval_Status__c, "Cancelled")) && ISPICKVAL(Publication_Status__c, "Published")` | *Rejected or Cancelled events cannot be published.* | Top of Page |
| 5 | `Event__c` | **`Rejection_Reason_Required`** | `ISPICKVAL(Approval_Status__c, "Rejected") && ISBLANK(Rejection_Reason__c)` | *Rejection Reason is mandatory when an event is rejected.* | `Rejection_Reason__c` |
| 6 | `Event__c` | **`No_Self_Approval`** | `ISPICKVAL(Approval_Status__c, "Approved") && NOT(ISBLANK(Approved_By__c)) && Approved_By__c = Organizer__c` | *An organizer cannot approve their own event.* | Top of Page |
| 7 | `Venue__c` | **`Capacity_Positive`** | `Venue_Capacity__c <= 0` | *Venue Capacity must be a positive number greater than zero.* | `Venue_Capacity__c` |
| 8 | `Ticket_Type__c` | **`No_Price_Change_After_Registration_Open`** | `ISCHANGED(Price__c) && ISPICKVAL(Event__r.Registration_Status__c, "Open")` | *Ticket price cannot be modified after registration has opened.* | `Price__c` |
| 9 | `Ticket_Type__c` | **`No_Quota_Change_After_Registration_Open`** | `ISCHANGED(Quota__c) && ISPICKVAL(Event__r.Registration_Status__c, "Open")` | *Ticket quota cannot be modified after registration has opened.* | `Quota__c` |
| 10 | `Ticket_Type__c` | **`Quota_Not_Below_Booked_Seats`** | `Quota__c < Booked_Seats__c` | *Ticket quota cannot be reduced below the number of already booked seats.* | `Quota__c` |
| 11 | `Registration__c` | **`Ticket_Type_Must_Belong_To_Event`** | `Ticket_Type__r.Event__c <> Event__c` | *The selected ticket type does not belong to the selected event.* | `Ticket_Type__c` |
| 12 | `Registration__c` | **`No_Reg_On_Unpublished_Or_Closed_Event`** | `ISNEW() && NOT(ISPICKVAL(Event__r.Registration_Status__c, "Open"))` | *Registrations cannot be created for events that are not currently open for registration.* | Top of Page |
| 13 | `Registration__c` | **`Booked_Price_Required`** | `ISNEW() && ISBLANK(Booked_Price__c)` | *Booked Price is required when creating a registration.* | `Booked_Price__c` |
| 14 | `Payment__c` | **`Amount_Matches_Registration_Booked_Price`** | `Amount__c <> Registration__r.Booked_Price__c` | *Payment amount must match the booked price of the registration.* | `Amount__c` |
| 15 | `Payment__c` | **`Txn_Ref_Required_When_Successful`** | `ISPICKVAL(Payment_Status__c, "Successful") && ISBLANK(Transaction_Reference__c)` | *Transaction Reference is required when Payment Status is Successful.* | `Transaction_Reference__c` |
| 16 | `Attendee__c` | **`Valid_Email_Format`** | `AND(NOT(ISBLANK(Email__c)), NOT(REGEX(Email__c, "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$")))` | *Please enter a valid email address.* | `Email__c` |
| 17 | `Attendee__c` | **`Valid_Phone_Number`** | `AND(NOT(ISBLANK(Phone__c)), NOT(REGEX(Phone__c, "^[0-9]{10}$")))` | *Phone number must contain exactly 10 digits.* | `Phone__c` |
| 18 | `Feedback__c` | **`Rating_Range`** | `Overall_Rating__c < 1 \|\| Overall_Rating__c > 5` | *Overall Rating must be an integer between 1 and 5.* | `Overall_Rating__c` |
| 19 | `Feedback__c` | **`No_Feedback_Before_Event_Ends`** | `Registration__r.Event__r.End_Date_Time__c > NOW()` | *Feedback cannot be submitted before the event has ended.* | Top of Page |
| 20 | `Feedback__c` | **`One_Feedback_Per_Registration`** | `Registration__r.Feedback_Submitted__c = TRUE` | *Feedback has already been submitted for this registration.* | Top of Page |

---

## 3. Deep-Dive by Functional Object

### 1. `Event__c` Validation Rules (6 Rules)

#### A. `End_After_Start`
- **Formula:** `Start_Date_Time__c >= End_Date_Time__c`
- **Business Rationale:** An event cannot end before it begins or have zero duration.
- **Save Context:** Evaluated on Create and Edit whenever start or end dates are modified.

#### B. `Budget_Required_On_Submit`
- **Formula:** `ISBLANK(Proposed_Budget__c) && ISPICKVAL(Approval_Status__c, "Pending Approval")`
- **Business Rationale:** The dynamic approval engine routes approval based on `Proposed_Budget__c`. An organizer cannot submit an event for approval without specifying the budget.

#### C. `No_Publish_Before_Approved`
- **Formula:** `ISPICKVAL(Publication_Status__c, "Published") && NOT(ISPICKVAL(Approval_Status__c, "Approved"))`
- **Business Rationale:** Enforces the governance separation between **Approval** and **Publication**. An organizer cannot publish an unapproved event to attendees.

#### D. `No_Booking_On_Rejected_Or_Cancelled`
- **Formula:** `(ISPICKVAL(Approval_Status__c, "Rejected") || ISPICKVAL(Approval_Status__c, "Cancelled")) && ISPICKVAL(Publication_Status__c, "Published")`
- **Business Rationale:** Prevents invalid or cancelled events from appearing in published state on the portal.

#### E. `Rejection_Reason_Required`
- **Formula:** `ISPICKVAL(Approval_Status__c, "Rejected") && ISBLANK(Rejection_Reason__c)`
- **Business Rationale:** When an Event Manager rejects a proposed event budget, feedback must be recorded to explain the business reason to the organizer.

#### F. `No_Self_Approval`
- **Formula:** `ISPICKVAL(Approval_Status__c, "Approved") && NOT(ISBLANK(Approved_By__c)) && Approved_By__c = Organizer__c`
- **Business Rationale:** Defense-in-depth security guard. Prevents an organizer from approving their own event.

---

### 2. `Venue__c` Validation Rules (1 Rule)

#### A. `Capacity_Positive`
- **Formula:** `Venue_Capacity__c <= 0`
- **Business Rationale:** Ensures that venues have a valid physical seat limit. Prevents zero or negative numbers from breaking downstream capacity formulas.

---

### 3. `Ticket_Type__c` Validation Rules (3 Rules)

#### A. `No_Price_Change_After_Registration_Open`
- **Formula:** `ISCHANGED(Price__c) && ISPICKVAL(Event__r.Registration_Status__c, "Open")`
- **Business Rationale:** Consumer fairness guard. Ticket prices cannot be changed dynamically once registration is active to prevent bait-and-switch pricing.

#### B. `No_Quota_Change_After_Registration_Open`
- **Formula:** `ISCHANGED(Quota__c) && ISPICKVAL(Event__r.Registration_Status__c, "Open")`
- **Business Rationale:** Prevents organizers from altering tier allocations mid-campaign, which would distort capacity formulas and analytics.

#### C. `Quota_Not_Below_Booked_Seats`
- **Formula:** `Quota__c < Booked_Seats__c`
- **Business Rationale:** An organizer cannot decrease a tier quota below the number of tickets already purchased by attendees, preventing negative available seat calculations.

---

### 4. `Registration__c` Validation Rules (3 Rules)

#### A. `Ticket_Type_Must_Belong_To_Event`
- **Formula:** `Ticket_Type__r.Event__c <> Event__c`
- **Business Rationale:** Relational integrity guard. Prevents an attendee from booking a Ticket Type associated with Event A against an event record for Event B.

#### B. `No_Reg_On_Unpublished_Or_Closed_Event`
- **Formula:** `ISNEW() && NOT(ISPICKVAL(Event__r.Registration_Status__c, "Open"))`
- **Critical Architectural Design:** The `ISNEW()` guard ensures this rule only executes during the **initial ticket creation**. If an event's registration closes while an attendee is finishing the payment countdown, the subsequent update (changing status from `Pending` to `Confirmed`) will not be blocked.

#### C. `Booked_Price_Required`
- **Formula:** `ISNEW() && ISBLANK(Booked_Price__c)`
- **Business Rationale:** Mandates that a historical price snapshot is captured when the registration is inserted, insulating financial reports from future tier price changes.

---

### 5. `Payment__c` Validation Rules (2 Rules)

#### A. `Amount_Matches_Registration_Booked_Price`
- **Formula:** `Amount__c <> Registration__r.Booked_Price__c`
- **Business Rationale:** Prevents financial reconciliation errors and underpayment by guaranteeing that the recorded payment matches the registration's booked price snapshot.

#### B. `Txn_Ref_Required_When_Successful`
- **Formula:** `ISPICKVAL(Payment_Status__c, "Successful") && ISBLANK(Transaction_Reference__c)`
- **Business Rationale:** Ensures all successful transactions have an auditable gateway or UPI reference ID (e.g., `UPI-1725538000-9842`).

---

### 6. `Attendee__c` Validation Rules (2 Rules)

#### A. `Valid_Email_Format`
- **Formula:** `AND(NOT(ISBLANK(Email__c)), NOT(REGEX(Email__c, "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$")))`
- **Business Rationale:** Enforces RFC 5322 compliant email formatting for QR ticket delivery and email alerts.

#### B. `Valid_Phone_Number`
- **Formula:** `AND(NOT(ISBLANK(Phone__c)), NOT(REGEX(Phone__c, "^[0-9]{10}$")))`
- **Business Rationale:** Standardizes mobile numbers to exact 10 digits for SMS notifications and UPI identity mapping.

---

### 7. `Feedback__c` Validation Rules (3 Rules)

#### A. `Rating_Range`
- **Formula:** `Overall_Rating__c < 1 || Overall_Rating__c > 5`
- **Business Rationale:** Standardizes survey scoring on a clean 1 to 5 star scale for reporting and dashboard gauges.

#### B. `No_Feedback_Before_Event_Ends`
- **Formula:** `Registration__r.Event__r.End_Date_Time__c > NOW()`
- **Business Rationale:** Prevents attendees from submitting reviews before an event has actually concluded.

#### C. `One_Feedback_Per_Registration`
- **Formula:** `Registration__r.Feedback_Submitted__c = TRUE`
- **Business Rationale:** Prevents duplicate feedback spam. Works in tandem with the `Feedback_Submitted__c` checkbox on `Registration__c`, which is set to `TRUE` via trigger/flow upon first review submission.

---

## 4. Architectural Separation: Why Certain Rules Are in Apex

When questioned during Viva: *"Why aren't Venue Capacity limits or Concurrent Seat Bookings written as Validation Rules?"*

### 1. Total Quota vs Venue Capacity (`TicketTypeTriggerHandler.cls`)
- **Limitation of Validation Rules:** A validation rule on `Ticket_Type__c` evaluates only single records and their direct parent fields. It **cannot aggregate sibling records** without a roll-up summary.
- **Race Condition in Validation Rules:** In Salesforce, roll-up summary fields calculate *after* validation rules run. Therefore, a validation rule would evaluate against stale pre-save data and allow capacity violations to slip through.
- **Apex Implementation:** `TicketTypeTriggerHandler.validateQuotaAgainstVenueCapacity()` queries all sibling ticket types, aggregates the proposed total, and adds a field error if `(Existing Sibling Quotas + New Quota) > Venue.Venue_Capacity__c`.

### 2. High-Concurrency Overbooking Guard (`RegistrationTriggerHandler.cls`)
- **Limitation of Validation Rules:** Validation rules do not lock database rows. If two users click "Book Now" for the final available ticket simultaneously, both validation rules evaluate `Available_Seats__c > 0` as true, causing an overbooking violation.
- **Apex Implementation:** `RegistrationTriggerHandler.validateQuotaAndCapacity()` locks the `Ticket_Type__c` record using `[SELECT ... FOR UPDATE]` and serializes transactions to guarantee 100% seat availability integrity.

### 3. Ownership & Duplicate Payment Guards (`EventBookingController.cls`)
- **Ownership Verification:** Verifies `reg.Attendee__r.User__c == UserInfo.getUserId()`. Declarative validation rules cannot dynamically check the calling portal user context across related parent records.
- **Payment Idempotency:** Queries `Payment__c WHERE Registration__c = :registrationId` before inserting, ensuring multi-clicks on the payment modal never generate duplicate payment records.

---

## 5. Viva / Technical Defense Questions

### Q1: "Why did you use `ISNEW()` in `No_Reg_On_Unpublished_Or_Closed_Event`?"
> **Answer:** *"Sir, without `ISNEW()`, the validation rule executes on every subsequent update to the Registration record. In our workflow, an attendee first creates a registration in `Pending` status, and after completing the payment countdown, our Apex method updates it to `Confirmed`. If the event registration closed during that 10-second payment window, an un-scoped validation rule would block the payment confirmation update. Adding `ISNEW()` ensures the rule only restricts new bookings."*

### Q2: "What happens if an admin enters an invalid phone number through Data Loader?"
> **Answer:** *"Because these are native Salesforce validation rules defined on the object schema, they execute regardless of entry point—whether through our LWC frontend, standard Salesforce UI, Flow, or API Data Loader. Any invalid phone number that does not match `^[0-9]{10}$` will be rejected by the database engine."*
