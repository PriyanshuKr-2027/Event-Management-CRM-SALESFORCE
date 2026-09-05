# The 3 Dedicated Flows — Implementation Plan

`prd.md §25` requires three native Flow **types** to be demonstrated: Screen Flow,
Record-Triggered Flow, and Scheduled Flow (×2 instances). `Event_Creation_Screen_Flow`
(Organizer side) already covers the Screen Flow type and is tracked separately in
`implementation-plan.md`. This document covers the three that are still unbuilt, all on the
Attendee side — pulled out of `attendee-implementation-plan.md` Phases 6/9/10 into full
element-by-element specs so each can be built in one pass, with prerequisites called out
up front instead of discovered mid-build.

| # | Flow | Type | Status |
|---|---|---|---|
| 1 | `Event_Registration_Screen_Flow` | Screen Flow | ⬜ Not built |
| 2 | `Post_Registration_Automation` | Record-Triggered Flow | ⬜ Not built |
| 3 | `Event_Reminder_Scheduled_Flow` + `Post_Event_Feedback_Scheduled_Flow` | Scheduled Flow (×2 instances) | ⬜ Not built |

**Build order:** 1 → 2 → 3, since Flow 2's trigger condition can only be exercised once Flow 1
(plus the `confirmPayment` Apex step, tracked in `attendee-implementation-plan.md` Phase 8) is
actually producing `Confirmed` Registrations to fire off of. Flow 3 has no dependency on the
other two beyond the base objects existing.

---

## Prerequisites — check these before building any of the three

- [ ] **Data Foundation confirmed** — `Registration__c`, `Payment__c`, `Attendee__c` (with
      `User__c`), `Ticket__c` exist in-org. (`attendee-implementation-plan.md` Phase 1 — still
      unconfirmed as of this doc.)
- [ ] **`Event__c` has "Allow Activities" enabled** — Flow 2 creates a Task with
      `WhatId = {!$Record.Event__c}`; without this object setting, Task creation fails
      validation. One-click Setup toggle, not a metadata file.
- [ ] **`EventBookingController.confirmPayment` exists** (`attendee-implementation-plan.md`
      Phase 8) — this is the only thing that ever flips `Registration_Status__c` to
      `Confirmed`, which is Flow 2's entire entry condition. Building Flow 2 before this exists
      means it can be deployed but never tested live.
- [ ] **An Email Template/Email Alert exists** for both the registration confirmation email
      (Flow 2) and the reminder/feedback emails (Flow 3a/3b) — not covered by this doc, needs
      its own quick pass in Setup/Email Templates.

---

## Flow 1 — `Event_Registration_Screen_Flow` (Screen Flow)

**Runs as:** current user (Attendee) · **Launched from:** `attendeeEventBooking` LWC via
`<lightning-flow flow-api-name="Event_Registration_Screen_Flow" flow-input-variables={flowInputs}>`

**Input variables:** `recordId` (Event Id), `selectedTicketTypeId`, `currentAttendeeId`

**Elements, in order:**

1. **Screen `Confirm_Selection`** — read-only display of Event Name, Ticket Type Name, Price
2. **Get Records `Get_Ticket_Type_Details`** — `Ticket_Type__c` by Id, fields
   `Price__c`, `Available_Seats__c`, `Status__c`, `Name` → `varTicketType`
3. **Decision `Is_Still_Available`** — Sold Out if `Available_Seats__c <= 0` or
   `Status__c = "Sold Out"`; default Available
4. **Screen `Sold_Out_Message`** (Sold Out path only) — ends the flow here
5. **Screen `Attendee_Details`** (Available path) — Name, Email, Phone, pre-filled where
   possible
6. **Get Records `Get_Existing_Attendee`** — match `User__c = {!$User.Id}` first; if null **and**
   not a guest context, fall back to `Email = {!Attendee_Details.Email}` → `varExistingAttendee`
7. **Decision `Attendee_Exists`** — New vs Existing
8. **Create Records `Create_Attendee`** (New path) — Name/Email/Phone from screen 5,
   `Attendee_Status__c = "Active"`, `User__c = {!$User.Id}` (blank if guest) → `varAttendeeId`
9. **Assignment `Set_Attendee_Id_Existing`** (Existing path) — `varAttendeeId = varExistingAttendee.Id`
10. **Screen `Review`** — full summary before commit
11. **Create Records `Create_Registration`** — `Event__c`, `Ticket_Type__c`, `Attendee__c`,
    `Registration_Status__c = "Pending"`, `Booked_Price__c = {!varTicketType.Price__c}`,
    `Confirmation_Status__c = "Not Sent"`. **Fault connector** → element 12.
12. **Screen `Registration_Failed`** (fault path) — parsed `{!$Flow.FaultMessage}`, flow ends
13. **Screen `Registration_Successful`** (happy path) — last screen; LWC reads output variables
    and transitions to the Payment step, not straight to a success card

**Output variables:** `outcome` (Text: "Success"/"SoldOut"/"Failed"), `newRegistrationId` (Text)

**Build prompt:**
> "Generate `Event_Registration_Screen_Flow.flow-meta.xml` implementing elements 1–13 above
> exactly, in order, with the fault connector off `Create_Registration` wired to
> `Registration_Failed`."

---

## Flow 2 — `Post_Registration_Automation` (Record-Triggered Flow)

**Object:** `Registration__c` · **Trigger:** Create or Update, After Save
**Entry condition:** `ISCHANGED(Registration_Status__c) && ISPICKVAL(Registration_Status__c, "Confirmed")`

> This is the corrected trigger (Option B from the earlier Flow 2 review) — scoped to
> `Create`-only with a `Confirmed`-at-insert condition would never fire, since Flow 1 always
> inserts Registrations as `Pending`. `EventBookingController.confirmPayment` is the only thing
> that performs the Pending→Confirmed transition, which is what this flow actually fires on.
> `ISCHANGED(...)` ensures it fires exactly once per Registration.

**Scope boundary:** this flow must never write to `Booked_Seats__c` — that field is owned
exclusively by `RegistrationTriggerHandler` (Apex).

**Elements, in order:**

1. **Trigger** — as above
2. **Create Records `Create_Ticket`** — `Registration__c = {!$Record.Id}`,
   `Ticket_Status__c = "Active"`, `Issue_Date_Time__c = {!$Flow.CurrentDateTime}` → `varTicketId`
3. **Create Records `Create_Confirmation_Task`** — Subject =
   `"Send registration confirmation — " + {!$Record.Name}` (Registration Number, e.g.
   REG-00001 — **not** the raw record Id), `WhatId = {!$Record.Event__c}`,
   `Status = "Not Started"`, `ActivityDate = TODAY`
4. **Action `Send_Confirmation_Email`** — recipient `{!$Record.Attendee__r.Email}`, template
   merges Event Name, Ticket Type, Registration Number, Ticket Number. **Runs before** element 5.
5. **Update Records `Set_Confirmation_Status`** — `Confirmation_Status__c = "Sent"`, runs
   *after* the email action succeeds

**Fault handling:**
- Fault off `Create_Ticket` → Update Records: `Confirmation_Status__c = "Failed"`
- Fault off `Send_Confirmation_Email` → Update Records: `Confirmation_Status__c = "Failed"`
  (both fault paths leave Registration/Ticket intact — only the status field reflects failure)

**Build prompt:**
> "Generate `Post_Registration_Automation.flow-meta.xml` implementing elements 1–5 above
> exactly, in this element order (email before status-set), with fault paths off both
> `Create_Ticket` and `Send_Confirmation_Email` setting `Confirmation_Status__c = 'Failed'`.
> Confirm `Event__c` has Allow Activities enabled before deploying — see Prerequisites."

---

## Flow 3 — Scheduled Flows (×2 instances)

Same structural pattern, different timing/target, both hourly.

### 3a — `Event_Reminder_Scheduled_Flow`

**Frequency:** Hourly, all days. Filters each run for a 1-hour-wide window centered on
"24 hours from now" — standard tolerance pattern for this kind of scheduled check in Salesforce.

**Elements:**
1. **Trigger** — Scheduled, hourly
2. **Assignment `Set_Window_Bounds`** — `varWindowStart = NOW() + 23:00:00`,
   `varWindowEnd = NOW() + 24:00:00`
3. **Get Records `Get_Events_Starting_In_Window`** — `Event__c` where
   `Start_Date_Time__c >= varWindowStart AND < varWindowEnd AND Publication_Status__c = "Published"`
   → `varUpcomingEvents`
4. **Loop `Loop_Events`** over `varUpcomingEvents`
5. **Get Records `Get_Confirmed_Registrations`** (in loop) — `Registration__c` where
   `Event__c = {!Loop_Events.Id} AND Registration_Status__c = "Confirmed"` → `varRegistrationsForEvent`
6. **Loop `Loop_Registrations`** over `varRegistrationsForEvent`
7. **Action `Send_Reminder_Email`** (inner loop) — recipient
   `{!Loop_Registrations.Attendee__r.Email}`, merges Event Name, Start Date/Time, Venue
8. End inner loop → end outer loop

### 3b — `Post_Event_Feedback_Scheduled_Flow`

**Frequency:** Hourly. Filters for events whose `End_Date_Time__c` fell 9–10 hours ago.

**Elements:**
1. **Trigger** — Scheduled, hourly
2. **Assignment `Set_Window_Bounds`** — `varWindowStart = NOW() - 10:00:00`,
   `varWindowEnd = NOW() - 09:00:00`
3. **Get Records `Get_Recently_Ended_Events`** — `Event__c` where
   `End_Date_Time__c >= varWindowStart AND < varWindowEnd` → `varEndedEvents`
4. **Loop `Loop_Events`** over `varEndedEvents`
5. **Get Records `Get_Attended_Registrations`** (in loop) — `Registration__c` where
   `Event__c = {!Loop_Events.Id} AND Registration_Status__c = "Confirmed"` → `varRegistrationsForEvent`
6. **Loop `Loop_Registrations`** over `varRegistrationsForEvent`
7. **Get Records `Check_Existing_Feedback`** (inner loop) — `Feedback__c` where
   `Registration__c = {!Loop_Registrations.Id}` → `varExistingFeedback` (nullable)
8. **Decision `Feedback_Not_Yet_Requested`** — Send if `varExistingFeedback` is null, else Skip
9. **Action `Send_Feedback_Request_Email`** (Send path) — recipient
   `{!Loop_Registrations.Attendee__r.Email}`, includes a link to the feedback submission form
10. End inner loop → end outer loop

**Build prompt (covers both in one pass):**
> "Generate `Event_Reminder_Scheduled_Flow.flow-meta.xml` and
> `Post_Event_Feedback_Scheduled_Flow.flow-meta.xml` implementing the elements above exactly
> — both hourly-scheduled, both using the windowed Get Records + nested-loop pattern, the
> Feedback flow including the `Check_Existing_Feedback` dedupe check before sending."

---

## After all three are built

Run the end-to-end test from `attendee-implementation-plan.md` Phase 12 — it's written to
exercise Flow 1 → `confirmPayment` → Flow 2 in one pass via `Test.startTest()/stopTest()` to
force the async automation to actually execute. Flow 3a/3b are time-window-based and are best
verified by temporarily creating an Event/Registration with dates inside the current hour's
window rather than waiting for real time to pass.
