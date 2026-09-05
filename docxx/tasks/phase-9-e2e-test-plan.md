# Task Documentation: Phase 9 — End-to-End Test Plan

**Status:** ✅ Completed  
**Relevant Folder:** [`E2E_Tests/`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/E2E_Tests/)  
**Date Completed:** September 4, 2026  

---

## 1. Overview & Objective
Validate the entire Organizer lifecycle from event creation through venue quota checks, approval processes, event publication, and dashboard metric visibility in a single end-to-end test suite:
- **`OrganizerJourneyE2ETest.cls`**: Apex test suite simulating the full organizer flow, exercising `TicketTypeTriggerHandler`, Validation Rules, the `Event_Budget_Approval` process, and `OrganizerDashboardController`.

---

## 2. Files Created

| File | Type | Location | Purpose |
|---|---|---|---|
| [`OrganizerJourneyE2ETest.cls`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/E2E_Tests/OrganizerJourneyE2ETest.cls) | Apex Test Class | `E2E_Tests/` | 4 comprehensive E2E test cases simulating happy path, manager approval, rejection, and quota overflows. |
| [`OrganizerJourneyE2ETest.cls-meta.xml`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/E2E_Tests/OrganizerJourneyE2ETest.cls-meta.xml) | Metadata XML | `E2E_Tests/` | Metadata descriptor (API 61.0, Active). |

---

## 3. Test Scenarios Covered

1. **`testOrganizerJourney_HappyPathWithAutoApprovalAndPublish`**:
   - Creates Venue (500 capacity).
   - Creates Event in `Draft` with low proposed budget within auto-approval limits.
   - Bulk-inserts multiple Ticket Types (100 VIP + 300 General = 400 <= 500 capacity).
   - Verifies auto-approval (`Approval_Status__c = 'Approved'`).
   - Flips `Publication_Status__c = 'Published'` and `Registration_Status__c = 'Open'`.
   - Calls `OrganizerDashboardController.getMyEvents()` to verify that the newly published event and calculated capacity (400) appear accurately on the dashboard.

2. **`testOrganizerJourney_ManagerApprovalProcessWorkflow`**:
   - Creates Venue and Event with a high proposed budget (> threshold).
   - Submits record for approval via `Approval.ProcessSubmitRequest` targeting `Event_Budget_Approval`.
   - Asserts record locks and `Approval_Status__c` transitions to `'Pending Approval'`.
   - Simulates Event Manager decision approving the request via `Approval.ProcessWorkitemRequest`.
   - Asserts final transition to `'Approved'`.

3. **`testOrganizerJourney_ManagerRejectionWorkflow`**:
   - Submits an over-budget event for managerial review.
   - Simulates rejection with mandatory reason logged in `Rejection_Reason__c`.
   - Asserts `Approval_Status__c = 'Rejected'` and verifies reason presence.

4. **`testOrganizerJourney_CapacityOverflowEnforcement`**:
   - Creates Venue with 100 capacity.
   - Inserts first Ticket Type with 70 quota (succeeds).
   - Attempts to insert second Ticket Type with 40 quota (70 + 40 = 110 > 100).
   - Asserts `DmlException` is raised by `TicketTypeTriggerHandler` containing `'exceed venue capacity'`.
