# Event Creation Screen Flow — Element-by-Element Spec

Fills the last open gap flagged against `prd.md §24` item 12. This is a **new Flow 0**,
slotting in before Flow 1 (`Event_Registration_Screen_Flow`) in `flows.md`'s numbering —
cross-reference from there once merged.

**Design decision — no separate Ticket Type object page.** `organizer.md`'s UX
(`Add Ticket Type → Add another → Add another → Done`) is a native fit for Flow Builder's
**Go To Connector** (available Spring '22+): a screen can loop back to itself, collecting one
record per pass into a collection variable, until the user chooses "Done." This means Ticket
Type creation is entirely **inside** this flow — there is no `Ticket_Type__c` "New" object
page anywhere in the Organizer's path, and no Apex-backed dynamic-rows component is needed
(unlike the QR payment step, which needed an LWC because Screen Flow can't do a live countdown
or QR render — a repeating input screen it can do natively).

---

## Flow: `Event_Creation_Screen_Flow` (Screen Flow, hosted in LWC)

**Type:** Screen Flow
**Launched from:** `organizerDashboard` LWC via `<lightning-flow flow-api-name="Event_Creation_Screen_Flow">` (see dashboard wiring changes below) — no input variables required; the flow resolves the running user as Organizer internally.
**Runs as:** current user (Organizer)

### Elements, in order

1. **Screen: `Basic_Details`**
   - Text input: Event Name (required)
   - Long Text input: Description
   - Picklist: Category
   - Purpose: `organizer.md` Step 1

2. **Screen: `Date_Time`**
   - Date/Time input: Start Date/Time (required)
   - Date/Time input: End Date/Time (required)
   - Validation on the screen component: End Date/Time > Start Date/Time (client-side UX
     check; the authoritative check remains `VR: End_After_Start` on Event, per
     `validationrules.md §1`, which fires regardless of what the screen catches)

3. **Screen: `Venue_Selection`**
   - Lookup/Picklist component: Venue (bound to `Venue__c` records where `Status__c = "Active"`)
   - Purpose: `organizer.md` Step 3

4. **Get Records: `Get_Selected_Venue_Capacity`**
   - Object: Venue__c
   - Filter: Id = `{!Venue_Selection.selectedVenueId}`
   - Fields: Venue_Capacity__c
   - Store: `varVenueCapacity`
   - Runs immediately after venue selection so capacity is available for the running-total
     display in the ticket type loop (element 6) without a repeated query per pass

5. **Assignment: `Init_Ticket_Type_Collection`**
   - `varTicketTypes = {}` (empty collection of `Ticket_Type__c` record variables)
   - `varRunningQuotaTotal = 0`

6. **Screen: `Add_Ticket_Type`** *(loop entry point)*
   - Text input: Ticket Type Name (required)
   - Currency input: Price (required)
   - Number input: Quota (required)
   - Long Text input: Description
   - Display Text (read-only, updates each pass): "Running total: `{!varRunningQuotaTotal}` /
     Venue capacity: `{!varVenueCapacity}`" — a live-ish preview; the authoritative
     over-capacity check still happens in Apex at Submit (element 13), per
     `validationrules.md` Resolved §1 (Roll-Up-based checks lag a save behind, so this
     preview is advisory only, never a hard gate at this screen)

7. **Assignment: `Add_To_Collection`**
   - Build a new `Ticket_Type__c` record variable from the screen 6 inputs (Name, Price,
     Quota, Description; `Event__c` is left blank here — populated in bulk at element 13,
     since the Event doesn't have an Id yet)
   - Add that record variable to `varTicketTypes` (Add to Collection)
   - `varRunningQuotaTotal = varRunningQuotaTotal + {!Add_Ticket_Type.Quota}`

8. **Screen: `Add_Another_Ticket_Type`**
   - Radio/Toggle: "Add another ticket type?" — Yes / No (required, no default — forces an
     explicit choice, matching `organizer.md`'s explicit "Add another / Done" branch)
   - Optional Display Text: read-only summary list of ticket types added so far (Data Table
     screen component bound to `varTicketTypes`, if the org's Flow Builder version supports
     it; otherwise a formatted Display Text built from a loop-free `TEXT()` join is an
     acceptable fallback)

9. **Decision: `Loop_Or_Done`**
   - Outcome "Add Another": `{!Add_Another_Ticket_Type.choice} = "Yes"` → **Go To Connector**
     back to element 6 (`Add_Ticket_Type`), with the screen's input fields reset to blank on
     re-entry
   - Default outcome "Done": proceeds to element 10
   - **No minimum-one-ticket-type enforcement is skipped here** — see element 9a

9a. **Decision: `At_Least_One_Ticket_Type`** (only reached on "Done")
   - Outcome "None Added": `{!varTicketTypes}` is empty → routes to a short warning Screen
     ("An event needs at least one ticket type.") with a single button back to element 6
   - Default: proceeds to element 10
   - Purpose: `prd.md` doesn't explicitly say an event needs ≥1 ticket type, but Total
     Capacity is `SUM(Ticket Type Quota)` (`datamodel.md §1`) — an event with zero ticket
     types would have zero capacity and be unbookable by construction, so this guard exists
     to catch that before the Organizer submits

10. **Screen: `Proposed_Budget`**
    - Currency input: Proposed Budget (required)
    - Purpose: `organizer.md` Step 5. `VR: Budget_Required_On_Submit` (`validationrules.md
      §1`) backstops this at save time regardless.

11. **Screen: `Review`**
    - Display Text: full summary — Event Name, Description, Category, Start/End, Venue,
      each Ticket Type (Name/Price/Quota) from `varTicketTypes`, Proposed Budget, computed
      Total Capacity (`SUM` of the collection, computed via a Loop + Assignment, or an
      Apex-free running total already tracked in `varRunningQuotaTotal` from element 7)
    - Purpose: `organizer.md` Step 6 — last confirmation before commit

12. **Create Records: `Create_Event`**
    - Object: Event__c
    - Field values: Event Name, Description, Category, Start/End Date/Time, Venue Id,
      Organizer = `{!$User.Id}`, Proposed Budget, Approval_Status__c = **"Draft"** (set
      provisionally; corrected immediately after the threshold check in elements 14–15),
      Publication_Status__c = "Unpublished", Registration_Status__c = "Not Open"
    - Store new Id in `varEventId`
    - **Fault Connector** wired to a `Creation_Failed` screen (generic error message +
      "Try Again" button back to element 1), covering any unexpected Apex/validation failure
      not already surfaced by a more specific step

13. **Loop: `Set_Event_Id_On_Ticket_Types`** over `varTicketTypes`
    - Assignment inside loop: `Event__c = {!varEventId}` on each collection member
    - (A loop is used here only to stamp the now-known Event Id onto each already-built
      record variable — this is in-memory collection manipulation, not SOQL/DML, so it does
      not violate the "no DML inside loops" rule)

14. **Create Records: `Create_Ticket_Types`**
    - Object: Ticket_Type__c
    - Input: the entire `varTicketTypes` collection, inserted in **one bulk Create Records
      call** (not a loop with DML inside it — Flow's Create Records element accepts a
      collection natively and performs a single bulk DML)
    - **This is the element that fires `TicketTypeTrigger` (before insert)**, running
      `TicketTypeTriggerHandler.beforeSave` from `apex-design.md §1` — the authoritative
      Quota-vs-Venue-Capacity check happens here, across the whole batch at once, which is
      exactly the case that check was designed for (`validationrules.md` Resolved §1)
    - **Fault Connector** → `Ticket_Type_Creation_Failed` screen: displays
      `{!$Flow.FaultMessage}` (the Apex `addError()` text, e.g. "Total ticket quota... would
      exceed venue capacity..."), with a button back to element 6 so the Organizer can adjust
      quotas without losing the Event record (the Event stays in Draft; nothing publishes or
      submits for approval on this path)

15. **Get Records: `Get_Approval_Threshold`**
    - Object: a Custom Metadata Type, e.g. `Approval_Settings__mdt`, single record holding
      `Budget_Threshold__c`
    - Store: `varThreshold`
    - Using Custom Metadata (not a hardcoded value or Custom Setting) means the threshold is
      package-deployable and editable by Admin without a code change — resolves `prd.md §23`
      open item #1 ("exact budget threshold...to finalize")

16. **Decision: `Budget_Exceeds_Threshold`**
    - Outcome "Requires Approval": `{!Proposed_Budget.value} > {!varThreshold.Budget_Threshold__c}`
    - Default: "Auto Approved"

17. **Update Records: `Set_Approved`** (Auto Approved path)
    - Target: `{!varEventId}`
    - `Approval_Status__c = "Approved"`

18. **Action: `Submit_For_Approval`** (Requires Approval path)
    - Standard "Submit for Approval" flow action, targeting `{!varEventId}`
    - This routes into the declarative **Approval Process** (`prd.md §16`/Task 6), whose
      entry criteria are `Approval_Status__c` unset or "Draft" and whose approver is the
      Event Manager role — configured declaratively in Setup, not in this flow. The Approval
      Process itself is responsible for setting `Approval_Status__c = "Pending Approval"` on
      submission and `"Approved"`/`"Rejected"` on the Manager's decision (with
      `Rejection_Reason__c` populated on reject, satisfying `VR: Rejection_Reason_Required`).
    - **Not build here** because Approval Processes are Setup configuration (steps, approver
      determined by role hierarchy per `owd.md §5`'s "not self-approval" rule), not flow
      elements or code — listed for completeness of the end-to-end chain only.

19. **Screen: `Event_Submitted`** (both paths converge here)
    - Display Text, branched by which path was taken:
      - Auto Approved: "Your event has been approved. You can now publish it from your
        dashboard."
      - Pending Approval: "Your event has been submitted for approval. You'll be notified
        once the Event Manager reviews it."
    - Button: "Back to Dashboard" — closes the embedded flow; the hosting LWC's
      `onstatuschange` handler (FINISHED) triggers `refreshApex` so the new event appears
      immediately in the Organizer's "My Events" list

### Output variables (read by the LWC after flow completion)

| Variable | Type |
|---|---|
| `outcome` | Text ("AutoApproved" / "PendingApproval" / "Failed") |
| `newEventId` | Text |

---

## Custom Metadata Type required

| Object | Field | Type | Notes |
|---|---|---|---|
| `Approval_Settings__mdt` | `Budget_Threshold__c` | Number/Currency | Single default record; read by element 15. Admin-editable in Setup without redeployment. |

---

## Apex change required

None. This flow uses only native Get/Create/Update Records and the standard Submit for
Approval action — it reuses `TicketTypeTriggerHandler` exactly as already built in
`apex-design.md §1`, with no modification. `RegistrationTriggerHandler` is untouched (it only
ever fires off `Registration__c`, which this flow never creates).

---

## Chain diagram

```
organizerDashboard LWC — "Create Event" button
    │
    ▼
Event_Creation_Screen_Flow
    │  Basic Details → Date/Time → Venue
    │  Add_Ticket_Type ⟲ Add_Another_Ticket_Type (Go To loop, 1..n passes)
    │  At_Least_One_Ticket_Type guard
    │  Proposed Budget → Review
    │  Create Event (Draft)
    │  Create Ticket Types (bulk) ── fires TicketTypeTriggerHandler
    │      │ fault → Ticket_Type_Creation_Failed (loop back to Add_Ticket_Type)
    │  Get Approval_Settings__mdt threshold
    │  Budget > Threshold?
    │      No  → Approval_Status__c = "Approved"
    │      Yes → Submit for Approval → Approval Process (Setup, not this flow)
    │  Event_Submitted screen
    ▼
organizerDashboard LWC — refreshApex → new event visible in My Events
```

---

## Changelog

| Version | Change |
|---|---|
| This version (new doc) | Full element spec for `Event_Creation_Screen_Flow`, folding Ticket Type creation into the same flow via a native Go To loop rather than a separate object page or LWC. |
