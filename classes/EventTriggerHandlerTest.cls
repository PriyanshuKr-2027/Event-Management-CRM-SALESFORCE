@IsTest
private class EventTriggerHandlerTest {

    private static Venue__c createVenue(String name, Decimal capacity) {
        Venue__c v = new Venue__c(
            Name = name,
            City__c = 'New Delhi',
            Venue_Capacity__c = capacity,
            Status__c = 'Active'
        );
        insert v;
        return v;
    }

    private static Event__c createEvent(Id venueId, String name, Datetime startDt, Datetime endDt) {
        Event__c ev = new Event__c(
            Name = name,
            Category__c = 'Conference',
            Start_Date_Time__c = startDt,
            End_Date_Time__c = endDt,
            Venue__c = venueId,
            Organizer__c = UserInfo.getUserId(),
            Proposed_Budget__c = 1000,
            Approval_Status__c = 'Approved',
            Publication_Status__c = 'Published',
            Registration_Status__c = 'Open'
        );
        return ev;
    }

    private static Ticket_Type__c createTicketType(Id eventId, Decimal quota) {
        Ticket_Type__c tt = new Ticket_Type__c(
            Name = 'General Admission',
            Event__c = eventId,
            Price__c = 100,
            Quota__c = quota,
            Booked_Seats__c = 0,
            Status__c = 'Available'
        );
        insert tt;
        return tt;
    }

    @IsTest
    static void testVenueDoubleBooking_OverlappingDates_Blocked() {
        Venue__c venue = createVenue('Grand Hall', 500);

        Datetime start1 = Datetime.now().addDays(10);
        Datetime end1   = start1.addHours(4);

        Event__c event1 = createEvent(venue.Id, 'Tech Expo 2026', start1, end1);
        insert event1;

        // Overlapping event: starts 2 hours into event1
        Datetime start2 = start1.addHours(2);
        Datetime end2   = start2.addHours(4);
        Event__c event2 = createEvent(venue.Id, 'Design Con 2026', start2, end2);

        Test.startTest();
        Boolean failed = false;
        try {
            insert event2;
        } catch (DmlException e) {
            failed = true;
            System.assert(e.getMessage().contains('Venue is already booked for'),
                'Expected double booking error but got: ' + e.getMessage());
        }
        Test.stopTest();

        System.assert(failed, 'Overlapping venue booking should be blocked.');
    }

    @IsTest
    static void testVenueBooking_NonOverlappingDates_Succeeds() {
        Venue__c venue = createVenue('Grand Hall', 500);

        Datetime start1 = Datetime.now().addDays(10);
        Datetime end1   = start1.addHours(4);
        Event__c event1 = createEvent(venue.Id, 'Morning Summit', start1, end1);
        insert event1;

        // After event1 finishes
        Datetime start2 = end1.addHours(1);
        Datetime end2   = start2.addHours(4);
        Event__c event2 = createEvent(venue.Id, 'Evening Gala', start2, end2);

        Test.startTest();
        insert event2;
        Test.stopTest();

        System.assertNotEquals(null, event2.Id, 'Non-overlapping venue booking should succeed.');
    }

    @IsTest
    static void testDifferentVenues_SameTime_Succeeds() {
        Venue__c venue1 = createVenue('Auditorium A', 300);
        Venue__c venue2 = createVenue('Auditorium B', 300);

        Datetime startDt = Datetime.now().addDays(10);
        Datetime endDt   = startDt.addHours(4);

        Event__c event1 = createEvent(venue1.Id, 'Track 1', startDt, endDt);
        Event__c event2 = createEvent(venue2.Id, 'Track 2', startDt, endDt);

        Test.startTest();
        insert new List<Event__c>{ event1, event2 };
        Test.stopTest();

        System.assertNotEquals(null, event1.Id);
        System.assertNotEquals(null, event2.Id);
    }

    @IsTest
    static void testCancelledEvent_DoesNotBlockVenue() {
        Venue__c venue = createVenue('Hall C', 200);

        Datetime startDt = Datetime.now().addDays(10);
        Datetime endDt   = startDt.addHours(4);

        Event__c cancelledEvent = createEvent(venue.Id, 'Cancelled Con', startDt, endDt);
        cancelledEvent.Approval_Status__c = 'Cancelled';
        cancelledEvent.Publication_Status__c = 'Unpublished';
        insert cancelledEvent;

        Event__c newEvent = createEvent(venue.Id, 'Replacement Con', startDt, endDt);

        Test.startTest();
        insert newEvent;
        Test.stopTest();

        System.assertNotEquals(null, newEvent.Id, 'Cancelled event should not block another event from using the venue.');
    }

    @IsTest
    static void testVenueCapacityDowngrade_ExceedsQuota_Blocked() {
        Venue__c bigVenue   = createVenue('Convention Center', 500);
        Venue__c smallVenue = createVenue('Meeting Room', 50);

        Datetime startDt = Datetime.now().addDays(10);
        Datetime endDt   = startDt.addHours(4);

        Event__c ev = createEvent(bigVenue.Id, 'Big Event', startDt, endDt);
        insert ev;

        // Create ticket type with quota 200 (fits big venue 500, but exceeds small venue 50)
        createTicketType(ev.Id, 200);

        Test.startTest();
        Boolean failed = false;
        try {
            ev.Venue__c = smallVenue.Id;
            update ev;
        } catch (DmlException e) {
            failed = true;
            System.assert(e.getMessage().contains('exceed the new venue capacity'),
                'Expected downgrade capacity error but got: ' + e.getMessage());
        }
        Test.stopTest();

        System.assert(failed, 'Downgrading venue below ticket quotas should be blocked.');
    }
}
