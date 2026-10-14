@IsTest
private class PrintableTicketExtensionTest {

    private static Venue__c createVenue() {
        Venue__c v = new Venue__c(
            Name = 'Grand Convention Center',
            City__c = 'San Francisco',
            Address__c = '100 Market St',
            Venue_Capacity__c = 500,
            Status__c = 'Active'
        );
        insert v;
        return v;
    }

    private static Event__c createEvent(Id venueId) {
        Event__c ev = new Event__c(
            Name = 'Cloud Developers Summit',
            Category__c = 'Conference',
            Start_Date_Time__c = Datetime.now().addDays(5),
            End_Date_Time__c = Datetime.now().addDays(5).addHours(4),
            Venue__c = venueId,
            Organizer__c = UserInfo.getUserId(),
            Proposed_Budget__c = 15000,
            Approval_Status__c = 'Approved',
            Publication_Status__c = 'Published',
            Registration_Status__c = 'Open'
        );
        insert ev;
        return ev;
    }

    private static Speaker__c createSpeaker(String name, String email, String org, String expertise) {
        Speaker__c sp = new Speaker__c(
            Name = name,
            Email__c = email,
            Organization__c = org,
            Expertise__c = expertise,
            Status__c = 'Active'
        );
        insert sp;
        return sp;
    }

    private static Ticket_Type__c createTicketType(Id eventId) {
        Ticket_Type__c tt = new Ticket_Type__c(
            Name = 'VIP Pass',
            Event__c = eventId,
            Price__c = 250,
            Quota__c = 50,
            Booked_Seats__c = 0,
            Status__c = 'Available'
        );
        insert tt;
        return tt;
    }

    private static Attendee__c createAttendee(String name, String email) {
        Attendee__c att = new Attendee__c(
            Name = name,
            Email__c = email,
            Phone__c = '9876543210',
            Attendee_Status__c = 'Active'
        );
        insert att;
        return att;
    }

    @IsTest
    static void testSingleTicketWithSpeakers() {
        Venue__c venue = createVenue();
        Event__c event = createEvent(venue.Id);
        Speaker__c speaker = createSpeaker('Dr. Jane Doe', 'jane.doe@example.com', 'Apex Labs', 'Architecture');
        
        // Link speaker via junction
        Event_Speaker__c es = new Event_Speaker__c(
            Event__c = event.Id,
            Speaker__c = speaker.Id,
            Role__c = 'Keynote',
            Session_Title__c = 'The Future of Cloud Architecture',
            Display_Order__c = 1
        );
        insert es;

        Ticket_Type__c tt = createTicketType(event.Id);
        Attendee__c attendee = createAttendee('John Booker', 'john.booker@example.com');

        Registration__c reg = new Registration__c(
            Event__c = event.Id,
            Ticket_Type__c = tt.Id,
            Attendee__c = attendee.Id,
            Booked_Price__c = 250,
            Registration_Status__c = 'Confirmed',
            Booking_Group_Id__c = 'BKG-TEST-123'
        );
        insert reg;

        List<Ticket__c> tkts = [SELECT Id FROM Ticket__c WHERE Registration__c = :reg.Id];
        Ticket__c tkt;
        if (!tkts.isEmpty()) {
            tkt = tkts[0];
        } else {
            tkt = new Ticket__c(
                Registration__c = reg.Id,
                Ticket_Status__c = 'Active',
                Issue_Date_Time__c = Datetime.now()
            );
            insert tkt;
        }

        Test.startTest();
        PageReference pageRef = Page.PrintableTicket;
        pageRef.getParameters().put('id', tkt.Id);
        Test.setCurrentPage(pageRef);

        PrintableTicketExtension ext = new PrintableTicketExtension();
        Test.stopTest();

        System.assertNotEquals(null, ext.primaryTicket.Id, 'Primary ticket should be loaded.');
        System.assertEquals(1, ext.totalAttendeeCount, 'Attendee count should be 1.');
        System.assertEquals(true, ext.hasSpeakers, 'Should have speakers.');
        System.assertEquals(1, ext.eventSpeakers.size(), 'Should find 1 speaker.');
        System.assertEquals('Dr. Jane Doe', ext.eventSpeakers[0].Speaker__r.Name);
    }

    @IsTest
    static void testGroupBookingPass() {
        Venue__c venue = createVenue();
        Event__c event = createEvent(venue.Id);
        Ticket_Type__c tt = createTicketType(event.Id);

        Attendee__c att1 = createAttendee('Attendee One', 'att1@example.com');
        Attendee__c att2 = createAttendee('Attendee Two', 'att2@example.com');

        String groupId = 'BKG-MULTI-789';
        Registration__c reg1 = new Registration__c(
            Event__c = event.Id,
            Ticket_Type__c = tt.Id,
            Attendee__c = att1.Id,
            Booked_Price__c = 250,
            Registration_Status__c = 'Confirmed',
            Booking_Group_Id__c = groupId
        );
        Registration__c reg2 = new Registration__c(
            Event__c = event.Id,
            Ticket_Type__c = tt.Id,
            Attendee__c = att2.Id,
            Booked_Price__c = 250,
            Registration_Status__c = 'Confirmed',
            Booking_Group_Id__c = groupId
        );
        insert new List<Registration__c>{ reg1, reg2 };

        List<Ticket__c> tkts = [SELECT Id FROM Ticket__c WHERE Registration__r.Booking_Group_Id__c = :groupId];
        Ticket__c tkt1;
        if (tkts.isEmpty()) {
            tkt1 = new Ticket__c(Registration__c = reg1.Id, Ticket_Status__c = 'Active');
            Ticket__c tkt2 = new Ticket__c(Registration__c = reg2.Id, Ticket_Status__c = 'Active');
            insert new List<Ticket__c>{ tkt1, tkt2 };
        } else {
            tkt1 = tkts[0];
        }

        Test.startTest();
        ApexPages.StandardController sc = new ApexPages.StandardController(tkt1);
        PrintableTicketExtension ext = new PrintableTicketExtension(sc);
        Test.stopTest();

        System.assertEquals(true, ext.isGroupBooking, 'Should be flagged as a group booking.');
        System.assertEquals(2, ext.totalAttendeeCount, 'Should have 2 attendees.');
        System.assertEquals(500, ext.totalGroupPrice, 'Total price should be 500.');
    }

    @IsTest
    static void testNullTicketIdHandledGracefully() {
        Test.startTest();
        PrintableTicketExtension ext = new PrintableTicketExtension();
        Test.stopTest();

        System.assertEquals(null, ext.primaryTicket.Id, 'Primary ticket should be empty for null id.');
        System.assertEquals(false, ext.hasSpeakers, 'hasSpeakers should be false.');
        System.assertEquals(false, ext.isCancelled, 'isCancelled should be false.');
    }

    @IsTest
    static void testCancelledTicket_SetsCancelledFlag() {
        Venue__c venue = createVenue();
        Event__c event = createEvent(venue.Id);
        Ticket_Type__c tt = createTicketType(event.Id);
        Attendee__c att = createAttendee('Cancel Tester', 'canceltester@example.com');

        Registration__c reg = new Registration__c(
            Event__c = event.Id,
            Ticket_Type__c = tt.Id,
            Attendee__c = att.Id,
            Booked_Price__c = 250,
            Registration_Status__c = 'Cancelled'
        );
        insert reg;

        Ticket__c tkt = new Ticket__c(Registration__c = reg.Id, Ticket_Status__c = 'Cancelled');
        insert tkt;

        Test.startTest();
        ApexPages.currentPage().getParameters().put('id', tkt.Id);
        PrintableTicketExtension ext = new PrintableTicketExtension();
        Test.stopTest();

        System.assertEquals(true, ext.isCancelled, 'Cancelled ticket should set isCancelled to true.');
    }
}
