# Relationship Model & Schema Architecture

> **Module:** Entity Relationships & Data Architecture  
> **Source of Truth:** `objects/*/fields/*.field-meta.xml` & `ROLE_1_DATA_MODEL_AND_WORKFLOW.md`  
> **Master Relationships:** **3 Master-Detail Relationships**  
> **Lookup Relationships:** **11 Custom Lookup Relationships**  
> **Total Active Relational Links:** **14 Schema Connections**

---

## 1. Complete Relationship Matrix (14 Connections)

| # | Child Object | Relationship Field | Type | Parent Object | Required? | Relationship Name | Architectural Justification |
|---|---|---|---|---|:---:|---|---|
| 1 | **`Event__c`** | `Venue__c` | **Lookup** | `Venue__c` | **Yes** | `Events` | Venues are independent physical assets that outlive any individual event. Cascade delete is strictly disabled to prevent loss of venue inventory. |
| 2 | **`Event__c`** | `Organizer__c` | **Lookup** | `User` | No | `Organized_Events` | Standard user assignment link. User accounts must never cascade delete if an event is removed. |
| 3 | **`Event__c`** | `Approved_By__c` | **Lookup** | `User` | No | `Approved_Events` | Audit trail link indicating which Manager approved the event budget. |
| 4 | **`Ticket_Type__c`** | `Event__c` | **Master-Detail** | `Event__c` | **Yes** | `Ticket_Types` | **Enables native Roll-up Summaries** on `Event__c` (`Total_Capacity__c`, `Booked_Seats__c`). Ticket tiers have no independent business meaning without their parent event. |
| 5 | **`Registration__c`** | `Event__c` | **Master-Detail** | `Event__c` | **Yes** | `Registrations` | Connects the booking record to the event lifecycle. Deleting an event cascades to clean up registrations automatically. |
| 6 | **`Registration__c`** | `Ticket_Type__c` | **Lookup** | `Ticket_Type__c` | **Yes** | `Registrations` | Links registration to the specific pricing tier without imposing a secondary Master-Detail constraint. |
| 7 | **`Registration__c`** | `Attendee__c` | **Lookup** | `Attendee__c` | **Yes** | `Registrations` | Attendees exist independently of individual events (one customer attends multiple events over time). |
| 8 | **`Ticket__c`** | `Registration__c` | **Master-Detail** | `Registration__c` | **Yes** | `Tickets` | A physical ticket pass only exists if a registration succeeded. Deleting a registration cascades to delete the ticket. |
| 9 | **`Payment__c`** | `Registration__c` | **Lookup** | `Registration__c` | **Yes** | `Payments` | **Intentionally Lookup, NOT Master-Detail:** Financial audit records must persist even if a registration is modified. Allows Finance to maintain separate record-level access. |
| 10| **`Speaker__c`** | `Event__c` | **Lookup** | `Event__c` | No | `Speakers` | Direct lookup architecture. Speakers can exist as independent contacts or belong to an event without forced cascade deletion. |
| 11| **`Feedback__c`** | `Event__c` | **Lookup** | `Event__c` | **Yes** | `Feedback` | Post-event review linked to the overall event. Kept as Lookup to prevent survey data from interfering with event lifecycle locks. |
| 12| **`Feedback__c`** | `Attendee__c` | **Lookup** | `Attendee__c` | **Yes** | `Feedback` | Identifies which attendee provided the review. |
| 13| **`Feedback__c`** | `Registration__c` | **Lookup** | `Registration__c` | **Yes** | `Feedback` | Guarantees that only attendees with a valid confirmed registration can submit feedback (`One_Feedback_Per_Registration` rule). |
| 14| **`Attendee__c`** | `User__c` | **Lookup** | `User` | No | `Attendees` | Binds a community/portal attendee to their Salesforce User ID for controller ownership checks and portal security. |

---

## 2. Visual Entity Relationship Diagram (ERD)

```
                       ┌─────────────────────────┐
                       │        Venue__c         │
                       │─────────────────────────│
                       │ Name                    │
                       │ Venue_Capacity__c       │
                       │ City__c                 │
                       └────────────┬────────────┘
                                    │ 1
                                    │
                                    │ N (Lookup: Required)
                                    ▼
┌─────────────────────────┐   ┌─────────────────────────┐   ┌─────────────────────────┐
│          User           │───│        Event__c         │───│       Speaker__c        │
│    (Event Manager)      │ 1 │─────────────────────────│ N │─────────────────────────│
│ (Organizer / Approver)  │   │ Category__c             │   │ Name                    │
└─────────────────────────┘   │ Proposed_Budget__c      │   │ Bio__c / Email__c       │
                              │ Approval_Status__c      │   │ Event__c (Lookup)       │
                              │ Total_Capacity__c (RS)  │   └─────────────────────────┘
                              │ Booked_Seats__c (RS)    │
                              │ Available_Seats__c (FX) │
                              └───────┬─────────┬───────┘
                                      │ 1       │ 1
                                      │         │
                 ┌────────────────────┘         └───────────────────┐
                 │ M-D (1:N)                                        │ M-D (1:N)
                 ▼                                                  ▼
   ┌─────────────────────────┐                        ┌─────────────────────────┐
   │     Ticket_Type__c      │                        │     Registration__c     │
   │─────────────────────────│                        │─────────────────────────│
   │ Quota__c                │◀──────(Lookup)─────────│ Booking_Group_Id__c     │
   │ Price__c                │ 1                    N │ Booked_Price__c         │
   │ Booked_Seats__c         │                        │ Registration_Status__c  │
   │ Available_Seats__c (FX) │                        └───────┬─────────┬───────┘
   └─────────────────────────┘                                │ 1       │ 1
                                                               │         │
                                      ┌────────────────────────┘         └───────────────────┐
                                      │ M-D (1:N)                                            │ Lookup (1:N)
                                      ▼                                                      ▼
                        ┌─────────────────────────┐                            ┌─────────────────────────┐
                        │        Ticket__c        │                            │       Payment__c        │
                        │─────────────────────────│                            │─────────────────────────│
                        │ Ticket_Status__c        │                            │ Amount__c               │
                        │ Issue_Date_Time__c      │                            │ Payment_Status__c       │
                        │ Registration__c (M-D)   │                            │ Payment_Method__c       │
                        └─────────────────────────┘                            │ Transaction_Reference__c│
                                                                               └─────────────────────────┘
                                                  ▲
                                                  │ Lookup
                        ┌─────────────────────────┴───────────────┐
                        │                   Feedback__c           │
                        │─────────────────────────────────────────│
                        │ Event__c (Lookup)                       │
                        │ Attendee__c (Lookup)                    │
                        │ Registration__c (Lookup)                │
                        │ Overall_Rating__c (1-5)                 │
                        └─────────────────────────────────────────┘
```

---

## 3. Deep-Dive: Master-Detail vs. Lookup Decisions

### 1. Why `Ticket_Type__c → Event__c` is Master-Detail
1. **Roll-up Summary Requirement:** In Salesforce, **Roll-Up Summary fields are ONLY permitted across Master-Detail relationships**. The `Event__c` record maintains two mission-critical real-time roll-up fields:
   - `Total_Capacity__c`: `SUM(Ticket_Type__c.Quota__c)`
   - `Booked_Seats__c`: `SUM(Ticket_Type__c.Booked_Seats__c)`
   Without Master-Detail, roll-ups could not exist declaratively and would require extensive trigger logic.
2. **Lifecycle Dependency:** A ticket tier (e.g. VIP ₹5,000 for "Dreamforce 2026") cannot exist without its parent event. Deleting an event cleanly removes its ticket tiers.

### 2. Why `Registration__c → Event__c` is Master-Detail
1. **Event Lifecycle Governance:** Bookings are intrinsically bound to an event. If an event is cancelled or purged from the database, orphaned registrations must not remain.
2. **Security & Sharing Inheritance:** The OWD for `Registration__c` is set to **Controlled by Parent**. Detail records automatically inherit the security settings of `Event__c` (Private).

### 3. Why `Ticket__c → Registration__c` is Master-Detail
1. **Single Relationship Principle:** `Ticket__c` has **only one relationship field** in the entire schema: `Registration__c`. It deliberately does not duplicate lookups to Event, Attendee, or Ticket Type.
2. **Cascade Integrity:** A ticket entry pass has no purpose without an approved registration. Deleting a registration automatically voids and cascades to delete the issued pass.

### 4. Why `Payment__c → Registration__c` was Kept as Lookup (NOT Master-Detail)
1. **Financial Audit Isolation:** Under enterprise accounting principles, financial payment transactions must **never cascade delete** if an event or registration record is corrected or deleted.
2. **Independent OWD & Sharing:** Allows Finance team members to have dedicated object-level and field-level permissions on `Payment__c` without requiring broad modify-all permissions on registrations.

### 5. Why `Speaker__c → Event__c` is a Direct Lookup (No Junction Object)
1. **Schema Simplicity:** In earlier designs, a many-to-many junction (`Event_Speaker__c`) was proposed. However, in our architecture, keynotes and presenters are assigned directly to events via `Speaker__c.Event__c`.
2. **Decoupled Lifecycle:** Speaker bio data can be entered into the CRM prior to final event scheduling and persists even if an event is cancelled.

---

## 4. Cardinality & Multiplicity Reference

```
[1] Venue__c            ─── (0..N) Event__c
[1] User (Organizer)    ─── (0..N) Event__c
[1] User (Approver)     ─── (0..N) Event__c
[1] Event__c            ─── (1..N) Ticket_Type__c  (Master-Detail)
[1] Event__c            ─── (0..N) Registration__c (Master-Detail)
[1] Attendee__c         ─── (0..N) Registration__c (Lookup)
[1] Ticket_Type__c      ─── (0..N) Registration__c (Lookup)
[1] Registration__c     ─── (0..1) Ticket__c       (Master-Detail)
[1] Registration__c     ─── (0..N) Payment__c      (Lookup)
[1] Event__c            ─── (0..N) Feedback__c     (Lookup)
[1] Registration__c     ─── (0..1) Feedback__c     (Lookup - guarded by validation rule)
[1] User (Portal User)  ─── (0..N) Attendee__c     (Lookup)
[1] Event__c            ─── (0..N) Speaker__c      (Lookup)
```

---

## 5. Viva / Oral Defense Questions for Relationships

### Q1: "Why did you use Master-Detail for `Ticket_Type__c` and `Registration__c`, but Lookup for `Payment__c` and `Attendee__c`?"
> **Answer:** *"Sir, Master-Detail on `Ticket_Type__c` and `Registration__c` to `Event__c` enables native Roll-Up Summary fields (`Total_Capacity__c` and `Booked_Seats__c`) on the Event record with zero Apex code. It also guarantees cascading cleanup if an event is deleted.  
> In contrast, `Payment__c` uses a Lookup because financial records must be preserved for accounting audit trails even if a registration is modified or deleted. `Attendee__c` uses a Lookup because an attendee represents a persistent individual customer who can register for multiple events across the year."*

### Q2: "Can you change a Lookup relationship to a Master-Detail relationship in an active Salesforce org?"
> **Answer:** *"Yes, Sir, but only under two strict conditions:  
> 1. All existing records in the child object must have a value in that lookup field (no null values).  
> 2. The parent object cannot already have reached the limit of 2 Master-Detail relationships."*

### Q3: "Why doesn't `Ticket__c` have lookups to `Event__c` and `Attendee__c`?"
> **Answer:** *"Sir, following Salesforce normalized relational design and the 'Single Source of Truth' principle, `Ticket__c` points only to `Registration__c`. The event, venue, and attendee details are traversed relationship-wise (`Registration__r.Event__r.Name`, `Registration__r.Attendee__r.Email__c`). Adding duplicate lookups would risk data drift and unnecessary schema overhead."*
