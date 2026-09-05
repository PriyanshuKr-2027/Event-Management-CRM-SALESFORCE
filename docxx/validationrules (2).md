# Validation Rules

**Revision note (this version):** `No_Registration_On_Unpublished_Or_Closed_Event` (Registration
§3) is now scoped to insert only (`ISNEW()` guard added). Without this, the rule also fired on
the *second* save that `EventBookingController.confirmPayment` performs (Pending → Confirmed),
which meant a Registration Team member or an unlucky timing window (event's registration
window closing between booking and the attendee finishing the 10-second QR verification step)
could leave a payment "confirmed" in the UI while the underlying Apex update silently failed.
All other rules are unchanged from the prior version. See `flows.md` and `datamodel.md` (this
same revision) for the related Flow/field changes.

Grouped by object. Each rule lists the enforced business requirement (traced to prd.md /
organizer.md / attendeeworkflow.md / owd.md) and pseudo-formula logic. Final Apex-vs-Validation-Rule
split for the two capacity checks (marked ⚠️) is resolved in section "Resolved" below.

---

## 1. Event

**VR: End_After_Start**
- Requirement: `End Date/Time > Start Date/Time` (prd.md §7 Step 2)
- Formula: `Start_Date_Time__c >= End_Date_Time__c` → Error

**VR: Budget_Required_On_Submit**
- Requirement: Organizer must supply a Proposed Budget before Submit
- Formula: `ISBLANK(Proposed_Budget__c) && ISPICKVAL(Approval_Status__c, "Pending Approval")` → Error

**VR: No_Publish_Before_Approved**
- Requirement: Approved ≠ Published; Organizer can only Publish an Approved event (prd.md §8, §9)
- Formula: `ISPICKVAL(Publication_Status__c, "Published") && NOT(ISPICKVAL(Approval_Status__c, "Approved"))` → Error

**VR: No_Booking_On_Rejected_Or_Cancelled**
- Requirement: Rejected/Cancelled events are not bookable or publishable (prd.md §8)
- Formula: `(ISPICKVAL(Approval_Status__c,"Rejected") || ISPICKVAL(Approval_Status__c,"Cancelled")) && ISPICKVAL(Publication_Status__c,"Published")` → Error

**VR: Rejection_Reason_Required**
- Requirement: Manager rejection comments must be stored (prd.md §8)
- Formula: `ISPICKVAL(Approval_Status__c,"Rejected") && ISBLANK(Rejection_Reason__c)` → Error

**VR: No_Self_Approval**
- Requirement: Organizer cannot approve their own event; Manager cannot approve their own request (prd.md §3.2/§3.3, owd.md §5)
- Formula: `ISPICKVAL(Approval_Status__c,"Approved") && Approved_By__c = Organizer__c`
- Note: primarily enforced through the Approval Process's approver routing (submitter ≠
  approver), this validation rule is a defense-in-depth backstop if Approved_By is captured
  as a field.

---

## 2. Ticket Type

**VR: No_Price_Change_After_Registration_Open**
- Requirement: Price locked once Registration Opens (prd.md §5.2 rule 6, §10)
- Formula: `ISCHANGED(Price__c) && ISPICKVAL(Event__r.Registration_Status__c, "Open")` → Error

**VR: No_Quota_Change_After_Registration_Open**
- Requirement: Quota locked once Registration Opens (prd.md §5.2 rule 7, §10)
- Formula: `ISCHANGED(Quota__c) && ISPICKVAL(Event__r.Registration_Status__c, "Open")` → Error

**VR: Quota_Not_Below_Booked_Seats**
- Requirement: Quota cannot be reduced below already-booked seats (prd.md §5.2 rule 4, §10)
- Formula: `Quota__c < Booked_Seats__c` → Error

**VR: No_Manual_Availability_Edit**
- Requirement: Booked Seats / Available Seats are system-controlled; Organizer cannot manually
  edit availability (prd.md §5.2 rules 8–9)
- Formula: `ISCHANGED(Booked_Seats__c) && !$Permission.System_Automation_Override` → Error
  (Booked Seats should really be a Roll-Up Summary, which is inherently non-editable by users —
  this rule is a backstop in case it's implemented as a plain Number field instead.)

---

## 3. Registration

**VR: Ticket_Type_Must_Belong_To_Event**
- Requirement: Selected Ticket Type must belong to the selected Event (prd.md §5.3)
- Formula: `Ticket_Type__r.Event__c <> Event__c` → Error

**VR: No_Registration_On_Unpublished_Or_Closed_Event** ⟵ *changed this version*
- Requirement: Attendees may only register for events open for registration (prd.md §6)
- Formula (updated):
  ```
  ISNEW() &&
  NOT(ISPICKVAL(Event__r.Registration_Status__c, "Open"))
  ```
- **Why the `ISNEW()` guard was added:** the original formula ran on every save, including the
  second save `confirmPayment` performs to flip `Registration_Status__c` from Pending to
  Confirmed. If an event's registration window closed in the gap between the attendee
  finishing checkout and finishing the 10-second QR verification screen, that second save
  would be blocked by this rule — leaving the attendee looking at "Payment Confirmed" in the
  LWC while the underlying `update reg;` in Apex actually failed. Scoping to `ISNEW()` means
  this rule only ever gates the *original* booking, which is the only point at which it
  should apply; once a Registration exists, whether the event's window later closes is not a
  reason to block that Registration's own downstream status transitions.
- Note: this remains the last-line UI-facing check on **insert** only; the authoritative
  concurrency-safe capacity check is still the Apex Trigger (prd.md §14), not this rule.

**VR: Booked_Price_Required**
- Requirement: Registration stores a price snapshot at booking time (prd.md §5.3)
- Formula: `ISBLANK(Booked_Price__c)` on insert → Error

---

## 4. Payment

**VR: Transaction_Reference_Required_When_Successful**
- Requirement: A Successful payment should be traceable/reconcilable (prd.md §5.5, owd.md §7 Finance responsibilities)
- Formula: `ISPICKVAL(Payment_Status__c, "Successful") && ISBLANK(Transaction_Reference__c)` → Error
- Note: satisfied automatically by `confirmPayment`, which always populates
  `Transaction_Reference__c` from the QR session reference before insert — but the rule stays
  in place as a backstop against any other insert path (e.g. Finance manually logging an
  offline payment) that forgets to supply it.

**VR: Amount_Matches_Registration_Booked_Price**
- Requirement: Payment amount should reconcile with the Registration's locked-in price
- Formula: `Amount__c <> Registration__r.Booked_Price__c` → Error (or Warning, if partial
  payments/refund adjustments are expected — decide once §7 payment sequencing is finalized)
- Note: `confirmPayment` sets `Amount__c` directly from `Registration.Booked_Price__c`
  server-side, so this rule should never actually fire for QR-flow payments — it exists to
  catch any other insert path (manual Finance entry, future payment gateway integration) that
  might supply a mismatched amount.

---

## 5. Feedback

**VR: One_Feedback_Per_Registration**
- Requirement: One Registration → at most one Feedback submission (prd.md §4.2, §5.10)
- Not expressible as a simple field-level Validation Rule (requires checking for existing
  records). Implement via:
  - A Duplicate Rule on Registration__c, **or**
  - A `Feedback_Submitted__c` checkbox roll-up/flag on Registration, checked by a Validation
    Rule on Feedback: `Registration__r.Feedback_Submitted__c = TRUE` → Error, **or**
  - Apex Trigger validation (most reliable for concurrent submissions)

**VR: Rating_Range**
- Requirement: Ratings are bounded (1–5)
- Formula (per rating field): `Overall_Rating__c < 1 || Overall_Rating__c > 5` → Error

**VR: No_Feedback_Before_Event_Ends**
- Requirement: Feedback flow only fires 10 hours after Event End (prd.md §12)
- Formula: `Registration__r.Event__r.End_Date_Time__c > NOW()` → Error

---

## 6. Venue

**VR: Capacity_Positive**
- Formula: `Venue_Capacity__c <= 0` → Error

---

## 7. Speaker / Event Speaker

**VR: No_Duplicate_Speaker_On_Event**
- Requirement: implicit data-quality rule — same Speaker shouldn't be linked twice to the same Event
- Not expressible as a plain Validation Rule (cross-record uniqueness). Implement via a
  Duplicate Rule/Matching Rule on Event Speaker, keyed on (Event, Speaker), or an Apex Trigger
  check.

---

## 8. Apex-level checks (not Validation Rules, listed here for completeness)

These live in `EventBookingController.confirmPayment` rather than as declarative Validation
Rules, because each requires either a cross-record existence check or a security context
check that Validation Rules cannot perform:

**Ownership check**
- Requirement: a portal/community user must only be able to confirm payment for their own
  Registration (see `datamodel.md §7`, new `Attendee.User__c` field)
- Logic: `reg.Attendee__r.User__c != UserInfo.getUserId()` → `AuraHandledException`
- Not a Validation Rule because it needs `UserInfo.getUserId()`, which Validation Rule
  formulas cannot evaluate against an arbitrary related record's lookup field in this way
  reliably across guest/community contexts.

**Duplicate-payment guard**
- Requirement: a double-click or retried request must not create two `Payment__c` records for
  one Registration
- Logic: query `Payment__c WHERE Registration__c = :registrationId` before insert; short-circuit
  if one already exists
- Not a Validation Rule because it requires a SOQL existence check against sibling records,
  which — per the same reasoning as the capacity checks below — is unsafe to express as a
  single-record formula.

---

## Resolved — items previously flagged ⚠️

### 1. Quota vs Venue Capacity → **Apex, not a Validation Rule**

A Validation Rule on Ticket Type can only see the record being saved plus its direct lookups
— it cannot natively SUM the Quota of *sibling* Ticket Types under the same Event without a
Roll-Up Summary field on Event. Even with that Roll-Up in place, the check would be unsafe:
Roll-Up Summary fields recalculate **after** the triggering DML commits, so the Validation
Rule would evaluate against the *stale* pre-save sum and let an overshoot through on the
save that actually causes it.

**Decision:** this check moves entirely to Apex, on Ticket Type before insert/update. See
`apex-design.md` §1 (`TicketTypeTriggerHandler`) for the full spec. The `Quota_Not_Exceed_Venue_Capacity`
row has been removed from the Event/Ticket Type Validation Rule list above for this reason —
`Quota_Not_Below_Booked_Seats` and the price/quota-lock rules remain as Validation Rules
since those are genuinely single-record, deterministic checks.

### 2. Overbooking / concurrent registration protection → **confirmed Apex-only, no Validation Rule**

Confirmed as originally scoped in prd.md §14. A Validation Rule evaluates against record
state at the start of a transaction with no locking mechanism — two concurrent Registration
inserts for the last seat could both pass the same check and both succeed. Only Apex, using
row-level locking (`FOR UPDATE`), can serialize concurrent booking attempts safely. Full spec
in `apex-design.md` §2 (`RegistrationTriggerHandler`).

This also resolves prd.md's open item #8 (*"exact authoritative mechanism for updating Booked
Seats"*): **Apex owns the write to `Booked_Seats__c`**, not the Record-Triggered Flow. The
Record-Triggered Flow's scope is downstream automation only — confirmation Task, notification
— per the "one source of truth for inventory" design principle (prd.md §26).

### 3. Payment sequencing (prd.md §23 open item #2) → **resolved**

Payment is created **before** the Registration's status flips to Confirmed, both within the
single `confirmPayment` transaction, itself invoked only after the attendee completes the
10-second QR verification step in the `paymentQrVerification` LWC. See `flows.md` for the
full sequence diagram.

---

## Changelog

| Version | Change |
|---|---|
| This version | Added `ISNEW()` guard to `No_Registration_On_Unpublished_Or_Closed_Event`. Added §8 documenting the two Apex-level checks (ownership, duplicate-payment) that back the QR payment flow. Added resolution note for payment sequencing. |
| Prior version | Resolved Quota-vs-Capacity and overbooking checks to Apex-only. |
