# Organizer Workflow — Implementation Plan

Scope: the Organizer's own path only — create event → ticket types → submit → approval →
dashboard visibility. Attendee booking, payment QR verification, the Record-Triggered Flow,
and the Scheduled Flows belong to a separate persona's workflow and are tracked in `flows.md`,
not here.

Each phase lists its current status and, where work remains, a ready-to-use prompt you can
hand back to build that piece. Phases already fully built and reviewed are marked done with no
prompt attached. Cross-references throughout are to the spec docs already in the project
(`datamodel.md`, `relationship.md`, `validationrules.md`, `flows.md`,
`event-creation-flow.md`, `owd.md`, `prd.md`) and to `progress.md`'s work log entries.

---

## Phase 1 — Data Foundation

**Status:** ✅ Done. Full Salesforce metadata XML created in `objects/` for all 9 Custom Objects (`Venue__c`, `Event__c`, `Ticket_Type__c`, `Attendee__c`, `Registration__c`, `Ticket__c`, `Payment__c`, `Speaker__c`, `Feedback__c`) and `Approval_Settings__mdt` (+ `Approval_Settings.Default_Threshold.md-meta.xml` in `customMetadata/`), including all fields and relationships per `datamodel (2).md` and `relationship (1).md`.

---

## Phase 2 — Validation Rules

**Status:** ✅ Done. Generated complete metadata XML files for all 17 Validation Rules across `Venue__c`, `Event__c`, `Ticket_Type__c`, `Registration__c`, `Payment__c`, and `Feedback__c` in `objects/<ObjectName>/validationRules/`.

- `Event__c`: `End_After_Start`, `Budget_Required_On_Submit`, `No_Publish_Before_Approved`, `No_Booking_On_Rejected_Or_Cancelled`, `Rejection_Reason_Required`, `No_Self_Approval`.
- `Ticket_Type__c`: `No_Price_Change_After_Registration_Open`, `No_Quota_Change_After_Registration_Open`, `Quota_Not_Below_Booked_Seats`.
- `Venue__c`: `Capacity_Positive`.
- `Registration__c`: `Ticket_Type_Must_Belong_To_Event`, `No_Registration_On_Unpublished_Or_Closed_Event`, `Booked_Price_Required`.
- `Payment__c`: `Transaction_Reference_Required_When_Successful`, `Amount_Matches_Registration_Booked_Price`.
- `Feedback__c`: `One_Feedback_Per_Registration`, `Rating_Range`, `No_Feedback_Before_Event_Ends`.
*(Note: `Quota_Not_Exceed_Venue_Capacity` and concurrent seat-booking protection are handled in Apex via `TicketTypeTriggerHandler` and `RegistrationTriggerHandler`).*

---

## Phase 3 — Access & Visibility

**Status:** ✅ Done. Set `Event__c` OWD to Private (`objects/Event__c/Event__c.object-meta.xml`). Created 2-tier Role Hierarchy (`Event_Manager.role-meta.xml`, `Event_Organizer.role-meta.xml` in `roles/`), criteria-based sharing rule (`Event__c.sharingRules-meta.xml` in `sharingRules/`), and Permission Sets (`Event_Organizer_Permissions.permissionset-meta.xml`, `Event_Manager_Permissions.permissionset-meta.xml` in `permissionsets/`).

**Prompt:**
> "Generate the OWD setting (Event__c = Private), a Role Hierarchy sketch (Organizer / Event
> Manager), a sharing rule so Event Managers can see all Pending Approval events, and a
> `Permission_Set` metadata XML granting Organizers CRUD on Event__c/Ticket_Type__c and read on
> Venue__c, per `owd.md` §5's 'not self-approval' rule and the roles referenced throughout
> `event-creation-flow.md`."

---

## Phase 4 — UI Scaffolding

**Status:** ✅ Done. Created Custom Tabs (`Event__c`, `Venue__c`, `Organizer_Dashboard` in `tabs/`), Compact Layouts on `Event__c` and `Venue__c` (`objects/<ObjectName>/compactLayouts/`), standard Page Layouts (`layouts/Event__c-Event Layout.layout-meta.xml`, `layouts/Venue__c-Venue Layout.layout-meta.xml`), Lightning Record Pages (`flexipages/Event_Record_Page.flexipage-meta.xml`, `flexipages/Venue_Record_Page.flexipage-meta.xml`), and the Lightning Application definition (`applications/Event_Management.app-meta.xml`).

**Prompt:**
> "Generate the Lightning App (`.app-meta.xml`), Custom Tabs, and Lightning Record Page
> metadata for Event__c and Venue__c, including a compact layout showing Approval Status,
> Publication Status, and Registration Status badges consistent with `organizerDashboard.html`'s
> badge styling."

---

## Phase 5 — Apex Automation

**5a. `TicketTypeTriggerHandler` + `TicketTypeTrigger`**

**Status:** ✅ Done. Created in `Registration handler/` with bulk-safe row-level locking (`FOR UPDATE`), in-memory cumulative quota validation against `Venue__r.Venue_Capacity__c`, and clear error reporting matching `TicketTypeTriggerHandlerTest.cls`.

**Prompt:**
> "Write `TicketTypeTriggerHandler.cls` + `TicketTypeTrigger.trigger` to satisfy the existing
> `TicketTypeTriggerHandlerTest.cls` exactly — lock sibling Ticket Types under the same Event
> with `FOR UPDATE`, sum quotas in-memory including existing siblings, and `addError()` with a
> message containing the substring 'exceed venue capacity' when the aggregate exceeds
> `Venue__c.Venue_Capacity__c`. Mirror the bulk-safe pattern already used in
> `RegistrationTriggerHandler.cls`."

**5b. `RegistrationTriggerHandlerTest.cls`**

**Status:** ✅ Done. Created in `Registration handler/` with 10 comprehensive unit tests covering happy path within quota, quota updates, exact-at-quota boundary auto-flipping to Sold Out, quota overflow, event mismatch, closed event, Sold Out/Closed status checks, and bulk transactions.

**Prompt:**
> "Write `RegistrationTriggerHandlerTest.cls` covering `RegistrationTriggerHandler.beforeInsert`
> — happy path within quota, quota-exceeded failure, wrong-event ticket type failure,
> closed-registration failure, Sold-Out/Closed ticket type failure, and the exact-at-quota
> boundary case (should succeed)."

---

## Phase 6 — Event Creation Screen Flow + Dashboard Controller

**6a. `Event_Creation_Screen_Flow` metadata**

**Status:** ✅ Done. `Event_Creation_Screen_Flow.flow-meta.xml` created in `Event_Creation_Screen_Flow/`. Implements all 19 elements from `event-creation-flow.md`, embeds the `ticketTypeCollector` LWC, sets up bulk ticket type creation, loops over `TicketTypeWrapper` collections, evaluates `Approval_Settings__mdt` thresholds, routes auto-approval vs submit-for-approval, and wires fault connectors on DML nodes.

**Prompt:**
> "Generate the `Event_Creation_Screen_Flow.flow-meta.xml` implementing every element in
> `event-creation-flow.md` exactly in order (elements 1–19), embedding the `ticketTypeCollector`
> component at the `Add_Ticket_Type` step in place of the Go-To loop, per Entry 3 in
> `progress.md`. Include the fault connectors on `Create_Event` and `Create_Ticket_Types` as
> specified."

**6b. `OrganizerDashboardController.cls`**

**Status:** ✅ Done. Created `OrganizerDashboardController.cls` (+ meta XML and `OrganizerDashboardControllerTest.cls`) in `Event_Creation_Screen_Flow/`. Returns `EventSummaryWrapper` with all fields expected by `organizerDashboard.js` (`eventId`, `eventName`, `startDateTime`, `venueName`, `approvalStatus`, `publicationStatus`, `registrationStatus`, `bookedSeats`, `totalCapacity`, `availableSeats`, `confirmedRegistrations`, `revenue`), scoped to `Organizer__c = UserInfo.getUserId()`.

**Prompt:**
> "Write `OrganizerDashboardController.cls` with an `@AuraEnabled(cacheable=true) getMyEvents()`
> method returning the fields `organizerDashboard.js`'s `decorateEvent()` expects (`eventId`,
> `eventName`, `startDateTime`, `venueName`, `approvalStatus`, `publicationStatus`,
> `registrationStatus`, `bookedSeats`, `totalCapacity`, `availableSeats`,
> `confirmedRegistrations`, `revenue`), scoped to `Organizer__c = UserInfo.getUserId()`,
> consistent with the OWD/sharing model from Phase 3."

---

## Phase 7 — Approval Process

**Status:** ✅ Done. `Event__c.Event_Budget_Approval.approvalProcess-meta.xml` and 4 associated `workflowFieldUpdate-meta.xml` files generated in `Approval_Process/`. Configures single-step approval assigned to Event Manager role, entry criteria on draft/unset status, and automated status transitions for submission, approval, rejection, and recall.

**Prompt:**
> "Generate the `ApprovalProcess` metadata XML for Event__c per `event-creation-flow.md`
> element 18 — entry criteria `Approval_Status__c` unset or 'Draft', single-step approval
> routed to the Event Manager role (never the submitter, per `owd.md` §5), final approval
> action sets `Approval_Status__c = 'Approved'`, final rejection action requires
> `Rejection_Reason__c`."

---

## Phase 8 — Reporting (organizer-facing)

**Status:** ✅ Done. Created Custom Report Type (`Events_with_Registrations`) in `Reporting/reportTypes/` and two standard summary reports with charts (`My_Events_by_Approval_Status` and `My_Events_Revenue_Summary`) in `Reporting/reports/Event_Reports/`, matching the dashboard's summary tiles.

**Prompt:**
> "Generate a Report Type and two Reports for Event__c — 'My Events by Approval Status' and
> 'My Events Revenue Summary' — matching the summary tiles already in
> `organizerDashboard.html` (Total Events, Confirmed Registrations, Total Revenue)."

---

## Phase 9 — End-to-End Test Plan

**Status:** ✅ Done. Created `OrganizerJourneyE2ETest.cls` in `E2E_Tests/`. Implements 4 comprehensive test scenarios verifying venue setup, bulk ticket insertion, capacity limits, approval submission/approval/rejection flows, and dashboard metrics.

**Prompt:**
> "Write an Apex test class simulating the full organizer journey end-to-end: create Venue →
> create Event (Draft) → bulk-insert Ticket Types (both within and exceeding capacity) →
> Submit for Approval → simulate Manager approval/rejection → assert final
> `Approval_Status__c`/`Publication_Status__c` states — exercising `TicketTypeTriggerHandler`,
> the Validation Rules from Phase 2, and the Approval Process from Phase 7 together."

---

## Recommended build order
 
1. **Phase 5a** — `TicketTypeTriggerHandler` + trigger (test already waiting)
2. **Phase 6b** — `OrganizerDashboardController.cls` (unblocks the dashboard)
3. **Phase 5b** — `RegistrationTriggerHandlerTest`
4. **Phase 2** — Validation Rules *(🟡 currently in progress by team)*
5. **Phase 3** — Access & Visibility
6. **Phase 4** — UI Scaffolding
7. **Phase 6a** — Event Creation Screen Flow metadata
8. **Phase 7** — Approval Process
9. **Phase 8** — Reports
10. **Phase 9** — End-to-end test
 
Once the Organizer side is solid, move to the Attendee-side items already tracked separately
in `flows.md` and `progress.md`: Attendee booking Screen Flow + `attendeeEventBooking` LWC,
Payment QR Verification, the Record-Triggered Flow, and the two Scheduled Flows.
