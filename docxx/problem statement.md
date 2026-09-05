Event Management & Ticketing CRM
Salesforce Final-Year Project — End-to-End Implementation

1. Business Scenario
   An event company needs to manage events, venues, speakers, attendees, registrations, tickets, payments and feedback.
   The goal is to implement a working Salesforce solution that demonstrates the complete lifecycle of the business process rather than isolated configuration exercises.
2. Project Objectives
   • Build a realistic Salesforce data model and user experience.
   • Automate repetitive business processes using Flow.
   • Apply Salesforce security and approval concepts.
   • Use Apex/Trigger for logic that should be handled programmatically.
   • Expose useful business functionality through Visualforce and LWC.
   • Provide reports and dashboards for management decisions.
   • Document, test and demonstrate the complete solution.
3. Main Data Model
   Recommended objects:
   • Event
   • Venue
   • Speaker
   • Attendee
   • Ticket
   • Registration
   • Payment
   • Feedback
4. End-to-End Project Tasks
   Task 1: Admin & Data Model
   Create the event-management app and configure relationships, ticket types, capacity, registration status and payment fields.
   Expected outcome: The feature should be tested with sample records and demonstrated during the final presentation.
   Task 2: Security
   Configure Organizer, Registration Team, Finance, Speaker Coordinator and Admin access.
   Expected outcome: The feature should be tested with sample records and demonstrated during the final presentation.
   Task 3: Screen Flow — Event Registration
   Create a registration flow where an attendee selects an event and ticket type, enters details and receives a Registration record.
   Expected outcome: The feature should be tested with sample records and demonstrated during the final presentation.
   Task 4: Record-Triggered Flow — Registration
   When a registration is created, update available capacity and create a confirmation task/notification.
   Expected outcome: The feature should be tested with sample records and demonstrated during the final presentation.
   Task 5: Scheduled Flow — Event Reminder
   Identify upcoming events and create reminder tasks for registered attendees.
   Expected outcome: The feature should be tested with sample records and demonstrated during the final presentation.
   Task 6: Approval — Event Budget
   Require manager approval for events whose proposed budget exceeds a threshold.
   Expected outcome: The feature should be tested with sample records and demonstrated during the final presentation.
   Task 7: Apex Trigger
   Prevent registrations beyond capacity and calculate available seats in bulk-safe code.
   Expected outcome: The feature should be tested with sample records and demonstrated during the final presentation.
   Task 8: Visualforce
   Create a printable event ticket or attendee pass.
   Expected outcome: The feature should be tested with sample records and demonstrated during the final presentation.
   Task 9: LWC
   Build an Event Dashboard showing registrations, seats, revenue and event status; add event search/filtering.
   Expected outcome: The feature should be tested with sample records and demonstrated during the final presentation.
   Task 10: Reports & Dashboard
   Show event-wise registrations, revenue, attendance, ticket types and feedback results.
   Expected outcome: The feature should be tested with sample records and demonstrated during the final presentation.
5. Suggested End-to-End Business Flow
   Students should demonstrate one complete business journey from data creation through automation, approval/programmatic processing, user interface and reporting.
   Example demonstration sequence:
   • Create the required master records.
   • Create a transaction/request using the Screen Flow or Salesforce UI.
   • Show the Record-Triggered Flow automation.
   • Show approval routing where applicable.
   • Demonstrate Apex/Trigger behavior with valid and invalid test data.
   • Open the Visualforce output.
   • Use the LWC dashboard/component.
   • Finish with Reports and Dashboard showing the business result.
6. Mandatory Salesforce Topics
   • Objects, fields, relationships, tabs, app, page layouts and Lightning Record Pages
   • Formula fields, roll-up summaries and validation rules
   • Record Types and Quick Actions
   • Profiles, Permission Sets, Permission Set Groups, OWD, Role Hierarchy and Sharing
   • Screen Flow, Record-Triggered Flow and Scheduled Flow
   • Approval Process
   • Apex Class, Trigger, SOQL, DML, bulkification and Test Class
   • Visualforce page
   • At least two LWC components
   • Reports and Dashboard
7. Testing Requirements
   • Test normal/success scenarios.
   • Test validation and negative scenarios.
   • Test automation with multiple records to demonstrate bulk behavior.
   • Test approval submission, approval and rejection.
   • Create Apex test data and verify trigger/class results.
   • Verify that users with different permissions cannot access unauthorized data.
8. Final Deliverables
   • Salesforce implementation in the assigned org.
   • Data model/ERD diagram.
   • Configuration and automation documentation.
   • Apex classes, triggers and test classes.
   • Visualforce page and LWC components.
   • Reports and dashboard.
   • Test cases and test results.
   • Screenshots of important implementation steps.
   • Final presentation/demo.
9. Recommended Team Roles
   • Team Member 1 — Admin, Data Model & Security
   • Team Member 2 — Flow & Approval
   • Team Member 3 — Apex, Trigger & Testing
   • Team Member 4 — Visualforce, LWC & UI
   • Team Member 5 — Reports, Documentation & Integration of all modules (if applicable)
10. Final Presentation Checklist
    • Explain the business problem in 2–3 minutes.
    • Explain the data model and relationships.
    • Demonstrate one complete end-to-end scenario.
    • Show security by logging in/using appropriate user access.
    • Demonstrate each Flow and the Approval Process.
    • Show Apex/Trigger behavior and test coverage.
    • Demonstrate Visualforce and both LWCs.
    • Show reports/dashboard and explain business insights.
    • Explain challenges, solutions and future enhancements.
