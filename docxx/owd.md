# 1. First: don't make "Manager" a separate Profile

Your requirement says **Event Organiser/Manager**, but the original specification names **Organizer** and separately requires an approval for high-budget events.

```text
ADMIN
  │
  ├── EVENT MANAGER / SENIOR ORGANIZER
  │
  ├── ORGANIZER
  │
  ├── REGISTRATION TEAM
  │
  ├── FINANCE
  │
  └── SPEAKER COORDINATOR
```

The **Manager** can be an Organizer with additional permission/approval authority rather than creating another completely separate profile.

That gives us a much cleaner Salesforce security demonstration.

---

# 2. Our profiles

Let's define **six functional user types**:

| Profile / User Type     | Main Responsibility                       |
| ----------------------- | ----------------------------------------- |
| **Attendee**            | Browse events and manage own bookings     |
| **Organizer**           | Create/manage events                      |
| **Event Manager**       | Manage/approve organizational activity    |
| **Registration Team**   | Manage attendee registrations             |
| **Finance**             | Manage payments and financial information |
| **Speaker Coordinator** | Manage speakers                           |
| **Admin**               | Full system administration                |

The original assignment explicitly specifies five organizational roles; **Attendee and Event Manager are our additions to make your workflow work properly**.

---

# 3. Attendee

We've already designed this, but let's formalize the security side.

### Can SEE

- Upcoming events
- Published event details
- Available seats
- Ticket types
- Their own registrations
- Their own tickets
- Their own payments
- Their own feedback

### Can CREATE

- Their registration through the booking Screen Flow
- Their feedback

### Can EDIT

Potentially:

- Their own attendee details
- Their own feedback before submission, depending on our design

### CANNOT SEE

- Other attendees
- Other attendees' registrations
- Event revenue
- Other people's payments
- Internal event budget
- Organizer information
- Finance information
- Internal reports
- Admin configuration

### CANNOT DO

- Create/update events
- Modify event capacity
- Modify ticket pricing
- Modify payments
- Approve budgets
- Manage speakers

---

# 4. Organizer

This is the person actually running events.

### Can SEE

Their assigned:

- Events
- Venues
- Speakers associated with their events
- Registrations for their events
- Tickets for their events
- Attendance information
- Available seats
- Event status
- Ticket sales
- Event revenue/statistics

### Can CREATE

- Events
- Event-related records
- Event/speaker associations

### Can EDIT

Their events:

- Event name
- Description
- Start Date/Time
- End Date/Time
- Venue
- Capacity
- Ticket types
- Proposed budget
- Event status

But **capacity shouldn't be freely manipulated once registrations exist**, because that could break our seat calculation. We'll enforce this with validation/business logic.

### Cannot directly approve their own high-budget event

This is important.

If:

```text
Organizer creates Event
        ↓
Budget > threshold
        ↓
Approval required
```

the Organizer **submits it for approval**, but a Manager approves/rejects it.

That gives us a genuine approval workflow instead of a fake one.

---

# 5. Event Manager

The Manager is basically the higher-level event authority.

### Can SEE

Everything an Organizer needs, plus:

- Events managed by organizers
- Event budgets
- Event performance
- Registration statistics
- Revenue statistics
- Available seats
- Reports relevant to event management

### Can CREATE/EDIT

Depending on our final design:

- Events
- Event configuration
- Event status
- Organizer assignments

### Can APPROVE

High-budget events.

Example:

```text
Proposed Budget = ₹2,00,000
             ↓
Threshold = ₹1,00,000
             ↓
Approval Required
             ↓
Event Manager
       ↙           ↘
   APPROVE        REJECT
```

The original assignment specifically requires manager approval when the proposed event budget exceeds a threshold.

### Important

The Manager should **not be able to approve their own request**.

We'll configure the approval routing accordingly.

---

# 6. Registration Team

This team handles registration-related operations.

### Can SEE

- Attendees
- Registrations
- Tickets
- Events
- Available seats
- Registration status

### Can CREATE

Potentially:

- Attendee records
- Registrations on behalf of attendees
- Relevant registration-related records

### Can EDIT

- Registration status
- Attendee details where operationally required
- Registration information

### Can SEE but NOT MODIFY

- Event capacity
- Ticket pricing
- Event budget
- Payments

### Cannot

- Approve event budgets
- Modify financial records
- Create/change events
- Manage speakers
- Change system security

This makes the Registration Team a good example of **limited object/record access**.

---

# 7. Finance

This role should be very restricted around financial data.

### Can SEE

- Payments
- Payment status
- Registration associated with payment
- Ticket information needed for reconciliation
- Event revenue
- Financial reports

### Can CREATE

- Payment records where appropriate

### Can EDIT

- Payment status
- Payment reference/details
- Other finance-specific fields

### Cannot

- Change event capacity
- Change ticket type/pricing
- Modify attendee personal information unnecessarily
- Create speakers
- Approve event budgets unless we specifically give them approval authority

### Important security demonstration

An Organizer may see:

```text
Event Revenue = ₹5,40,000
```

but shouldn't necessarily be able to modify the underlying Payment records.

Finance can manage those records.

---

# 8. Speaker Coordinator

This person's job is speakers.

### Can SEE

- Speakers
- Events
- Speaker-event relationships
- Relevant event information

### Can CREATE

- Speaker records
- Speaker assignments

### Can EDIT

- Speaker details
- Speaker-event assignments

### Cannot

- Modify payments
- Approve budgets
- Change registrations
- Modify attendee records
- Change ticket availability
- Modify event financial information

So their Salesforce experience is very focused.

---

# 9. Admin

Admin is the unrestricted system administrator.

### Can SEE

Everything.

```text
All Events
All Attendees
All Registrations
All Tickets
All Payments
All Speakers
All Feedback
All Reports
All Dashboards
```

### Can DO

Everything required to administer the system:

- Create/edit/delete records
- Configure objects
- Configure fields
- Manage Flows
- Manage Apex
- Manage users
- Manage permissions
- Configure sharing
- Configure reports/dashboards
- Configure Lightning pages
- Manage approval processes

This is obviously necessary for the actual Salesforce implementation.

---

# 10. Proposed OWD strategy

I'd make the important transactional objects relatively **private by default**.

For example:

| Object       | Proposed OWD |
| ------------ | ------------ |
| Event        | Private      |
| Registration | Private      |
| Ticket       | Private      |
| Payment      | Private      |
| Feedback     | Private      |
| Speaker      | Private      |
| Attendee     | Private      |
| Venue        | Private      |

Then we open access deliberately using roles/sharing.

### Why?

Because the assignment specifically wants us to demonstrate that different users **cannot access unauthorized data**.

If everything is Public Read/Write, our security demonstration becomes meaningless.

---

# 12. But attendees need to see published events

This is the interesting part.

An attendee needs to see:

> "Upcoming events"

but shouldn't see internal event data.

So we can expose **only the appropriate event information through the attendee-facing UI**, rather than simply making the entire Event object public.

For example:

```text
EVENT RECORD

PUBLIC INFORMATION
✓ Name
✓ Description
✓ Start Date/Time
✓ End Date/Time
✓ Venue
✓ Ticket Types
✓ Available Seats

INTERNAL INFORMATION
✗ Proposed Budget
✗ Internal Notes
✗ Organizer information
✗ Internal financial details
```

The LWC/Screen Flow can show only what the attendee is supposed to see.

---

# 13. Event ownership

I'd also introduce an **Event Organizer** relationship.

For example:

```text
Event: AI Summit 2026
Organizer: Rahul
Manager: Priya
```

Then:

```text
Organizer Rahul
       ↓
Can manage
       ↓
AI Summit 2026
```

But another organizer shouldn't automatically be able to modify Rahul's event.

That's where **OWD + Role Hierarchy + Sharing** becomes useful.

---

# 16. Event Status becomes important

I'd suggest these statuses:

```text
Draft
Pending Approval
Approved
Published
Registration Open
Registration Closed
Event Completed
Cancelled
Rejected
```

But **we don't necessarily need all of these**. We can simplify them once we design the Event object.

The critical distinction is:

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

This will make our attendee LWC much easier:

> Only show events that are actually available for registration.

---

# 1. profiles

## 1.1 Registration Team

### Main responsibility

The Registration Team handles the operational side of attendee registrations.

They are not event creators, not finance people, and not system admins.

### They can SEE

Attendee records
Events
Published events
Registrations
Tickets
Ticket Types
Available seats
Registration status
Attendance information

### They can CREATE

Attendee records, when assisting someone
Registration records, if a booking needs to be made on behalf of an attendee
Ticket-related records only where the business process requires it

But normally, the automated booking process should create the Registration/Ticket rather than the Registration Team manually creating them.

### They can EDIT

Registration-related information such as:
Registration status
Attendee details when correction is needed
Check-in/attendance status
Operational notes

### They CANNOT

Create or approve event budgets
Modify event budget
Modify payment amounts/status
Change ticket prices
Change ticket quotas
Change available seats manually
Manage speakers
Modify security settings
Important

The Registration Team should be able to see registrations for events they are responsible for, rather than automatically seeing every private registration in the entire organization.

## 1.2 Finance

### Main responsibility

Finance handles payments and financial information.
The original project explicitly includes Payment and requires reporting around revenue.

### They can SEE

Payment records
Payment status
Payment amount
Payment/reference information
Associated Registration
Associated Ticket
Associated Event
Event revenue
Financial reports

### They can CREATE

Payment records when required by the business process
Payment-related records

### They can EDIT

Finance-specific information such as:
Payment status
Transaction/reference ID
Payment verification information
Refund/payment remarks, if we decide to include them

### They CANNOT

Change Event capacity
Change Ticket Type quota
Change Ticket Type price
Modify attendee registrations
Create/edit speakers
Publish events
Approve their own financial/event requests
Manage Salesforce configuration

### Finance + Organizer relationship

The Organizer can see something like:
Event Revenue
₹7,50,000
But Finance manages the underlying payment information.
So:
ORGANIZER
↓
View event revenue/statistics

FINANCE
↓
Manage payment records

## 1.3 Speaker Coordinator

### Main responsibility

Everything related to speakers and their association with events.
The original project explicitly includes Speaker as a main object.

### They can SEE

Speaker records
Event records
Relevant event details
Speaker-event assignments
Speaker schedule/details

### They can CREATE

Speaker records
Speaker-event associations

### They can EDIT

Speaker information
Speaker contact/professional details
Speaker-event assignments
Speaker-related notes

### They CANNOT

Create or approve event budgets
Manage payments
Modify registrations
Change ticket prices
Change ticket quotas
Modify event budgets
Approve event budgets
Modify attendee information unnecessarily
Publish/cancel events unless we explicitly give that permission later

## 1.4 Admin

have all the power bro

### Admin can:

Create/edit/delete all relevant records
Manage users
Manage profiles/permissions
Manage sharing
Manage objects/fields
Manage Flows
Manage Approval Processes
Manage Apex
Manage Visualforce
Manage LWCs
Manage Reports/Dashboards
View all events
View all registrations
View all tickets
View all payments
View all speakers
View all feedback

## Final role structure

                         ADMIN
                           │
             ┌─────────────┼─────────────┐
             │             │             │
             ▼             ▼             ▼
        EVENT MANAGER   ORGANIZER     FINANCE
             │             │
             │             │
             │             └───────┐
             │                     │
             ▼                     ▼
       Approval Process       Event Management
                                   │
                   ┌───────────────┼───────────────┐
                   ▼               ▼               ▼
            REGISTRATION       SPEAKER          ATTENDEE
               TEAM           COORDINATOR

## Final permission overview

| Capability            | Attendee |  Organizer |      Manager | Registration | Finance | Speaker Coord. | Admin |
| --------------------- | -------: | ---------: | -----------: | -----------: | ------: | -------------: | ----: |
| View published events |       ✅ |         ✅ |           ✅ |           ✅ |      ✅ |             ✅ |    ✅ |
| Book registration     |       ✅ |          — |            — |           ✅ |      ❌ |             ❌ |    ✅ |
| Manage registrations  |      Own |   Assigned |     Relevant |           ✅ |      ❌ |             ❌ |    ✅ |
| Create events         |       ❌ |         ✅ |           ✅ |           ❌ |      ❌ |             ❌ |    ✅ |
| Manage events         |       ❌ |        Own | All relevant |           ❌ |      ❌ |   Limited view |    ✅ |
| Manage ticket types   |       ❌ |         ✅ |           ✅ |           ❌ |      ❌ |             ❌ |    ✅ |
| Manage ticket quotas  |       ❌ |       ✅\* |           ✅ |           ❌ |      ❌ |             ❌ |    ✅ |
| View revenue          |       ❌ | Own events |           ✅ |           ❌ |      ✅ |             ❌ |    ✅ |
| Manage payments       |       ❌ |         ❌ |           ❌ |           ❌ |      ✅ |             ❌ |    ✅ |
| Manage speakers       |       ❌ |       View |         View |           ❌ |      ❌ |             ✅ |    ✅ |
| Approve event budget  |       ❌ |         ❌ |           ✅ |           ❌ |      ❌ |             ❌ |    ✅ |
| View feedback         |      Own | Own events |           ✅ |  Operational |      ❌ |             ❌ |    ✅ |
| Manage security       |       ❌ |         ❌ |           ❌ |           ❌ |      ❌ |             ❌ |    ✅ |

# 2. Permission set

Profiles

- Permission Sets
- Permission Set Groups
- OWD
- Role Hierarchy
- Sharing Rules

## Finance

Finance Profile +
Finance Permission Set +
Financial Reports Permission Set

## Registration Team

Registration Profile +
Registration Management Permission Set

## Organizer

Organizer Profile +
Event Management Permission Set +
Event Dashboard Permission Set
