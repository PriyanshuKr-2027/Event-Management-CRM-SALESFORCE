# Relationship Model — Lookup vs Master-Detail

**Revision note (this version):** Removed the **Event Speaker** junction object and its two
Master-Detail rows. Replaced with a single direct `Speaker.Event__c` Lookup — see §1 and §4
below. This is a simplification, not a data-loss concern: nothing else in the project (Apex,
Flows, Validation Rules) referenced Event Speaker directly.

Rule followed throughout: relationship fields are created **once**, on the child object only.
Salesforce's automatic related list on the parent covers the reverse direction — a second
field is never created just to represent that reverse direction.

---

## 1. Relationship table

| Child Object | Relationship Field | Type | Parent Object | Why this type |
|---|---|---|---|---|
| Event | Venue | Lookup | Venue | Event should survive independently of Venue edits/archival; no cascade-delete needed |
| Event | Organizer | Lookup | User | Standard ownership-style reference; User records are never deleted alongside Events |
| Ticket Type | Event | **Master-Detail** | Event | Ticket Type has no meaning without its Event; needed for roll-ups (Total Capacity, Booked Seats) up to Event |
| Registration | Event | **Master-Detail** | Event | Corrected from Lookup — Registration cannot exist without a parent Event, and Event-level reporting/rollups depend on this being Master-Detail |
| Registration | Attendee | Lookup | Attendee | Attendee record persists independently of any single registration |
| Registration | Ticket Type | Lookup | Ticket Type | Needs to reference Ticket Type without forcing ownership/cascade-delete inheritance from Ticket Type |
| Ticket | Registration | **Master-Detail** | Registration | A Ticket only exists because a Registration succeeded; deleting the Registration should remove the Ticket. This is the **only** relationship field on Ticket — Event/Attendee/Ticket Type are reached via this path |
| Payment | Registration | Lookup | Registration | Deliberately Lookup, not Master-Detail — payment/financial history must be able to persist for audit even if the Registration record is later modified or its status changes; also lets Finance own sharing on Payment independently |
| Feedback | Event | Lookup | Event | |
| Feedback | Attendee | Lookup | Attendee | |
| Feedback | Registration | Lookup | Registration | Used to enforce "one Feedback per Registration" via validation rule, not via Master-Detail cascade |
| Attendee | User | Lookup | User | New — binds a portal/community Attendee record to its Salesforce User for ownership checks in `EventBookingController.confirmPayment`. Nullable, since not every Attendee has a User account (walk-in/phone registrations created by Registration Team) |
| **Speaker** | **Event** | **Lookup** | **Event** | **New — replaces the Event Speaker junction.** A Speaker now belongs to at most one Event; a person speaking at multiple events gets a separate Speaker record per event |

> ~~Event Speaker | Event | Master-Detail | Event~~ — **removed this version**
> ~~Event Speaker | Speaker | Master-Detail | Speaker~~ — **removed this version**

---

## 2. Relationship meaning (cardinality)

```
Venue          1 ── * Event
User(Organizer)1 ── * Event
Event          1 ── * Ticket Type
Event          1 ── * Registration
Attendee       1 ── * Registration
Ticket Type    1 ── * Registration
Registration   1 ── 1 Ticket        (one successful Registration produces at most one Ticket)
Registration   1 ── * Payment       (retries / partial payments possible)
Event          1 ── * Feedback
Attendee       1 ── * Feedback
Registration   1 ── ≤1 Feedback     (enforced by validation rule, not schema)
User           1 ── * Attendee      (optional — an Attendee may have no linked User)
Event          1 ── * Speaker       (a Speaker belongs to at most one Event; a person
                                     speaking at several events needs one Speaker record each)
```

---

## 3. Why each Master-Detail was chosen (cascade + rollup reasoning)

- **Ticket Type → Event**: needs Master-Detail so Event can roll up `Total Capacity` and
  `Booked Seats` from its Ticket Types using native Roll-Up Summary fields. Roll-Up Summary
  fields require Master-Detail.
- **Registration → Event**: same reasoning — without Master-Detail, Event cannot natively
  roll up registration-derived counts, and a Registration orphaned from its Event would be a
  data-integrity hole.
- **Ticket → Registration**: a Ticket has zero business meaning without a successful
  Registration behind it. Master-Detail also lets deleting a Registration (e.g. an
  admin-corrected erroneous booking) cascade-delete its Ticket cleanly.

## 4. Why the Lookups were deliberately kept as Lookup (not Master-Detail)

- **Event → Venue / Event → Organizer**: Venues and Users are shared master data that must
  outlive any single Event and must never be affected by an Event's sharing/ownership rules.
- **Registration → Attendee / Registration → Ticket Type**: both are shared reference-type
  records used across many Registrations; Master-Detail would force them to inherit
  Registration's OWD/sharing behavior, which is wrong for records that are naturally
  independent.
- **Payment → Registration**: intentionally Lookup so Finance retains its own record-level
  control over Payment (per the security/OWD model) and so payment/audit history isn't at
  risk of cascade-delete if a Registration record is later modified.
- **Feedback → Event / Attendee / Registration**: Feedback is a downstream, optional,
  time-delayed artifact (created up to 10 hours after event end) — it should never be
  cascade-tied to the lifecycle of Event, Attendee, or Registration records.
- **Attendee → User**: a User account's lifecycle (deactivation, deletion) shouldn't cascade
  into historical Attendee/Registration/Ticket data.
- **Speaker → Event**: kept as Lookup, not Master-Detail — a Speaker's contact/bio information
  can reasonably outlive the specific Event it was originally tied to (e.g. if the Event is
  later cancelled, the Speaker record itself is still legitimate reference data), and Speaker
  doesn't need any Event-level roll-up the way Ticket Type does.

---

## Changelog

| Version | Change |
|---|---|
| This version | Removed Event Speaker junction (both Master-Detail rows). Added `Speaker.Event__c` (Lookup) as direct replacement. Added `Attendee.User__c` (Lookup) row, carried over from the data model revision. |
| Prior version | Established Registration→Event as Master-Detail; Ticket carries only Registration as its relationship field. |
