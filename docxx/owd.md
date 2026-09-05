# Security Architecture, OWD, Roles & Access Control Specification

> **Module:** Security, Access Control & Governance  
> **Source of Truth:** `permissionsets/`, `roles/`, `permissionsetgroups/`, `objects/`, and `ROLE_2_SECURITY_OWD_PERMISSIONS.md`  
> **Target Audience:** Technical Evaluators, Architects & Viva Examiners

---

## 1. Executive Summary & Security Philosophy

The security model of the Event Management CRM is built upon Salesforce's **Defense-in-Depth** and **Principle of Least Privilege (PoLP)** paradigms.

Instead of relying on broad, bloated user profiles, the architecture strictly decouples **Authentication & Base Access** (Profiles) from **Job Function Entitlements** (Permission Sets & Groups), backed by granular **Record-Level Security** (OWD and Role Hierarchy).

```
+-------------------------------------------------------------------------+
|                         1. AUTHENTICATION LAYER                         |
| Login IP Ranges, Login Hours, Multi-Factor Authentication (MFA)         |
+-------------------------------------------------------------------------+
                                     |
                                     v
+-------------------------------------------------------------------------+
|                  2. OBJECT-LEVEL SECURITY (OLS - CRUD)                  |
| Minimal Base Profile + 6 Modular Permission Sets (Manager/Org/Fin/etc.) |
+-------------------------------------------------------------------------+
                                     |
                                     v
+-------------------------------------------------------------------------+
|                 3. FIELD-LEVEL SECURITY (FLS - Read/Edit)               |
| Protects Sensitive Attributes (Proposed_Budget__c, Approved_By__c, etc.)|
+-------------------------------------------------------------------------+
                                     |
                                     v
+-------------------------------------------------------------------------+
|                4. RECORD-LEVEL SECURITY (OWD & Sharing)                 |
| Organization-Wide Defaults (OWD) -> Role Hierarchy -> Criteria Sharing  |
+-------------------------------------------------------------------------+
                                     |
                                     v
+-------------------------------------------------------------------------+
|               5. PROGRAMMATIC SECURITY (Apex Class Sharing)             |
| Enforces 'with sharing' on controllers; 'without sharing' on guest API  |
+-------------------------------------------------------------------------+
```

---

## 2. Organization-Wide Defaults (OWD) Baseline

OWD establishes the **baseline security** for records a user does **not** own. If a user is not the record owner, OWD dictates whether they can view, edit, or even know the record exists.

| Object API Name | OWD Setting | Grant Access Using Hierarchies | Architectural Justification |
| :--- | :--- | :---: | :--- |
| **`Event__c`** | **Private** | **Enabled** | Organizers only view/edit their own assigned events. Event Managers see all events vertically via the Role Hierarchy. Public users interact via controlled portal interfaces. |
| **`Venue__c`** | **Public Read Only** | **Enabled** | Physical venues are shared corporate facilities. All organizers must be able to view venue capacities, locations, and amenities, but only Operations/Admins can create or modify them. |
| **`Attendee__c`** | **Private** | **Enabled** | Contains Personal Identifiable Information (PII) including phone, email, and corporate affiliation. Restricted to protect customer privacy. |
| **`Registration__c`** | **Controlled by Parent** | N/A (Inherited) | Master-Detail relationship with `Event__c`. Security is automatically inherited from the parent event record. |
| **`Ticket_Type__c`** | **Controlled by Parent** | N/A (Inherited) | Master-Detail relationship with `Event__c`. Tightly coupled with the event lifecycle. |
| **`Ticket__c`** | **Controlled by Parent** | N/A (Inherited) | Master-Detail relationship with `Registration__c`. Passes inherit access from registrations. |
| **`Payment__c`** | **Controlled by Parent** | N/A (Inherited) | Master-Detail relationship with `Registration__c`. Payment data inherits access from registration. |
| **`Feedback__c`** | **Controlled by Parent** | N/A (Inherited) | Master-Detail relationship with `Event__c`. Organizers review feedback for events they manage. |

> **Key Viva Tip for Examiners:**  
> When asked: *"Why do Ticket_Type__c, Registration__c, Ticket__c, Payment__c, and Feedback__c not have an independent OWD setting in Sharing Settings?"*  
> **Answer:** *"Sir, because they are on the detail side of a Master-Detail relationship. In Salesforce, detail objects cannot have independent OWD settings; their access is strictly 'Controlled by Parent'."*

---

## 3. Role Hierarchy Architecture

Salesforce uses Role Hierarchy to **open up record access vertically** above the record owner for objects with Private or Public Read-Only OWD. We enabled **Grant Access Using Hierarchies** across all custom objects.

### Role Hierarchy Tree:

```
               +-----------------------------------+
               |        Event Manager (Role)       |
               | (Full org-wide oversight, reports)|
               +-----------------------------------+
                                 |
         +-----------------------+-----------------------+
         |                       |                       |
         v                       v                       v
+-----------------+     +-----------------+     +-----------------+
| Event Organizer |     |  Event Finance  |     | Event Speaker   |
|     (Role)      |     |     (Role)      |     |   Coordinator   |
+-----------------+     +-----------------+     +-----------------+
         |
         v
+-------------------------+
| Event Registration Team |
|         (Role)          |
+-------------------------+
```

### Role Access & Functional Responsibilities:

1. **Event Manager (`roles/Event_Manager.role-meta.xml`)**:
   - Executive head sitting at the apex of the operational hierarchy.
   - Automatically inherits Read and Edit access to all `Event__c` and child records created by Organizers and Registration staff.
   - Executive authority for event approvals and org-wide financial reports.
2. **Event Organizer (`roles/Event_Organizer.role-meta.xml`)**:
   - Creates and manages assigned events, sets up ticket tiers, coordinates venue booking, and monitors attendance.
   - Subordinate to Event Manager; cannot view peer organizers' private events.
3. **Event Registration Team (`roles/Event_Registration_Team.role-meta.xml`)**:
   - Handles on-desk check-in, manual ticket issuance, and attendee registration assistance.
   - Sits beneath Event Organizer in the hierarchy.
4. **Event Finance (`roles/Event_Finance.role-meta.xml`)**:
   - Reviews payment records, payment gateway transaction IDs, budget allocations, and revenue reconciliation.
5. **Event Speaker Coordinator (`roles/Event_Speaker_Coordinator.role-meta.xml`)**:
   - Manages speaker profiles, session scheduling, and logistics.

---

## 4. Modern Profiles vs. Permission Sets Strategy

### The Modern Salesforce Best Practice:
Rather than proliferating hard-to-maintain custom profiles, our architecture uses:
- **Base Profile:** Standard User / Minimum Access Profile.
- **6 Modular Permission Sets:** Assigned according to job functions.
- **1 Permission Set Group (`Event_Management_Core_Access`):** Bundles common operational permissions.

### Permission Sets Breakdown:

#### 1. `Event_Manager_Permissions` (`permissionsets/Event_Manager_Permissions.permissionset-meta.xml`)
- **OLS:** View All & Modify All on `Event__c`, `Venue__c`, `Speaker__c`, `Attendee__c`, `Registration__c`, `Payment__c`, `Feedback__c`.
- **FLS:** Read/Edit on `Proposed_Budget__c`, `Total_Budget__c`, `Approval_Status__c`, `Approved_By__c`, `Payment__c.Transaction_Id__c`.
- **Custom Metadata Access:** `Approval_Matrix__mdt`, `Approval_Settings__mdt`, `Payment_Gateway_Config__mdt`.
- **Apex Access:** `OrganizerDashboardController`, `EventBookingController`, `PrintableTicketExtension`, `EventApprovalService`, `PaymentGatewayService`.
- **Visualforce Access:** `PrintableTicket`.

#### 2. `Event_Organizer_Permissions` (`permissionsets/Event_Organizer_Permissions.permissionset-meta.xml`)
- **OLS:** Full CRUD on `Event__c`, `Ticket_Type__c`, `Registration__c`, `Attendee__c`, `Feedback__c`; Read-Only on `Venue__c`.
- **FLS:** Read/Edit on `Proposed_Budget__c`, `Total_Budget__c`; Read-Only on `Approved_By__c`, `Approval_Status__c`.
- **Custom Metadata Access:** `Approval_Matrix__mdt`, `Approval_Settings__mdt`, `Payment_Gateway_Config__mdt`.
- **Apex Access:** `OrganizerDashboardController`, `PrintableTicketExtension`, `EventApprovalService`.
- **Visualforce Access:** `PrintableTicket`.

#### 3. `Event_Registration_Team_Permissions` (`permissionsets/Event_Registration_Team_Permissions.permissionset-meta.xml`)
- **OLS:** Create, Read, Edit on `Attendee__c`, `Registration__c`, `Ticket__c`; Read on `Event__c` and `Ticket_Type__c`.
- **FLS:** Access to `Attendee__c.Email__c`, `Phone__c`, `Company__c`, `Registration_Date__c`, `Status__c`, `Ticket_Type__c`.
- **Custom Metadata Access:** `Payment_Gateway_Config__mdt`.
- **Apex Access:** `EventBookingController`, `PrintableTicketExtension`.
- **Visualforce Access:** `PrintableTicket`.

#### 4. `Event_Finance_Permissions` (`permissionsets/Event_Finance_Permissions.permissionset-meta.xml`)
- **OLS:** Read & Edit on `Payment__c`; Read on `Event__c`, `Registration__c`, `Ticket_Type__c`.
- **FLS:** Read/Edit on `Payment__c.Transaction_Id__c`, `Payment_Status__c`, `Payment_Method__c`, `Payment_Date__c`, `Total_Amount__c`, `Discount_Code__c`; Read-Only on `Event__c.Proposed_Budget__c`, `Approved_By__c`.
- **Custom Metadata Access:** `Approval_Matrix__mdt`, `Payment_Gateway_Config__mdt`.

#### 5. `Event_Speaker_Coordinator_Permissions` (`permissionsets/Event_Speaker_Coordinator_Permissions.permissionset-meta.xml`)
- **OLS:** Full CRUD on `Speaker__c`; Read on `Event__c`, `Venue__c`.
- **FLS:** `Speaker__c.Bio__c`, `Email__c`, `Phone__c`, `Expertise__c`, `Organization__c`.

#### 6. `Event_Attendee_Permissions` (`permissionsets/Event_Attendee_Permissions.permissionset-meta.xml`)
- **OLS:** Create & Edit on `Attendee__c`, `Registration__c`, `Payment__c`, `Feedback__c`; Read-Only on published `Event__c`, `Venue__c`, `Ticket_Type__c`.
- **FLS:** Access to self-service booking fields, feedback rating, and payment submission details.
- **Custom Metadata Access:** `Payment_Gateway_Config__mdt` (to render UPI QR codes).

---

## 5. Field-Level Security (FLS) Matrix

FLS ensures that users can only see and edit fields relevant to their job, preventing unauthorized visibility of financial or confidential information.

| Object | Field Name | Manager | Organizer | Finance | Reg Team | Speaker Coord | Attendee |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **`Event__c`** | `Proposed_Budget__c` | **Read/Edit** | **Read/Edit** | **Read Only** | No Access | No Access | No Access |
| **`Event__c`** | `Total_Budget__c` | Read/Edit | Read/Edit | Read Only | No Access | No Access | No Access |
| **`Event__c`** | `Approved_By__c` | **Read/Edit** | **Read Only** | **Read Only** | No Access | No Access | No Access |
| **`Event__c`** | `Approval_Status__c` | Read/Edit | Read Only | Read Only | Read Only | Read Only | Read Only |
| **`Event__c`** | `Total_Revenue__c` | Read Only | Read Only | Read Only | No Access | No Access | No Access |
| **`Attendee__c`** | `Email__c` / `Phone__c` | Read/Edit | Read/Edit | Read Only | Read/Edit | No Access | Read/Edit |
| **`Registration__c`** | `Discount_Code__c` | Read/Edit | Read/Edit | Read Only | Read/Edit | No Access | Read/Edit |
| **`Payment__c`** | `Transaction_Id__c` | Read/Edit | Read Only | Read/Edit | Read Only | No Access | Read Only |
| **`Payment__c`** | `Payment_Status__c` | Read/Edit | Read Only | Read/Edit | Read Only | No Access | Read Only |
| **`Speaker__c`** | `Email__c` / `Bio__c` | Read/Edit | Read/Edit | No Access | No Access | Read/Edit | No Access |

> **Special Architectural Rule on Universally Required Fields:**  
> In Salesforce metadata, fields defined with `<required>true</required>` (e.g., `Event__c.Category__c`, `Event__c.Venue__c`, `Event__c.Start_Date_Time__c`, `Ticket_Type__c.Price__c`) **cannot** be explicitly declared in `<fieldPermissions>` in permission set XML files.  
> Attempting to do so triggers a deployment failure: `Cannot specify field permissions for universally required field`.  
> In Salesforce, access to universally required fields is automatically inherited whenever a user has Object-Level Security (OLS).

---

## 6. Custom Metadata Type Security (`<customMetadataTypeAccesses>`)

In modern Salesforce releases, when the org security setting **"Require Customize Application permission for direct read access to custom metadata types"** is enabled, non-admin users cannot query Custom Metadata records via SOQL or Apex without explicit permission grants.

| Custom Metadata Type | Description | Granted To | Justification |
| :--- | :--- | :--- | :--- |
| **`Approval_Matrix__mdt`** | Multi-Tier dynamic budget approval thresholds per category | `Event_Manager_Permissions`<br>`Event_Organizer_Permissions`<br>`Event_Finance_Permissions` | Organizers submit events against thresholds; Managers and Finance review category approval rules. |
| **`Approval_Settings__mdt`** | Global approval rules & flags | `Event_Manager_Permissions`<br>`Event_Organizer_Permissions` | Checked by `EventApprovalService` to determine whether approval routing is globally active. |
| **`Payment_Gateway_Config__mdt`**| UPI VPA, Merchant Name, Sandbox credentials | `Event_Manager_Permissions`<br>`Event_Organizer_Permissions`<br>`Event_Finance_Permissions`<br>`Event_Attendee_Permissions`<br>`Event_Registration_Team_Permissions` | Attendees and Registration staff need to render dynamic UPI QR codes and retrieve active merchant configuration. |

---

## 7. Sharing Enforcement in Apex Code (`with sharing` vs `without sharing`)

- **`OrganizerDashboardController.cls` (`public with sharing class`)**:
  - Enforces record-level security. When an Organizer logs in, SOQL automatically scopes to records they own or have explicit sharing access to. When an Event Manager logs in, Role Hierarchy automatically allows them to see all records.
- **`EventApprovalService.cls` (`public with sharing class`)**:
  - Ensures that only users who have permission to view or edit the `Event__c` record can evaluate its approval status or submit it for review.
- **`PaymentGatewayService.cls` (`public with sharing class`)**:
  - Adheres to least privilege when reading payment metadata and generating secure cryptographic webhook HMAC signatures.
- **`EventBookingController.cls` (`public without sharing class`)**:
  - Attendees booking tickets through the public or guest portal do not own the `Event__c`, `Ticket_Type__c`, or `Registration__c` records. If `with sharing` were used, guest users would receive an authorization fault when attempting to query remaining capacity or create registration records. The controller uses strict input validation and server-side verification to maintain data integrity safely.

---

## 8. Viva Q&A Cheat Sheet (Security & Permissions)

### Q1: "What is the difference between Role Hierarchy and Profiles?"
> **Answer:**  
> *"Profiles determine **what actions** a user can perform on an object (Create, Read, Edit, Delete, View All, Modify All) and which fields they can see (FLS).  
> Role Hierarchy determines **which records** a user can view and edit based on who owns the record. It opens up record visibility vertically upwards in the hierarchy for records with Private or Public Read-Only OWD."*

### Q2: "Why did you use Permission Sets instead of giving permissions on Profiles?"
> **Answer:**  
> *"Sir, Salesforce is retiring permissions on profiles in favor of Permission Sets. Following modern Salesforce best practices, we kept profiles minimal and used Permission Sets to grant functional permissions. This allows modular assignment—for example, an Organizer who also handles finance tasks can be assigned `Event_Organizer_Permissions` and `Event_Finance_Permissions` without needing a new profile."*

### Q3: "What happens if a field is hidden via FLS, but is displayed in an LWC?"
> **Answer:**  
> *"If the Apex controller or UI API enforces FLS (e.g. through `WITH USER_MODE` or `Schema.sObjectType...isAccessible()`), the field value will be stripped or nullified before being rendered in the LWC. If Apex runs in `without sharing` or system mode without checks, it queries the field, which is why explicit controller checks are vital."*

### Q4: "Can an Event Organizer see events created by another Event Organizer?"
> **Answer:**  
> *"No, Sir. Because the OWD for `Event__c` is set to **Private**, and Organizers sit at the same peer level in the Role Hierarchy. Neither organizer reports to the other. Therefore, they only see events where they are the designated record Owner. Only the Event Manager above them sees both."*

### Q5: "Why did you add `<customMetadataTypeAccesses>` in Permission Sets?"
> **Answer:**  
> *"In modern Salesforce orgs, non-admin users cannot query Custom Metadata records unless explicit access is granted via Profiles or Permission Sets. Since our dynamic approval thresholds and payment gateway configuration reside in Custom Metadata (`Approval_Matrix__mdt` and `Payment_Gateway_Config__mdt`), we granted explicit access in our permission sets so that organizers and attendees can access them smoothly without requiring administrator privileges."*
