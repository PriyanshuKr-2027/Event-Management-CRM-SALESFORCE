# Speaker Talking Notes & Evaluator Q&A

Use these speaker notes while navigating through [`presentation/index.html`](file:///c:/Users/10pri/Downloads/evmos%20saleforce/presentation/index.html).

---

### Slide 1: Title & Executive Summary
- **Key Message**: Introduce yourself and the system as an enterprise-grade, transactional CRM built 100% native on Salesforce.
- **Talking Point**: "Most student or demo projects focus only on basic CRUD forms. This project tackles real-world enterprise engineering challenges: handling concurrent ticket bookings, financial approvals, automated lifecycle fulfillment, and strict Salesforce governor limits."

---

### Slide 2: Problem Statement vs. Solution
- **Key Message**: Contrast manual operational pain points with your automated CRM solution.
- **Talking Point**: "Before this system, event organizers faced manual budget approval delays, lack of inventory locking that led to overselling venues, and manual email reminder overhead. We replaced that with an end-to-end automated platform."

---

### Slide 3: 4-Tier System Architecture
- **Key Message**: Demonstrate deep architectural thinking.
- **Talking Point**: "Our architecture has four distinct layers: LWC for customer-facing responsiveness, declarative Flows for agile business workflows, Apex with row locks for high-concurrency transactional safety, and Salesforce's native security model for data protection."

---

### Slide 4: Data Model & ERD
- **Key Message**: Justify your relationship types.
- **Anticipated Question**: *"Why did you use a Lookup relationship between `Event__c` and `Ticket_Type__c` instead of Master-Detail?"*
- **Answer**: "Because in event management, we need independent security permissions, custom archiving, and we want to prevent cascading deletions if an event record is ever modified. To manage `Booked_Seats__c` without master-detail roll-ups, we wrote an atomic counter in our Apex trigger."

---

### Slide 5: End-to-End Workflow Flowchart
- **Key Message**: Walk through the 6 phases from ideation to post-event survey.
- **Talking Point**: "Phase 1 is Organizer creation, Phase 2 is the Budget Approval gate, Phase 3 is Portal discovery, Phase 4 is atomic checkout, Phase 5 is ticket issuance, and Phase 6 is automated background lifecycle reminders."

---

### Slide 6: Event Creation & Budget Approval Engine
- **Key Message**: Highlight the embedded LWC inside the Screen Flow.
- **Talking Point**: "In `Event_Creation_Screen_Flow`, we embedded our custom `ticketTypeCollector` LWC to allow organizers to add multiple ticket tiers dynamically. If the proposed budget exceeds the threshold, the Flow automatically halts publication and routes to a manager for approval."

---

### Slide 7: Attendee Portal & Dynamic Booking (LWC)
- **Key Message**: Showcase the consumer-grade front-end experience.
- **Talking Point**: "The `attendeeEventBooking` LWC features real-time search, category filtering, multi-ticket selection for guests, client-side 10-digit phone regex validation, and an interactive simulated UPI/QR payment modal."

---

### Slide 8: Concurrency & Transaction Safety *(Star Slide)*
- **Key Message**: Explain the race condition fix.
- **Anticipated Question**: *"Why can't you just use a Validation Rule to prevent overselling?"*
- **Answer**: "Validation Rules only evaluate the start-of-transaction snapshot. If two users check out at the exact same millisecond for the last ticket, both will pass the Validation Rule and oversell the venue. We solved this by using `SELECT ... FOR UPDATE` row-level locking in `RegistrationTriggerHandler.cls`, forcing the database to process checkouts sequentially."

---

### Slide 9: Post-Booking Automation & Bulkified Scheduled Flows
- **Key Message**: Highlight your governor limit mastery.
- **Anticipated Question**: *"How do your scheduled flows handle events with hundreds of attendees without hitting governor limits?"*
- **Answer**: "Our scheduled flows are completely bulkified. We eliminated SOQL queries inside loops by filtering `Feedback_Submitted__c = false` upfront, and we accumulate email addresses in memory to dispatch a single batch email outside the loop, consuming only 1 out of 10 allowed email invocations."

---

### Slide 10: Security Model & Persona Matrix
- **Key Message**: Explain role-based access control.
- **Talking Point**: "We configured Private Organization-Wide Defaults (OWD) on sensitive financial objects like `Payment__c` and `Registration__c`, while keeping `Event__c` and `Venue__c` Public Read Only so attendees can browse."

---

### Slide 11: Business Impact & Q&A
- **Key Message**: Summarize the 3 key metrics (100% zero-oversell guarantee, 100% automated fulfillment, and 1 of 10 governor limit consumption) and transition to live demo or questions.
