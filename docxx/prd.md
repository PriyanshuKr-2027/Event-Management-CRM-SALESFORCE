# Event Management & Ticketing CRM — Product Requirements Document

## Revision Log

This version incorporates the following decisions made since the previous PRD draft:

1. **Event Speaker junction removed.** Speaker now carries a direct `Event` lookup instead
   (§4.1, §4.2, §5.8, §5.9 removed, §16). A speaker at multiple events now gets one Speaker
   record per event.
2. **`Attendee.User__c` added** (§5.6) to bind a portal/community Attendee to their
   Salesforce User, enabling ownership verification on payment confirmation.
3. **QR-code payment verification step added** between Registration submission and Ticket
   creation (§5.5, §6, §22). Registration is created as **Pending**; a new
   `EventBookingController.confirmPayment` Apex method — invoked only after the attendee
   completes a 10-second payment-verification screen — creates the Payment record and flips
   Registration to **Confirmed**, which is what fires the Record-Triggered Flow (§13).
4. **Payment sequencing resolved** (was open item §23.2): Payment is created **before** the
   Registration status update, both in one transaction, itself downstream of Registration
   creation. Ticket creation still follows, off the Confirmed status change.
5. **Event Creation Screen Flow specified** (§7, §24 item 12) — previously named in the
   implementation order but never speced. Dynamic Ticket Type entry (§5.2, §7 Step 4) is
   built as a native repeating loop within this one flow, not a separate object page.
6. **Approval budget threshold resolved** (was open item §23.1): sourced from a Custom
   Metadata Type (`Approval_Settings__mdt`) rather than hardcoded, so it's Admin-editable
   without redeployment.
7. **Booked Seats ownership resolved** (was open item §23.8): confirmed Apex-only, via
   `RegistrationTriggerHandler`, never touched by any Flow.

---

## 1. Product Overview

A Salesforce-based Event Management & Ticketing CRM for the complete event lifecycle:

- Event creation and configuration
- Venue management
- Dynamic ticket types, prices, and quotas
- Budget approval
- Event publishing and registration
- Attendee registration
- Ticket issuance
- Payment tracking
- Automated reminders
- Post-event feedback
- Dashboards and reporting

The original project specification defines Event, Venue, Speaker, Attendee, Ticket, Registration, Payment, and Feedback as core objects; Ticket Type was added for dynamic ticket quotas. fileciteturn0file0L17-L26

---

## 2. Goals

1. Provide an end-to-end Salesforce event lifecycle.
2. Allow organizers to create and manage events.
3. Support management approval for events when required.
4. Keep Approved and Published as separate states.
5. Support dynamic ticket types for every event.
6. Enforce ticket-type quotas and prevent overbooking.
7. Lock ticket price and quota once Registration Opens.
8. Let attendees discover and register for eligible events.
9. Generate a ticket only after successful registration.
10. Track payments.
11. Send reminders exactly 24 hours before an event starts.
12. Send feedback requests exactly 10 hours after an event ends.
13. Provide reports and dashboards.
14. Demonstrate the required Salesforce Admin, Flow, Approval, Apex, Visualforce, LWC, security, reporting, and testing capabilities. fileciteturn0file0L27-L74

---

# 3. User Roles

## 3.1 Attendee

Can:

- View published/upcoming eligible events.
- View event details, ticket types, prices, and available seats.
- Select a ticket type.
- Complete registration.
- View their own registrations and tickets.
- Complete payment where applicable.
- Receive confirmation.
- Receive post-event feedback request.
- Submit feedback.

Must not access other attendees' private data, internal budgets, internal financial information, or administration.

## 3.2 Event Organizer

Can:

- Create events.
- Set event details, dates, venue, ticket types, prices, quotas, and proposed budget.
- Submit events for approval when required.
- Publish approved events.
- Manage their events.
- View registrations, seats, revenue, and status for their events.
- Edit and resubmit rejected events.
- Cancel rejected events.

Cannot approve their own event.

## 3.3 Event Manager

Can:

- Review events requiring approval.
- Review proposed budgets and event details.
- Approve or reject events.
- Provide rejection comments/reason.
- Must not approve their own request.

## 3.4 Registration Team

Can operate on attendee and registration records as permitted, including events, registrations, tickets, ticket types, availability, and attendance-related operations.

Does not manage budgets, ticket prices/quotas, payments, speakers, or approvals.

## 3.5 Finance

Manages:

- Payment records
- Payment amount
- Payment status
- Transaction references
- Financial/revenue reporting

Does not manage capacity, quotas, prices, registrations, speakers, or approvals.

## 3.6 Speaker Coordinator

Manages:

- Speaker records
- Speaker information
- Event-speaker assignments

Does not manage payments, registrations, ticket pricing/quotas, budgets, or approvals.

## 3.7 Admin

Full access to Salesforce configuration, users, security, records, flows, approvals, Apex, Visualforce, LWCs, reports, and dashboards.

---

# 4. Data Model

## 4.1 Objects

1. Event
2. Venue
3. Ticket Type
4. Registration
5. Ticket
6. Attendee
7. Payment
8. Speaker
9. Feedback

Ticket Type was added because ticket quotas must be dynamic per event.

> **Revised:** an earlier draft included a 10th object, Event Speaker, as a junction for
> Event/Speaker many-to-many. This has been removed — a Speaker now belongs to at most one
> Event via a direct lookup (§5.8). If a person speaks at multiple events, a separate Speaker
> record is created per event, which is acceptable at this project's scope.

## 4.2 Relationship Model

Relationship fields are created only once on the child object. Salesforce automatically provides the reverse related list; a second relationship field is not created merely to represent the reverse direction.

| Child Object | Relationship Field | Type          | Related Object |
| ------------ | ------------------ | ------------- | -------------- |
| Event        | Venue              | Lookup        | Venue          |
| Event        | Organizer          | Lookup        | User           |
| Ticket Type  | Event              | Master-Detail | Event          |
| Registration | Event              | Master-Detail | Event          |
| Registration | Attendee           | Lookup        | Attendee       |
| Registration | Ticket Type        | Lookup        | Ticket Type    |
| Ticket       | Registration       | Master-Detail | Registration   |
| Payment      | Registration       | Lookup        | Registration   |
| Feedback     | Event              | Lookup        | Event          |
| Feedback     | Attendee           | Lookup        | Attendee       |
| Feedback     | Registration       | Lookup        | Registration   |
| Attendee     | User               | Lookup        | User           |
| Speaker      | Event              | Lookup        | Event          |

### Relationship meanings

- One Venue → many Events.
- One Organizer → many Events.
- One Event → many Ticket Types.
- One Event → many Registrations.
- One Attendee → many Registrations.
- One Ticket Type → many Registrations.
- One successful Registration → one Ticket.
- One Registration → payment record(s).
- One Event → many Feedback records.
- One Attendee → many Feedback records.
- One Registration → at most one Feedback submission.
- One User → many Attendee records (optional — an Attendee may have no linked User, e.g. walk-in registrations created by Registration Team).
- One Event → many Speakers (a Speaker belongs to at most one Event; a person speaking at several events needs one Speaker record per event).

The original data-model discussion established these relationships as the design basis and identified Lookup vs Master-Detail as the next design decision. fileciteturn1file0L651-L711

---

# 5. Object Requirements

## 5.1 Event

### Fields

- Event Name — Text
- Description — Long Text
- Category — Picklist
- Start Date/Time — Date/Time
- End Date/Time — Date/Time
- Venue — Lookup
- Organizer — Lookup/User
- Proposed Budget — Currency
- Approval Status — Picklist
- Publication Status — Picklist
- Registration Status — Picklist
- Total Capacity — Roll-Up/calculated
- Booked Seats — Roll-Up/calculated
- Available Seats — Formula

### Capacity

`Total Capacity = SUM(Ticket Type Quotas)`

`Booked Seats = SUM(Ticket Type Booked Seats)`

`Available Seats = Total Capacity - Booked Seats`

Total ticket quota must not exceed Venue Capacity.

The source design explicitly uses dynamic Ticket Type quotas to derive event capacity and available seats. fileciteturn1file0L121-L155

---

## 5.2 Ticket Type

Fields:

- Ticket Type Name
- Event
- Price
- Quota
- Booked Seats
- Available Seats
- Description
- Status

Example:

```text
VIP
Price: ₹2,000
Quota: 50
Booked: 48
Available: 2
```

Rules:

1. Ticket types are dynamic per event.
2. Each ticket type has its own quota.
3. Available Seats = Quota - Booked Seats.
4. Quota cannot be reduced below already-booked seats.
5. Total ticket quota cannot exceed venue capacity.
6. Price cannot be changed once Registration Opens.
7. Quota cannot be changed once Registration Opens.
8. Booked Seats and Available Seats are system-controlled.
9. Organizer cannot manually edit availability.

---

## 5.3 Registration

Represents the actual booking transaction.

Fields:

- Registration Number — Auto Number
- Attendee — Lookup
- Event — Master-Detail
- Ticket Type — Lookup
- Registration Date/Time — Date/Time
- Registration Status — Picklist
- Booked Price / Amount — Currency
- Confirmation Status — Picklist

Suggested Registration Status:

- Pending
- Confirmed
- Cancelled
- Rejected

Suggested Confirmation Status:

- Not Sent
- Sent
- Failed

The booked price is stored as the transaction's price snapshot.

Selected Ticket Type must belong to the selected Event.

---

## 5.4 Ticket

Represents the actual admission/pass generated from a successful registration.

Fields:

- Ticket Number — Auto Number
- Registration — Master-Detail
- Issue Date/Time — Date/Time
- Ticket Status — Picklist

Ticket generation occurs only after successful registration validation.

The ticket supports the required Visualforce printable ticket/pass.

---

## 5.5 Payment

Fields:

- Payment Number — Auto Number
- Registration — Lookup
- Amount — Currency
- Payment Date/Time — Date/Time
- Payment Status — Picklist
- Payment Method — Picklist
- Transaction Reference — Text

Suggested Payment Status:

- Pending
- Successful
- Failed
- Refunded

**Sequencing (resolved — supersedes the earlier open item):** Payment is created **before**
Ticket. The attendee completes a QR-code payment-verification screen (see §6) after
Registration is created; on completion, `EventBookingController.confirmPayment` inserts the
Payment record (Amount pinned server-side to `Registration.Booked_Price__c`, Payment Status =
"Successful", Payment Method = "UPI") and then updates the Registration's status to
Confirmed. That status change is what triggers Ticket creation via the Record-Triggered Flow
(§13). Payment amount is never accepted as raw client input — it is always derived
server-side from the Registration's price snapshot.

---

## 5.6 Attendee

Fields:

- Name — Standard Name
- Email — Email
- Phone — Phone
- Organization — Text
- Attendee Status — Picklist
- User — Lookup(User), optional — binds a portal/community Attendee to the logged-in
  Salesforce User, when one exists. Used to verify Registration ownership during payment
  confirmation (§6). Nullable, since Registration Team can create Attendee records for
  walk-in/phone bookings with no associated User account.

Related activity:

- Registrations
- Tickets
- Payments
- Feedback

---

## 5.7 Venue

Fields:

- Venue Name
- Address
- City
- Venue Capacity
- Contact Person
- Contact Phone
- Status

Rule:

`Total Ticket Quota <= Venue Capacity`

---

## 5.8 Speaker

Fields:

- Speaker Name
- Email
- Phone
- Organization
- Expertise
- Bio
- Status

Event participation uses Event Speaker.

---

## 5.9 Event Speaker

Junction object:

- Event — Master-Detail
- Speaker — Master-Detail

Supports:

`One Event → Many Speakers`

`One Speaker → Many Events`

---

## 5.10 Feedback

Fields:

- Feedback Number — Auto Number
- Event — Lookup
- Attendee — Lookup
- Registration — Lookup
- Overall Rating
- Event Experience
- Speaker Rating
- Venue Rating
- Comments
- Submitted Date/Time

Reports should support:

- Average rating by event
- Best/worst event
- Speaker ratings
- Venue ratings
- Feedback volume

---

# 6. Attendee Workflow

```text
Login
  ↓
View published/upcoming events
  ↓
Select Event
  ↓
View details + ticket types + available seats
  ↓
Select Ticket Type
  ↓
Enter registration details
  ↓
Review
  ↓
Submit Registration
```

A Screen Flow provides the booking interaction. An LWC may provide the event/ticket selection UI and launch/host the Screen Flow.

Record-Triggered Flow does not provide UI.

## Availability Gate

Registration is submitted to Salesforce and Apex performs the final server-side check.

Apex validates:

- Event is open for registration.
- Ticket Type belongs to Event.
- Ticket Type is available.
- Quota will not be exceeded.
- Booking is safe against concurrent attempts where applicable.

### If available

```text
Apex allows transaction
      ↓
Registration saved
      ↓
Post-registration Flow
      ↓
Ticket / confirmation process
```

### If unavailable

```text
Registration blocked
      ↓
No successful Registration
      ↓
No Ticket
      ↓
No confirmation
      ↓
UI tells attendee ticket type is unavailable
      ↓
Attendee may choose another available type
```

The system must never silently switch the attendee to another ticket type.

If every ticket type is sold out, show a sold-out state.

---

# 7. Organizer Workflow

Organizer launches Create Event Screen Flow.

## Step 1 — Basic Details

- Event Name
- Description
- Category
- Event Image where applicable
- Organizer/current user

## Step 2 — Date & Time

- Start Date/Time
- End Date/Time

Validation:

`End Date/Time > Start Date/Time`

## Step 3 — Venue

Select existing Venue.

Validation:

`Total Ticket Quota <= Venue Capacity`

## Step 4 — Dynamic Ticket Types

Organizer can dynamically add:

- Ticket Type Name
- Price
- Quota
- Description

System calculates:

- Booked Seats
- Available Seats
- Event Total Capacity

## Step 5 — Proposed Budget

Organizer enters Proposed Budget.

## Step 6 — Review

Display event configuration for confirmation.

## Step 7 — Submit

Event enters the approval/publication lifecycle.

---

# 8. Approval Workflow

Approved and Published are separate states.

```text
Organizer creates Event
        ↓
Submit
        ↓
Budget / Approval evaluation
       /       /   No approval  Approval required
    ↓              ↓
 Approved     Pending Approval
                    ↓
              Event Manager
                 /                   Approve     Reject
```

## Approval

```text
Pending Approval
      ↓
Approved
      ↓
Organizer may Publish
```

Approval does not automatically publish the event.

## Rejection

```text
Pending Approval
      ↓
Rejected
      ↓
Organizer notified
```

Organizer gets exactly two options:

### A. Edit & Resubmit

Organizer changes event details/budget and resubmits.

Approval logic evaluates the current event again.

### B. Cancel Event

Event becomes Cancelled.

The event remains in Salesforce for history/audit and cannot be published or booked.

Rejected events are not visible/bookable to attendees.

Manager rejection comments/reason should be stored.

The original workflow discussion established the separate Approved/Published concept and rejection options. fileciteturn1file0L785-L791

---

# 9. Event Lifecycle

Recommended lifecycle:

```text
Draft
  ↓
Pending Approval
  ↓
Approved
  ↓
Published
  ↓
Registration Open
  ↓
Registration Closed
  ↓
Completed
```

Additional states:

- Rejected
- Cancelled

Important distinctions:

- Approved ≠ Published.
- Published ≠ Registration Open.
- Registration Open is the point at which Ticket Type Price and Quota become locked.
- Rejected events cannot be booked.
- Cancelled events cannot be published or booked.

---

# 10. Price and Quota Locking

This is a hard business rule.

Before Registration Opens:

```text
Organizer can configure/edit Price
Organizer can configure/edit Quota
```

Once Registration Opens:

```text
Ticket Price → LOCKED
Ticket Quota → LOCKED
```

Only system-controlled inventory fields may continue changing:

```text
Booked Seats
Available Seats
```

Quota must also never be reduced below existing bookings before registration opens.

---

# 11. Reminder Workflow

Scheduled Flow:

**Exactly 24 hours before Event Start Date/Time**

```text
Event Start
   ↑
24 Hours
   ↑
Scheduled Flow
   ↓
Reminder
```

The reminder is based on the exact Date/Time, not merely the event date.

The original project specifically requires a Scheduled Flow for event reminders. fileciteturn0file0L49-L52

---

# 12. Feedback Workflow

Scheduled Flow:

**Exactly 10 hours after Event End Date/Time**

```text
Event Ends
   ↓
+10 Hours
   ↓
Scheduled Flow
   ↓
Find relevant registered attendees
   ↓
Send feedback request/form
   ↓
Attendee submits
   ↓
Feedback record
```

The original design specifies this post-event feedback lifecycle, with Feedback supporting event, attendee, and registration context. fileciteturn1file0L583-L633

---

# 13. Record-Triggered Flow

Runs after a successful Registration is created.

Purpose:

- Perform post-registration automation.
- Trigger downstream booking actions.
- Handle confirmation-related actions.
- Create/update relevant operational records where appropriate.

Important architecture rule:

**Do not allow Apex and Flow to independently and inconsistently maintain the same seat counter.**

There must be one authoritative inventory-update design.

---

# 14. Apex Trigger

The Apex Trigger is the final gatekeeper for registration availability.

Requirements:

- Prevent registrations beyond Ticket Type quota.
- Validate Event/Ticket Type consistency.
- Be bulkified.
- No SOQL inside loops.
- No DML inside loops.
- Handle bulk registrations.
- Handle concurrent booking attempts safely where applicable.
- Return useful errors to the booking UI.

The original project explicitly requires an Apex Trigger for capacity protection and bulk-safe implementation. fileciteturn0file0L57-L60

---

# 15. Apex Test Class

Test:

1. Successful registration.
2. Available ticket type.
3. Zero availability.
4. Attempt beyond quota.
5. Invalid Event/Ticket Type combination.
6. Multiple registrations.
7. Bulk registration.
8. Boundary conditions.
9. Error handling.

---

# 16. Security

Required Salesforce mechanisms:

- Profiles
- Permission Sets
- Permission Set Groups
- Organization-Wide Defaults
- Role Hierarchy
- Sharing Rules

High-level access:

| Role                | Main Access                                                              |
| ------------------- | ------------------------------------------------------------------------ |
| Attendee            | Own registrations/tickets/payments/feedback + eligible event information |
| Organizer           | Own events + operational records                                         |
| Event Manager       | Event management + approval                                              |
| Registration Team   | Registration/attendee operations                                         |
| Finance             | Payments/financial data                                                  |
| Speaker Coordinator | Speakers/Event Speakers                                                  |
| Admin               | Full access                                                              |

Profiles/Permission Sets control capabilities at object/field level.

OWD, Role Hierarchy and Sharing control record-level access.

The source specification explicitly requires these security topics. fileciteturn0file0L88-L94

---

# 17. Record Types and Quick Actions

Use Record Types where different business processes/page layouts genuinely require them.

Do not create Record Types simply to replace normal picklists.

Use Quick Actions for frequently performed operations where useful.

Final allocation is to be decided during UI/configuration design.

---

# 18. UI

Required:

- Custom object tabs
- Page layouts
- Lightning Record Pages
- Related lists
- Role-appropriate experiences

## Attendee LWC

Should support:

- Event discovery
- Event details
- Ticket types
- Prices
- Available seats
- Booking entry point
- Sold-out messaging
- Alternative ticket-type selection

## Organizer Dashboard LWC

Should show:

- My Events
- Upcoming/completed events
- Registrations
- Seats
- Revenue
- Event status
- Search/filter
- Create Event

The project requires at least two LWCs and specifically calls for an event dashboard showing registrations, seats, revenue, status, and search/filter capability. fileciteturn0file0L66-L70

---

# 19. Visualforce

Printable ticket/pass:

```text
Ticket Number
Event Name
Attendee
Ticket Type
Event Date/Time
Venue
Ticket Status
```

The Ticket record is the source for the printable Visualforce page.

---

# 20. Reports

Reports should cover:

- Event registrations
- Ticket sales
- Revenue
- Ticket-type availability
- Attendance/registration status
- Event feedback
- Average ratings
- Speaker ratings
- Venue ratings
- Feedback volume

---

# 21. Dashboard

Dashboard should provide:

- Total events
- Event status
- Registrations
- Seats/bookings
- Revenue
- Ticket-type availability
- Feedback/rating metrics

---

# 22. End-to-End Demo

```text
Admin configures master data
        ↓
Organizer creates Event
        ↓
Select Venue
        ↓
Add dynamic Ticket Types
        ↓
Set Price + Quota
        ↓
Enter Budget
        ↓
Approval evaluation
        ↓
Manager Approves / Rejects
        ↓
Organizer Publishes approved Event
        ↓
Registration Opens
        ↓
Price + Quota Locked
        ↓
Attendee views Event
        ↓
Selects Ticket Type
        ↓
Screen Flow
        ↓
Apex availability check
      /        Success      Unavailable
    ↓             ↓
Registration   Choose another
    ↓           ticket type
Ticket
    ↓
Payment process
    ↓
Confirmation
    ↓
24-hour reminder
    ↓
Event
    ↓
+10 hours
    ↓
Feedback request
    ↓
Feedback record
    ↓
Reports / Dashboard
```

---

# 23. Open Decisions Before Implementation

These are the remaining items that must be explicitly finalized before the relevant build stage:

1. Exact budget threshold for mandatory Event Manager approval.
2. Exact payment position relative to Ticket creation.
3. Final Event status values and transitions.
4. Final Record Type allocation.
5. Final field-level security matrix.
6. Final OWD/Role Hierarchy/Sharing model.
7. Whether cancellation/refund needs a separate detailed workflow.
8. Exact authoritative mechanism for updating Booked Seats so Apex and Flow do not double-update inventory.

These are open implementation decisions and do not change the established core data model.

---

# 24. Implementation Order

1. Lock object list.
2. Lock relationship types.
3. Create custom objects.
4. Create relationship fields.
5. Create normal fields.
6. Create formulas and roll-ups.
7. Create validation rules.
8. Configure Record Types and Quick Actions.
9. Configure tabs, page layouts, and Lightning pages.
10. Configure Profiles and Permission Sets.
11. Configure OWD, Role Hierarchy, and Sharing.
12. Build Event Creation Screen Flow.
13. Build Registration Screen Flow.
14. Build Record-Triggered Flow.
15. Build Scheduled Reminder Flow.
16. Build Scheduled Feedback Flow.
17. Build Approval Process.
18. Build Apex Trigger.
19. Build Apex Test Class.
20. Build Visualforce printable ticket.
21. Build Attendee LWC.
22. Build Organizer Dashboard LWC.
23. Build Reports.
24. Build Dashboard.
25. Perform end-to-end testing.
26. Prepare final documentation and demonstration.

---

# 25. Mandatory Project Coverage

The completed project must demonstrate:

- Custom objects and fields
- Relationships
- Tabs
- Page layouts
- Lightning pages
- Formula fields
- Roll-up summaries
- Validation rules
- Record Types
- Quick Actions
- Profiles
- Permission Sets/Groups
- OWD
- Role Hierarchy
- Sharing
- Screen Flow
- Record-Triggered Flow
- Scheduled Flow
- Approval Process
- Apex Trigger
- SOQL
- DML
- Bulkification
- Test Class
- Visualforce
- At least two LWCs
- Reports
- Dashboard
- End-to-end testing

The original project specification explicitly lists these mandatory topics and deliverables. fileciteturn0file0L88-L117

---

# 26. Design Principles

1. One source of truth for inventory.
2. Do not create duplicate relationship fields simply for reverse navigation.
3. Apex is the final server-side overbooking protection.
4. LWC/Screen Flow handles user-facing UI.
5. Record-Triggered Flow runs background automation.
6. Ticket Price and Quota are immutable once Registration Opens.
7. Approved and Published remain separate states.
8. Preserve historical transaction information.
9. Use dynamic Ticket Types rather than fixed VIP/General fields.
10. Design security using both capability permissions and record-level sharing.
11. Avoid conflicting Apex/Flow updates to the same inventory fields.
