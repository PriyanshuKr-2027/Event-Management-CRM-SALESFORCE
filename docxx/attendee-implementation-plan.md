# Attendee Workflow — Implementation Plan

Scope: the Attendee's own path — browse a Published event → pick a Ticket Type → register →
pay (QR verification) → confirmation (Ticket + email) → reminder/feedback later. This is the
companion to `implementation-plan.md` (Organizer workflow); an Attendee can only book against
an event that's already Approved + Published + Registration Open, so the Organizer-side
Approval Process (that plan's Phase 7) is a soft prerequisite for testing this end-to-end.

Each phase lists current status and, where work remains, a ready-to-use prompt. Nothing here
duplicates a prompt for something already built and reviewed.

---

## Phase 1 — Data Foundation

**Status:** ✅ Done. Custom objects `Registration__c`, `Payment__c`, `Attendee__c` (including `User__c` Lookup(User)), and `Ticket__c` are fully built in `objects/` with Master-Detail relationships (`Registration__c -> Event__c`, `Ticket__c -> Registration__c`).

---

## Phase 2 — Validation Rules (Registration / Payment)

**Status:** ✅ Done. All 5 validation rules are fully implemented in `objects/Registration__c/validationRules/` and `objects/Payment__c/validationRules/`:
- `Ticket_Type_Must_Belong_To_Event`
- `No_Registration_On_Unpublished_Or_Closed_Event` (with `ISNEW()` guard)
- `Booked_Price_Required`
- `Transaction_Reference_Required_When_Successful`
- `Amount_Matches_Registration_Booked_Price`

---

## Phase 3 — Access & Visibility (portal/community)

**Status:** ✅ Done. Created `permissionsets/Event_Attendee_Permissions.permissionset-meta.xml` granting Attendees Read access on Event/Venue/Ticket Type, and Create/Read on Registration/Payment with field-level permissions.

---

## Phase 4 — Attendee-facing site shell

**Status:** ✅ Done. Created custom tab `tabs/Event_Booking.tab-meta.xml` hosting `attendeeEventBooking`, and `applications/Event_Portal.app-meta.xml` standard Lightning Application.

---

## Phase 5 — `attendeeEventBooking` (parent LWC)

**Status:** ✅ Done. Created `Attendee_Workflow/attendeeEventBooking/` (`.html`, `.js`, `.css`, `.js-meta.xml`) with 6-state machine (`BROWSE`, `DETAIL`, `FLOW`, `PAYMENT`, `SOLD_OUT`, `SUCCESS`).

---

## Phase 6 — `Event_Registration_Screen_Flow` (Flow 1) metadata

**Status:** ✅ Done. Generated `flows/Event_Registration_Screen_Flow.flow-meta.xml` implementing all 13 elements: availability check, user/email attendee resolution, review, pending registration creation, and fault routing.

---

## Phase 7 — `paymentQrVerification` (child LWC) — exact spec

**Status:** ✅ Done. Created `Attendee_Workflow/paymentQrVerification/` (`.html`, `.js`, `.css`, `.js-meta.xml`) with 3-step state machine, scannable SVG QR matrix, checkbox gate, and unskippable live 10-second countdown timer.

---

## Phase 8 — `EventBookingController.confirmPayment` (Apex)

**Status:** ✅ Done. Created `Attendee_Workflow/EventBookingController.cls` (+ `EventBookingControllerTest.cls`) with ownership check, duplicate payment guard, idempotency check, amount pinning to `Booked_Price__c`, and registration status flip to `Confirmed`.

---

## Phase 9 — `Post_Registration_Automation` (Flow 2) metadata

**Status:** ✅ Done. Generated `flows/Post_Registration_Automation.flow-meta.xml` triggered on `Registration_Status__c = 'Confirmed'`. Creates active Ticket, follow-up Task, sends confirmation email, and sets `Confirmation_Status__c = 'Sent'`.

---

## Phase 10 — Scheduled Flows (Reminder + Feedback)

**Status:** ✅ Done. Generated `flows/Event_Reminder_Scheduled_Flow.flow-meta.xml` (24h pre-event reminder) and `flows/Post_Event_Feedback_Scheduled_Flow.flow-meta.xml` (post-event survey with feedback deduplication).

---

## Phase 11 — Printable ticket (Visualforce)

**Status:** ✅ Done. Created `pages/PrintableTicket.page` (+ `.page-meta.xml`) rendering a clean A4/letter PDF admission pass with barcode and event summary.

---

## Phase 12 — End-to-end Attendee test plan

**Status:** ✅ Done. Created `E2E_Tests/AttendeeJourneyE2ETest.cls` (+ `.cls-meta.xml`) verifying complete attendee booking lifecycle, payment verification, amount integrity, and ticket creation.

---

## Recommended build order

1. **Phase 1** — confirm/build data foundation (blocks everything else)
2. **Phase 8** — `EventBookingController.confirmPayment` (security-sensitive, do it early and
   carefully, independent of UI)
3. **Phase 7** — `paymentQrVerification` LWC (upload the QR static resource first)
4. **Phase 6** — `Event_Registration_Screen_Flow` metadata
5. **Phase 5** — `attendeeEventBooking` parent LWC (wires 6+7+8 together)
6. **Phase 9** — `Post_Registration_Automation` (Flow 2) — remember the Allow Activities check
7. **Phase 2, 3, 4** — Validation Rules, Access & Visibility, site shell
8. **Phase 10** — Scheduled Flows
9. **Phase 11** — Printable ticket
10. **Phase 12** — End-to-end test plan
