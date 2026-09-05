# Data Model — Objects, Fields, Types, Required

**Revision note (this version):** Removed the **Event Speaker** junction object. A Speaker no
longer needs to appear at multiple Events, so the many-to-many relationship collapses to a
direct lookup: `Speaker.Event__c`. If the same person speaks at more than one event, create a
separate Speaker record per event rather than reusing one record — acceptable at this
project's scope. This also removes the `No_Duplicate_Speaker_On_Event` concern from
`validationrules.md` (a direct lookup can't produce the duplicate-pair problem a junction
could). Everything else is unchanged from the prior version (which added `Attendee.User__c`).

This reflects the decisions locked in `prd.md`: Registration→Event is Master-Detail (not
Lookup), Ticket carries only Registration as its relationship field (Event/Attendee/Ticket
Type are reached through Registration, per the "no duplicate relationship fields" design
principle), Ticket Type→Event confirmed as Master-Detail.

Field name legend: **(R)** = Required, **(O)** = Optional. "System" = system-controlled,
never directly editable by end users through the UI.

---

## 1. Event

| Field | Type | Required | Notes |
|---|---|---|---|
| Event Name | Text (255) | R | |
| Description | Long Text Area | O | |
| Category | Picklist | R | e.g. Conference, Workshop, Webinar |
| Start Date/Time | Date/Time | R | Must be in the future at creation |
| End Date/Time | Date/Time | R | Must be > Start Date/Time |
| Venue | Lookup(Venue) | R | |
| Organizer | Lookup(User) | R | Defaults to current user |
| Proposed Budget | Currency | R | Drives approval routing |
| Approval Status | Picklist | R | Draft / Pending Approval / Approved / Rejected — System-set, Admin override only |
| Publication Status | Picklist | R | Unpublished / Published — System-set |
| Registration Status | Picklist | R | Not Open / Open / Closed — System-set |
| Total Capacity | Roll-Up Summary (SUM of Ticket Type Quota) | System | |
| Booked Seats | Roll-Up Summary (SUM of Ticket Type Booked Seats) | System | |
| Available Seats | Formula (Total Capacity − Booked Seats) | System | |
| Rejection Reason | Long Text Area | O | Populated by Event Manager on reject |
| Cancelled Flag / Status | Picklist (part of overall status) | O | See lifecycle note below |

**Overall Event Status** (if modeled as a single consolidated picklist instead of three
separate status fields): Draft, Pending Approval, Approved, Rejected, Cancelled, Published,
Registration Open, Registration Closed, Completed. Whether this is one field or three is a
UI/reporting decision — either is valid as long as Approved ≠ Published is preserved.

> Speakers for an Event are now reached via the reverse related list from `Speaker.Event__c`
> (see §9) rather than through a junction — no direct relationship field lives on Event itself.

---

## 2. Venue

| Field | Type | Required | Notes |
|---|---|---|---|
| Venue Name | Text (255) | R | |
| Address | Text (255) / Text Area | O | |
| City | Text (100) | R | |
| Venue Capacity | Number | R | Ceiling for total ticket quota |
| Contact Person | Text (120) | O | |
| Contact Phone | Phone | O | |
| Status | Picklist | R | Active / Inactive |

---

## 3. Ticket Type

| Field | Type | Required | Notes |
|---|---|---|---|
| Ticket Type Name | Text (80) | R | e.g. VIP, General |
| Event | Master-Detail(Event) | R | |
| Price | Currency | R | Locked once Registration Opens |
| Quota | Number | R | Locked once Registration Opens; ≥ Booked Seats |
| Booked Seats | Number (Roll-Up from Registration count) | System | |
| Available Seats | Formula (Quota − Booked Seats) | System | |
| Description | Long Text Area | O | |
| Status | Picklist | R | Available / Sold Out / Closed |

---

## 4. Registration

| Field | Type | Required | Notes |
|---|---|---|---|
| Registration Number | Auto Number | System | e.g. REG-00001 |
| Event | **Master-Detail(Event)** | R | Corrected from Lookup in the earlier draft |
| Attendee | Lookup(Attendee) | R | |
| Ticket Type | Lookup(Ticket Type) | R | Must belong to the same Event |
| Registration Date/Time | Date/Time | System | Defaults to created date |
| Registration Status | Picklist | R | Pending / Confirmed / Cancelled / Rejected. **Created as Pending** by the booking Screen Flow; flipped to **Confirmed** exclusively by `EventBookingController.confirmPayment` after the 10-second QR payment-verification step completes (see `flows.md`) |
| Booked Price / Amount | Currency | R | Price snapshot at booking time — not a live lookup |
| Confirmation Status | Picklist | R | Not Sent / Sent / Failed |

---

## 5. Ticket

| Field | Type | Required | Notes |
|---|---|---|---|
| Ticket Number | Auto Number | System | e.g. TKT-00001 |
| Registration | **Master-Detail(Registration)** | R | **Only** relationship field on this object |
| Issue Date/Time | Date/Time | System | Set at ticket generation |
| Ticket Status | Picklist | R | Active / Cancelled / Used |

> Event, Attendee, and Ticket Type are intentionally **not** duplicated on Ticket. They are
> reached via `Ticket → Registration → Event / Attendee / Ticket Type`. This corrects the
> earlier draft, which had put direct lookups for all three on Ticket — a violation of the
> "no duplicate relationship fields" principle and a data-integrity risk (a direct lookup could
> drift out of sync with what the parent Registration actually says).

---

## 6. Payment

| Field | Type | Required | Notes |
|---|---|---|---|
| Payment Number | Auto Number | System | |
| Registration | Lookup(Registration) | R | Lookup, not Master-Detail — payment history should be able to persist independently of registration edits |
| Amount | Currency | R | Set by `confirmPayment` from `Registration.Booked_Price__c` — never accepted as raw client input |
| Payment Date/Time | Date/Time | R | Set server-side to `Datetime.now()` at confirmation |
| Payment Status | Picklist | R | Pending / Successful / Failed / Refunded — `confirmPayment` inserts as "Successful" (QR flow has no partial/failed capture state in this design) |
| Payment Method | Picklist | R | Card / UPI / Cash / Other — `confirmPayment` inserts as "UPI" (QR-code payment path) |
| Transaction Reference | Text (100) | O | Required only when Payment Status = Successful (validation rule). Populated from the session reference generated client-side by the `paymentQrVerification` LWC and embedded in the QR payload |

**Sequencing (resolved):** Payment record is created **before** the Registration's status
update to Confirmed, within the same `confirmPayment` transaction. The Registration status
change is what triggers `Post_Registration_Automation` (Flow 2) to create the Ticket. See
`flows.md` for the full chain.

---

## 7. Attendee

| Field | Type | Required | Notes |
|---|---|---|---|
| Name | Standard Name | R | |
| Email | Email | R | Used for confirmations/reminders/feedback |
| Phone | Phone | O | |
| Organization | Text (120) | O | |
| Attendee Status | Picklist | R | Active / Inactive |
| User | Lookup(User) | O | Binds a portal/community Attendee record to the logged-in Salesforce User, when one exists. Nullable — Registration Team can create Attendee records on someone's behalf without that person having a User account (e.g. phone/walk-in registration). Used by `EventBookingController.confirmPayment` to verify the calling user owns the Registration before allowing a payment/status update; also the primary match key (ahead of Email) when the booking flow checks for an existing Attendee record. |

Related activity:

- Registrations
- Tickets
- Payments
- Feedback

---

## 8. Venue

(unchanged — see §2)

---

## 9. Speaker

| Field | Type | Required | Notes |
|---|---|---|---|
| Speaker Name | Text (120) | R | |
| Email | Email | O | |
| Phone | Phone | O | |
| Organization | Text (120) | O | |
| Expertise | Text (255) / Long Text | O | |
| Bio | Long Text Area | O | |
| Status | Picklist | R | Active / Inactive |
| **Event** | **Lookup(Event)** | **O** | **New — replaces the Event Speaker junction.** A Speaker now belongs to at most one Event. If a person speaks at multiple events, create a separate Speaker record per event. Optional because a Speaker record could theoretically be entered before it's assigned to a specific event, or an event might have no speakers at all. |

> **Why Lookup, not Master-Detail:** a Speaker record's relevance (bio, contact info) can
> reasonably persist independently of whether the specific Event still exists or is later
> cancelled — Master-Detail would force cascade-delete behavior that isn't wanted here, and
> Speaker doesn't need Event-level roll-ups the way Ticket Type does.

---

## 10. Feedback

| Field | Type | Required | Notes |
|---|---|---|---|
| Feedback Number | Auto Number | System | |
| Event | Lookup(Event) | R | |
| Attendee | Lookup(Attendee) | R | |
| Registration | Lookup(Registration) | R | Used to enforce one feedback per registration |
| Overall Rating | Number / Picklist (1–5) | R | |
| Event Experience | Number / Picklist (1–5) | O | |
| Speaker Rating | Number / Picklist (1–5) | O | Only relevant if event had a speaker |
| Venue Rating | Number / Picklist (1–5) | O | |
| Comments | Long Text Area | O | |
| Submitted Date/Time | Date/Time | System | |

---

## Object count (updated)

**9 objects total** (down from 10): Event, Venue, Ticket Type, Registration, Ticket, Payment,
Attendee, Speaker, Feedback. Event Speaker removed.

---

## Changelog

| Version | Change |
|---|---|
| This version | Removed Event Speaker junction object. Added `Speaker.Event__c` (Lookup) as its direct replacement. Updated Event's notes to reflect Speakers are now reached via reverse related list, not a junction. |
| Prior version | Added `Attendee.User__c` (Lookup to User) to support ownership verification in `confirmPayment`. |
| Earlier version | Corrected Registration→Event to Master-Detail; corrected Ticket to carry only the Registration relationship field. |
