# Presentation Screenshots Guide

Save your real system screenshots directly into this folder (`presentation/screenshots/`) using the exact filenames below. The presentation slide deck (`presentation/index.html`) will automatically display them!

---

### Screenshot Checklist & Filenames

| Filename | Slide | Description | How to Capture |
| :--- | :--- | :--- | :--- |
| `screenshot-event-creation.png` | **Slide 6** | Event Creation Wizard with dynamic ticket types | Open `Event_Creation_Screen_Flow` in Salesforce, fill basic event details, and capture the ticket types table. |
| `screenshot-approval-history.png` | **Slide 6** | Event Approval Process | Open an Event with budget > threshold, show the `Approval History` related list with `Pending Approval` or `Approved`. |
| `screenshot-attendee-portal.png` | **Slide 7** | Attendee Event Booking Portal | Open `attendeeEventBooking` LWC on the home/app page showing the event cards, search bar, and category filter. |
| `screenshot-qr-payment.png` | **Slide 7** | QR Code Payment Modal | Click "Proceed to Payment" during a booking to display the `paymentQrVerification` UPI/QR payment modal. |
| `screenshot-my-tickets.png` | **Slide 7** | Attendee "My Tickets" Tab | Click the "My Tickets" tab in the attendee portal showing confirmed tickets with ticket IDs and QR codes. |
| `flow-1-event-creation.png` | **Slide 9** | Flow 1: Event Creation Screen Flow Canvas | Open Flow Builder for `Event_Creation_Screen_Flow`, zoom to fit canvas, screenshot left-to-right nodes. |
| `flow-2-event-registration.png` | **Slide 10** | Flow 2: Event Registration Screen Flow Canvas | Open Flow Builder for `Event_Registration_Screen_Flow`, capture canvas with decision branch & screens. |
| `flow-3-post-registration.png` | **Slide 11** | Flow 3: Post-Registration Automation Flow Canvas | Open Flow Builder for `Post_Registration_Automation` showing ticket creation, task, email & fault paths. |
| `flow-4-event-reminder.png` | **Slide 12** | Flow 4: 24h Event Reminder Scheduled Flow Canvas | Open Flow Builder for `Event_Reminder_Scheduled_Flow` showing query, loop accumulator & batch email. |
| `flow-5-post-event-feedback.png` | **Slide 13** | Flow 5: Post-Event Feedback Scheduled Flow Canvas | Open Flow Builder for `Post_Event_Feedback_Scheduled_Flow` showing anti-spam filter, loop & batch survey dispatch. |
| `screenshot-dashboard.png` | **Slide 15** | Event Analytics Dashboard | Open your Event Management Dashboard showing reports, revenue, registrations, and capacity charts. |

---

> [!TIP]
> **Automatic Fallbacks:** If a screenshot is not yet dropped in this folder, the slide deck automatically falls back to our rendered high-resolution vector diagrams in `presentation/visuals/`!

### Tips for Best Quality
1. **Aspect Ratio**: 16:9 or clean window crops (1920x1080 or 1280x720) work best.
2. **Format**: PNG (`.png`) recommended for sharp text.
3. Once placed in this folder, simply refresh `presentation/index.html` in your browser!

