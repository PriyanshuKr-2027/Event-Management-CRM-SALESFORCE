# Flows — Element-by-Element Specs

**Revision note (this version):**
1. **Flow 2's trigger is corrected.** It previously fired on `Create` only with entry condition
   `Registration_Status__c = "Confirmed"` — but Flow 1 always creates Registrations as
   **Pending**, so that condition could never be true at insert. It now fires on **Create or
   Update** with `ISCHANGED(Registration_Status__c) && ISPICKVAL(Registration_Status__c, "Confirmed")`.
   The thing that actually performs that Pending→Confirmed transition is now specified below
   (the QR payment-verification step) — closing the gap flagged in the prior review.
2. **Flow 1's Attendee-matching elements are updated** to use the new `Attendee.User__c`
   field (see `datamodel.md`, this same revision) ahead of Email, and to populate it on
   create.
3. **A new payment step is inserted between Flow 1 and Flow 2**, implemented as an LWC
   (`paymentQrVerification`) plus one Apex method (`EventBookingController.confirmPayment`) —
   not as native Screen Flow screens, since a live 10-second countdown and generated QR code
   aren't things Screen Flow can render natively. It's documented here because it's the
   missing link in the end-to-end chain: it's what turns Pending into Confirmed, which is what
   fires Flow 2.

Three flow types required by prd.md §25: Screen Flow, Record-Triggered Flow, Scheduled Flow
(×2 instances — Reminder and Feedback). This doc specifies every element in build order.

The Attendee LWC (`attendeeEventBooking`, see `lwc-code.md` / `organizer-dashboard-code-reference.md`
sibling docs) is the entry point for Flow 1 — it displays Event/Ticket Type/seat data (which
Flow screens can't render nicely on their own), then embeds the Screen Flow via
`<lightning-flow>` once the attendee picks a Ticket Type, passing the Event Id and Ticket Type
Id in as input variables so the flow doesn't have to re-ask for them. On flow completion, the
same LWC hosts the new payment step (§1a below) before finally showing the Success view.

---

## Flow 1: `Event_Registration_Screen_Flow` (Screen Flow, hosted in LWC)

**Type:** Screen Flow
**Launched from:** `attendeeEventBooking` LWC via `<lightning-flow flow-api-name="Event_Registration_Screen_Flow" flow-input-variables={flowInputs}>`
**Runs as:** current user (Attendee)

### Input variables (set by the LWC before launch)

| Variable | Type | Direction |
|---|---|---|
| `recordId` (Event Id) | Text | Input |
| `selectedTicketTypeId` | Text | Input |
| `currentAttendeeId` | Text | Input (resolved by LWC/Apex from running user, where available) |

### Elements, in order

1. **Screen: `Confirm_Selection`**
   - Display Text: Event Name, Ticket Type Name, Price (all read-only, sourced from input variables merged via a preceding Get Records — see element 2)
   - Purpose: attendee confirms what they're booking before entering personal details

2. **Get Records: `Get_Ticket_Type_Details`**
   - Object: Ticket_Type__c
   - Filter: Id = `{!selectedTicketTypeId}`
   - Fields: Price__c, Available_Seats__c, Status__c, Name
   - Store: single record variable `varTicketType`
   - Runs before the Confirm screen so its fields can be merged in

3. **Decision: `Is_Still_Available`**
   - Outcome "Sold Out": `{!varTicketType.Available_Seats__c} <= 0` OR `{!varTicketType.Status__c} = "Sold Out"`
   - Default outcome: "Available"
   - Purpose: catches the case where seats sold out between the attendee opening the page and reaching this screen — UI-level pre-check only; Apex Trigger remains the authoritative check

4. **Screen: `Sold_Out_Message`** (only on "Sold Out" path)
   - Display Text: "Sorry, this ticket type just sold out. Please choose another ticket type."
   - Screen ends the flow here (no further elements on this branch) — the attendee is routed back to the LWC's ticket type list, which re-queries live availability

5. **Screen: `Attendee_Details`** (only on "Available" path)
   - Text input: Name (pre-filled from running user/Attendee record if one exists)
   - Email input: Email (pre-filled, editable)
   - Phone input: Phone (optional)
   - Purpose: confirms/collects Attendee contact info

6. **Get Records: `Get_Existing_Attendee`** ⟵ *updated this version*
   - Object: Attendee__c
   - Filter: `User__c = {!$User.Id}` — **matched first**, ahead of Email
   - Store: `varExistingAttendee` (nullable)
   - **Fallback sub-step** (only if the above returns null AND the running user is not a
     Guest/unauthenticated context): re-query with `Email = {!Attendee_Details.Email}`. This
     covers legacy Attendee records created before `User__c` existed, or records created by
     Registration Team on someone's behalf that were never linked to a User.
   - **Why this changed:** matching on Email alone is not a reliable identity binding —
     `EventBookingController.confirmPayment` needs `Attendee.User__c` to verify the calling
     user actually owns the Registration before allowing a payment/status update (see
     `validationrules.md` §8). If the Attendee record itself is never linked to a User, that
     check has nothing to compare against.

7. **Decision: `Attendee_Exists`**
   - Outcome "New Attendee": `{!varExistingAttendee}` is null
   - Default: "Existing Attendee"

8. **Create Records: `Create_Attendee`** (only on "New Attendee" path) ⟵ *updated this version*
   - Object: Attendee__c
   - Field values: Name, Email, Phone from `Attendee_Details` screen; Attendee Status =
     "Active"; **`User__c = {!$User.Id}`** (new — omitted/blank if the running context is a
     Guest user with no underlying User record to bind to)
   - Store new Id in `varAttendeeId`

9. **Assignment: `Set_Attendee_Id_Existing`** (only on "Existing Attendee" path)
   - `varAttendeeId = varExistingAttendee.Id`

10. **Screen: `Review`**
    - Display Text: full summary — Event, Ticket Type, Price, Attendee Name/Email
    - Purpose: last confirmation before commit, per prd.md §6 (`Review → Submit Registration`)

11. **Create Records: `Create_Registration`**
    - Object: Registration__c
    - Field values:
      - Event__c = `{!recordId}`
      - Ticket_Type__c = `{!selectedTicketTypeId}`
      - Attendee__c = `{!varAttendeeId}`
      - Registration_Status__c = **"Pending"** (unchanged — the flow still creates Pending
        Registrations; see §1a below for what confirms them)
      - Booked_Price__c = `{!varTicketType.Price__c}`
      - Confirmation_Status__c = "Not Sent"
    - **This is the element that fires `RegistrationTrigger` (before insert).** If Apex
      calls `addError()` (sold out / mismatched ticket type / registration not open), the
      Create Records element fails and the flow surfaces that error natively — no separate
      fault path needed for the capacity check itself, but a **Fault Connector** is still
      wired for user-friendly messaging (element 12).

12. **Screen: `Registration_Failed`** (fault path off element 11)
    - Display Text: `{!$Flow.FaultMessage}` reformatted — "This ticket type just sold out. Please go back and choose another." (the Apex error message is parsed/mapped, not shown raw)
    - Flow ends here on this path

13. **Screen: `Registration_Successful`** (happy path)
    - Display Text: Registration Number, Event Name, Ticket Type
    - This is the flow's last screen. The LWC reads the flow's output variables
      (`outcome`, `newRegistrationId`) via `onstatuschange` and — as of this revision — does
      **not** go straight to a success card. Instead it transitions to the payment step
      (§1a), since the Registration is still only Pending at this point.

### Output variables (read by the LWC after flow completion)

| Variable | Type |
|---|---|
| `outcome` | Text ("Success" / "SoldOut" / "Failed") |
| `newRegistrationId` | Text |

---

## Flow 1a: Payment Verification (LWC + Apex — new, not a native Flow)

**Why this isn't a Screen Flow:** three of its requirements — a live per-second countdown, a
generated/scannable QR code, and a Next button whose enabled state depends on a checkbox in
real time — aren't things Screen Flow renders natively without a custom Lightning Component
anyway, so the whole step is built as one child LWC.

**Component:** `paymentQrVerification`, embedded in `attendeeEventBooking` as a new `PAYMENT`
view state, shown immediately after Flow 1 finishes with `outcome = "Success"`.

### Sequence (client-side, inside the LWC)

1. **Entry sub-state** — heading "Complete Your Payment," a QR code generated from a random
   per-session reference (`sessionRef`) embedded in a UPI-style deep link, instruction text,
   a checkbox ("I have completed the payment"), and a Next button. Next is `disabled` until
   the checkbox is checked — there is no code path that enables it otherwise.
2. **Verifying sub-state** — heading "Verifying Payment," a 10-second countdown
   (`setInterval`, decrementing once per second, 10 → 0). No click handler exists on this
   sub-state that can skip or shorten it; the only transition out is the interval reaching
   zero.
3. **Confirmed sub-state** — success icon, "Payment Confirmed!", "Your payment has been
   successfully verified.", "Your registration is confirmed.", and a Done button that
   dispatches a `paymentconfirmed` event carrying `{ registrationId, transactionReference }`.

### Server-side: `EventBookingController.confirmPayment(registrationId, transactionReference)`

Called by the parent LWC's `paymentconfirmed` handler. In order:

1. **Ownership check** — re-query the Registration's `Attendee__r.User__c` and compare to
   `UserInfo.getUserId()`; throws `AuraHandledException` on mismatch. Depends on the new
   `Attendee.User__c` field (see `datamodel.md`) and the matching logic in Flow 1 element 6/8
   above actually having populated it.
2. **Duplicate-payment guard** — if a `Payment__c` already exists for this Registration,
   return without doing anything further (idempotent against double-click/retry).
3. **Insert `Payment__c`** — `Amount__c` set from `Registration.Booked_Price__c` (never from
   client input), `Payment_Status__c = "Successful"`, `Payment_Method__c = "UPI"`,
   `Transaction_Reference__c` from the LWC's session reference, `Payment_Date_Time__c = Datetime.now()`.
4. **Update the Registration** — `Registration_Status__c = "Confirmed"`. **This is the write
   that fires Flow 2** (see its updated entry condition below).

Full rationale and code for both the ownership check and the duplicate guard are in
`validationrules.md` §8.

---

## Flow 2: `Post_Registration_Automation` (Record-Triggered Flow)

**Type:** Record-Triggered Flow
**Object:** Registration__c
**Trigger:** **Create or Update, After Save** ⟵ *changed this version*
**Entry condition:** `ISCHANGED(Registration_Status__c) && ISPICKVAL(Registration_Status__c, "Confirmed")`

> **Why this changed:** the previous version was scoped to `Create` only with entry condition
> `Registration_Status__c = "Confirmed"`. Since Flow 1 always inserts Registrations as
> **Pending** (element 11 above), that condition could never be true at the moment of
> creation — the flow could never fire, and the entire downstream chain (Ticket creation,
> confirmation email, eventually reminders/feedback) was dead. The fix has two parts: (a) the
> trigger type now also covers Update, and (b) something now actually performs the
> Pending→Confirmed transition — `EventBookingController.confirmPayment`, called only after
> the attendee completes the QR payment-verification step in §1a above. `ISCHANGED(...)`
> ensures this flow fires exactly once per Registration, on the specific save that flips it to
> Confirmed, not on every subsequent edit.

> **Scope boundary, repeated from apex-design.md:** this flow must never write to
> `Booked_Seats__c`. That field is owned exclusively by `RegistrationTriggerHandler`. This
> flow's job is purely downstream automation.

### Elements, in order

1. **Trigger** — Registration__c, After Save, Create or Update, entry condition
   `ISCHANGED(Registration_Status__c) && ISPICKVAL(Registration_Status__c, "Confirmed")`

2. **Create Records: `Create_Ticket`**
   - Object: Ticket__c
   - Field values:
     - Registration__c = `{!$Record.Id}`
     - Ticket_Status__c = "Active"
     - Issue_Date_Time__c = `{!$Flow.CurrentDateTime}`
   - Store new Id in `varTicketId`

3. **Create Records: `Create_Confirmation_Task`**
   - Object: Task
   - Field values:
     - Subject = "Send registration confirmation — " CONCAT `{!$Record.Name}` (Registration
       Number, e.g. REG-00001 — corrected from `{!$Record.Id}` in the earlier draft, which
       would have produced an unreadable raw record Id in the subject line)
     - WhatId = `{!$Record.Event__c}`
     - Status = "Not Started"
     - ActivityDate = TODAY
   - Purpose: satisfies prd.md/problem statement Task 4 ("create a confirmation task/notification")

4. **Action: `Send_Confirmation_Email`** (Email Alert or Send Email action)
   - Recipient: `{!$Record.Attendee__r.Email}`
   - Template merges Event Name, Ticket Type, Registration Number, Ticket Number
   - Runs **before** the Confirmation Status update (element 5) — reordered from the earlier
     draft, which set `Confirmation_Status__c = "Sent"` before the email action ran, so an
     email failure could leave the Registration incorrectly marked "Sent."

5. **Update Records: `Set_Confirmation_Status`**
   - Target: `{!$Record.Id}`
   - `Confirmation_Status__c = "Sent"`
   - Allowed here since this is an after-save flow and the update is a separate transaction
     step, not a recursive same-record write within the triggering DML.

### Fault handling

- Fault path off `Create_Ticket` → **Update Records**: set `Confirmation_Status__c = "Failed"`.
- Fault path off `Send_Confirmation_Email` → **Update Records**: also set
  `Confirmation_Status__c = "Failed"` (previously missing — an email-send failure had no fault
  path at all in the earlier draft, since the status-set only followed `Create_Ticket`'s fault
  path).
- Both fault paths leave the Registration and Ticket records themselves intact (they already
  committed); only `Confirmation_Status__c` reflects the failure, so Registration Team can see
  and act on it without the underlying booking being at risk.

---

## Flow 3: Scheduled Flows — Reminder + Feedback

Two separate Scheduled Flows, same structural pattern, different timing and target. Unchanged
from the prior version.

### 3a. `Event_Reminder_Scheduled_Flow`

**Type:** Scheduled Flow, runs **hourly** (checking a rolling 24-hour window, since Scheduled
Flows can't be triggered at an arbitrary per-record offset — see note below)
**Frequency:** Hourly, all days
**Entry condition (evaluated inside the flow, not at schedule level):** finds Events whose
`Start_Date_Time__c` falls within the next 23–24 hour window from "now"

> **Why hourly, not "exactly 24 hours before":** Salesforce Scheduled-Triggered Flows fire on
> a schedule you define (e.g. hourly), then the flow's Get Records step filters for records
> matching the target window at that run. Running hourly and filtering for a 1-hour-wide
> window centered on "24 hours from now" achieves the prd.md requirement ("exactly 24 hours
> before") to within a 1-hour tolerance, which is standard practice for this pattern in
> Salesforce. A tighter/more frequent schedule can be substituted if the assignment requires
> stricter precision.

### Elements, in order

1. **Trigger** — Scheduled, runs hourly

2. **Assignment: `Set_Window_Bounds`**
   - `varWindowStart = NOW() + 23:00:00` (23 hours from now)
   - `varWindowEnd = NOW() + 24:00:00` (24 hours from now)

3. **Get Records: `Get_Events_Starting_In_Window`**
   - Object: Event__c
   - Filter: `Start_Date_Time__c >= {!varWindowStart} AND Start_Date_Time__c < {!varWindowEnd} AND Publication_Status__c = "Published"`
   - Store: collection `varUpcomingEvents`

4. **Loop: `Loop_Events`** over `varUpcomingEvents`

5. **Get Records (in loop): `Get_Confirmed_Registrations`**
   - Object: Registration__c
   - Filter: `Event__c = {!Loop_Events.Id} AND Registration_Status__c = "Confirmed"`
   - Store: collection `varRegistrationsForEvent`

6. **Loop: `Loop_Registrations`** over `varRegistrationsForEvent`

7. **Action (in inner loop): `Send_Reminder_Email`**
   - Recipient: `{!Loop_Registrations.Attendee__r.Email}`
   - Template merges Event Name, Start Date/Time, Venue

8. End inner loop → end outer loop

### 3b. `Post_Event_Feedback_Scheduled_Flow`

**Type:** Scheduled Flow, runs **hourly**
**Entry condition:** finds Events whose `End_Date_Time__c` fell within the past 9–10 hours

### Elements, in order

1. **Trigger** — Scheduled, runs hourly

2. **Assignment: `Set_Window_Bounds`**
   - `varWindowStart = NOW() - 10:00:00`
   - `varWindowEnd = NOW() - 09:00:00`

3. **Get Records: `Get_Recently_Ended_Events`**
   - Object: Event__c
   - Filter: `End_Date_Time__c >= {!varWindowStart} AND End_Date_Time__c < {!varWindowEnd}`
   - Store: collection `varEndedEvents`

4. **Loop: `Loop_Events`** over `varEndedEvents`

5. **Get Records (in loop): `Get_Attended_Registrations`**
   - Object: Registration__c
   - Filter: `Event__c = {!Loop_Events.Id} AND Registration_Status__c = "Confirmed"`
   - Store: collection `varRegistrationsForEvent`

6. **Loop: `Loop_Registrations`** over `varRegistrationsForEvent`

7. **Get Records (in inner loop): `Check_Existing_Feedback`**
   - Object: Feedback__c
   - Filter: `Registration__c = {!Loop_Registrations.Id}`
   - Store: `varExistingFeedback` (nullable)
   - Purpose: enforce "one Feedback per Registration" (prd.md §4.2) even though feedback
     itself is submitted later by the attendee — this just prevents sending a duplicate
     request if the flow somehow runs twice in the same window

8. **Decision: `Feedback_Not_Yet_Requested`**
   - Outcome "Send": `{!varExistingFeedback}` is null
   - Default: "Skip"

9. **Action (on "Send" path): `Send_Feedback_Request_Email`**
   - Recipient: `{!Loop_Registrations.Attendee__r.Email}`
   - Template includes a link to the feedback submission form (a separate lightweight LWC or
     Experience Cloud page, out of scope for this doc — links to a public feedback Screen
     Flow keyed by Registration Id)

10. End inner loop → end outer loop

---

## Full end-to-end chain (post-revision)

```
attendeeEventBooking LWC
    │
    ▼
Event_Registration_Screen_Flow (Flow 1)
    │  Attendee matched/created via User__c (fallback: Email)
    │  Registration created — Registration_Status__c = "Pending"
    │  outcome = "Success"
    ▼
paymentQrVerification LWC (§1a)
    │  QR + checkbox → Next → 10s countdown → Confirmed
    │  dispatches paymentconfirmed { registrationId, transactionReference }
    ▼
EventBookingController.confirmPayment (Apex)
    │  ownership check (Attendee.User__c == running user)
    │  duplicate-payment guard
    │  insert Payment__c (Successful, amount from Booked_Price__c)
    │  update Registration__c → Registration_Status__c = "Confirmed"
    ▼  (Registration_Status__c changed to "Confirmed")
Post_Registration_Automation (Flow 2)
    │  Create Ticket__c
    │  Create confirmation Task
    │  Send confirmation email
    │  Set Confirmation_Status__c = "Sent" (or "Failed" on either fault path)
    ▼
attendeeEventBooking LWC — SUCCESS view
    │
    ▼ (24h before Event Start)
Event_Reminder_Scheduled_Flow (Flow 3a)
    │
    ▼ (10h after Event End)
Post_Event_Feedback_Scheduled_Flow (Flow 3b)
```

## Cross-flow summary table

| Flow / Step | Type | Trigger | Owns |
|---|---|---|---|
| Event_Registration_Screen_Flow | Screen Flow | Launched from LWC | Registration creation UI (Pending), Attendee match/upsert via User__c |
| Payment Verification (§1a) | LWC + Apex | Launched from LWC after Flow 1 success | QR/checkbox/countdown UI, Payment record, Registration Pending→Confirmed transition |
| Post_Registration_Automation | Record-Triggered (After Save, Create/Update) | Registration_Status__c changes to Confirmed | Ticket creation, confirmation Task/email |
| Event_Reminder_Scheduled_Flow | Scheduled (hourly) | Time window vs Event Start | 24h-before reminder emails |
| Post_Event_Feedback_Scheduled_Flow | Scheduled (hourly) | Time window vs Event End | 10h-after feedback request emails |

None of these write to `Booked_Seats__c` — that remains Apex-only (`RegistrationTriggerHandler`),
per `apex-design.md` and `validationrules.md` Resolved §2.

---

## Changelog

| Version | Change |
|---|---|
| This version | Fixed Flow 2 trigger (Create-only → Create/Update with `ISCHANGED`) so it can actually fire. Added §1a (QR payment LWC + `confirmPayment` Apex) as the mechanism that performs the Pending→Confirmed transition. Updated Flow 1 Attendee-matching to use `User__c` ahead of Email. Reordered Flow 2's email-send and status-set steps; added a fault path off the email action. Corrected Task Subject to use `{!$Record.Name}` instead of the raw record Id. |
| Prior version | Initial element-by-element spec for all three flow types; established "Apex owns Booked_Seats__c" boundary. |
