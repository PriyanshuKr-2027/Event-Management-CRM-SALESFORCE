# Event-Management-CRM-SALESFORCE

An Enterprise Event Management CRM built on Salesforce Lightning Platform.

## Overview
This repository contains a full-stack Event Management solution designed for end-to-end event planning, budget approvals, tiered ticket inventory management, multi-attendee bookings, automated payment reconciliation, and real-time executive analytics.

## Key Features
- **Event Lifecycle & Operations**: End-to-end management for In-Person and Virtual events with venue capacity enforcement and speaker coordination.
- **Budget Approval Automation**: Automatic routing for proposed budgets exceeding ₹2,00,000 INR to Manager approval via Salesforce Approval Processes.
- **Atomic Inventory & Ticket Allocation**: Real-time quota validation, automatic 'Sold Out' status transitions, and pessimistic locking via Apex trigger architecture.
- **Attendee Booking Portal (LWC)**:
  - Multi-ticket counter with dynamic quantity increment/decrement (`[-] [ Count ] [+]`).
  - Dynamic Attendee detail capture for all passes.
  - Interactive UPI/QR code payment simulation and verification.
  - "My Tickets" dashboard tab for instant pass access and reprint.
- **Printable Visualforce PDF Passes**: Dynamic group pass rendering with QR barcodes and a full Attendee Roster table.
- **Executive Analytics & Dashboards**: Pre-built Salesforce Lightning reports and a 4-quadrant Executive Dashboard monitoring revenue, approval statuses, feedback, and seat allocations.
- **Role-Based Security & Permissions**: Strict OWD configuration, Role Hierarchy, and dedicated Permission Sets for Event Organizers, Managers, Registration Team, Finance, and Attendees.

## Project Structure
```
├── classes/               # Apex Controllers, Handlers, and Comprehensive Unit Tests (100% Pass Rate)
├── triggers/              # Domain Triggers for Events, Registrations, and Ticket Types
├── lwc/                   # Lightning Web Components (Attendee Booking, QR Verification, Dashboard)
├── pages/                 # Visualforce PDF Template (PrintableTicket.page)
├── objects/               # Custom Objects, Fields, and Validation Rules
├── flows/                 # Screen Flows and Autolaunched Process Flows
├── approvalProcesses/     # Event Budget Approval Workflows
├── permissionsets/        # Granular Security Profiles and Permission Sets
├── reports/               # Native Salesforce Operational & Financial Reports
├── dashboards/            # Executive Dashboards
└── manifest/              # Metadata Deployment Manifests
```
