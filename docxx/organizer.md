## organizer flow

                 EVENT ORGANIZER
                       │
                       ▼
                  LOGIN
                       │
                       ▼
               ORGANIZER DASHBOARD
                       │
                [+ CREATE EVENT]
                       │
                       ▼
                  SCREEN FLOW
                       │
        ┌──────────────┼──────────────┐
        │              │              │
      Details       Date/Time       Venue
        │              │              │
        └──────────────┼──────────────┘
                       │
                       │
                 Create Ticket Types
                      │
                      ├── Add Ticket Type
                      │ ├── Name
                      │ ├── Price
                      │ ├── Quota
                      │ └── Description
                      │
                      ├── Add another
                      │
                      ├── Add another
                      │
                      └── Done
                           |
                           │
                    System calculates Total Capacity
                           |
                           |
                    ┌───────────────────────┐
                    │ Enter Proposed Budget │
                    └───────────┬───────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │   Submit Event        │
                    └───────────┬───────────┘
                                │
                                ▼
                  ┌─────────────────────────────┐
                  │ Is Budget > Approval        │
                  │       Threshold?            │
                  └─────────────┬───────────────┘
                           ┌────┴────┐
                         NO│         │YES
                           │         │
                           ▼         ▼
                ┌──────────────┐   ┌────────────────────┐
                │   APPROVED   │   │ PENDING APPROVAL   │
                └──────┬───────┘   └─────────┬──────────┘
                       │                     │
                       │                     ▼
                       │           ┌────────────────────┐
                       │           │   EVENT MANAGER    │
                       │           │  Reviews Request   │
                       │           └─────────┬──────────┘
                       │                     │
                       │              ┌──────┴──────┐
                       │              │             │
                       │           APPROVE        REJECT
                       │              │             │
                       │              ▼             ▼
                       │       ┌──────────────┐  ┌──────────────┐
                       │       │   APPROVED   │  │   REJECTED   │
                       │       └──────┬───────┘  └──────┬───────┘
                       │              │                 │
                       │              │                 ▼
                       │              │       ┌─────────────────────┐
                       │              │       │ Organizer Notified  │
                       │              │       │ + Rejection Reason  │
                       │              │       └──────────┬──────────┘
                       │              │                  │
                       │              │           ┌──────┴───────┐
                       │              │           │              │
                       │              │           ▼              ▼
                       │              │    EDIT & RESUBMIT   CANCEL EVENT
                       │              │           │              │
                       │              │           ▼              ▼
                       │              │    ┌──────────────┐  ┌───────────┐
                       │              │    │ Modify Event │  │ CANCELLED │
                       │              │    │ / Budget     │  └───────────┘
                       │              │    └──────┬───────┘
                       │              │           │
                       │              │           ▼
                       │              │    ┌─────────────────┐
                       │              │    │     RESUBMIT    │
                       │              │    └────────┬────────┘
                       │              │             │
                       │              │             ▼
                       │              │    ┌────────────────────┐
                       │              │    │ Budget > Threshold?│
                       │              │    └─────────┬──────────┘
                       │              │         ┌───┴───┐
                       │              │       NO│       │YES
                       │              │         │       │
                       │              │         ▼       ▼
                       │              │    APPROVED   PENDING
                       │              │                APPROVAL
                       │              │                   │
                       │              │                   │
                       │              └───────────────────┘
                       │
                       ▼
             ┌───────────────────────┐
             │ ORGANIZER CAN PUBLISH │
             │   APPROVED EVENT      │
             └───────────┬───────────┘
                         │
                         ▼
                   ┌────────────┐
                   │  PUBLISHED │
                   └────────────┘

## Dynamic ticket types

Event → Ticket Types
We'll have a separate Ticket Type custom object related to Event.
EVENT
│
├── Ticket Type 1
│ ├── Name
│ ├── Price
│ ├── Quota
│ ├── Booked Seats
│ └── Available Seats
│
├── Ticket Type 2
│ ├── Name
│ ├── Price
│ ├── Quota
│ ├── Booked Seats
│ └── Available Seats
│
└── Ticket Type 3
├── Name
├── Price
├── Quota
├── Booked Seats
└── Available Seats

Event Capacity = total of all Ticket Type quotas.
