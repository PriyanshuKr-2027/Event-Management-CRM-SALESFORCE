@IsTest
private class RegistrationTriggerHandlerTest {

    private static Venue__c createVenue(Decimal capacity) {
        Venue__c v = new Venue__c(
            Name = 'Test Venue',
            City__c = 'Test City',
            Venue_Capacity__c = capacity,
            Status__c = 'Active'
        );
        insert v;
        return v;
    }

    private static Event__c createEvent(Id venueId, String regStatus) {
        Event__c ev = new Event__c(
            Name = 'Test Event',
            Category__c = 'Conference',
            Start_Date_Time__c = Datetime.now().addDays(10),
            End_Date_Time__c = Datetime.now().addDays(10).addHours(3),
            Venue__c = venueId,
            Organizer__c = UserInfo.getUserId(),
            Proposed_Budget__c = 1000,
            Approval_Status__c = 'Approved',
            Publication_Status__c = 'Published',
            Registration_Status__c = regStatus
        );
        insert ev;
        return ev;
    }

    private static Ticket_Type__c createTicketType(Id eventId, Decimal quota, Decimal bookedSeats, String status) {
        Ticket_Type__c tt = new Ticket_Type__c(
            Name = 'General Admission',
            Event__c = eventId,
            Price__c = 100,
            Quota__c = quota,
            Booked_Seats__c = bookedSeats,
            Status__c = status
        );
        insert tt;
        return tt;
    }

    private static Attendee__c createAttendee() {
        Attendee__c att = new Attendee__c(
            Name = 'Test Attendee',
            Email__c = 'attendee' + Crypto.getRandomInteger() + '@example.com',
            Attendee_Status__c = 'Active'
        );
        insert att;
        return att;
    }

    private static Registration__c createRegistration(Id eventId, Id ticketTypeId, String status) {
        Attendee__c att = createAttendee();
        return new Registration__c(
            Event__c = eventId,
            Ticket_Type__c = ticketTypeId,
            Attendee__c = att.Id,
            Registration_Status__c = status,
            Booked_Price__c = 100
        );
    }

    // =====================================================
    // BEFORE INSERT TESTS (existing — unchanged)
    // =====================================================

    @IsTest
    static void testHappyPathWithinQuota_Succeeds() {
        Venue__c venue = createVenue(100);
        Event__c ev = createEvent(venue.Id, 'Open');
        Ticket_Type__c tt = createTicketType(ev.Id, 10, 2, 'Available');

        Registration__c reg = createRegistration(ev.Id, tt.Id, 'Pending');

        Test.startTest();
        insert reg;
        Test.stopTest();

        System.assertNotEquals(null, reg.Id, 'Registration within quota should insert successfully.');

        Ticket_Type__c updatedTT = [SELECT Booked_Seats__c, Status__c FROM Ticket_Type__c WHERE Id = :tt.Id];
        System.assertEquals(3, updatedTT.Booked_Seats__c, 'Booked_Seats__c should increment by 1.');
        System.assertEquals('Available', updatedTT.Status__c, 'Status should remain Available when quota is not reached.');
    }

    @IsTest
    static void testExactAtQuotaBoundary_SucceedsAndMarksSoldOut() {
        Venue__c venue = createVenue(100);
        Event__c ev = createEvent(venue.Id, 'Open');
        Ticket_Type__c tt = createTicketType(ev.Id, 5, 4, 'Available'); // 1 seat remaining

        Registration__c reg = createRegistration(ev.Id, tt.Id, 'Pending');

        Test.startTest();
        insert reg;
        Test.stopTest();

        System.assertNotEquals(null, reg.Id, 'Booking the last seat should succeed.');

        Ticket_Type__c updatedTT = [SELECT Booked_Seats__c, Status__c FROM Ticket_Type__c WHERE Id = :tt.Id];
        System.assertEquals(5, updatedTT.Booked_Seats__c, 'Booked seats should equal quota.');
        System.assertEquals('Sold Out', updatedTT.Status__c, 'Status should flip to Sold Out when booked seats reaches quota.');
    }

    @IsTest
    static void testQuotaExceeded_Fails() {
        Venue__c venue = createVenue(100);
        Event__c ev = createEvent(venue.Id, 'Open');
        Ticket_Type__c tt = createTicketType(ev.Id, 5, 5, 'Available'); // Already at quota

        Registration__c reg = createRegistration(ev.Id, tt.Id, 'Pending');

        Test.startTest();
        Boolean dmlFailed = false;
        try {
            insert reg;
        } catch (DmlException e) {
            dmlFailed = true;
            System.assert(
                e.getMessage().contains('sold out'),
                'Error message should indicate ticket type is sold out.'
            );
        }
        Test.stopTest();

        System.assert(dmlFailed, 'Registration exceeding quota should fail.');
    }

    @IsTest
    static void testWrongEventTicketType_Fails() {
        Venue__c venue = createVenue(100);
        Venue__c venue2 = createVenue(100);
        Event__c ev1 = createEvent(venue.Id, 'Open');
        Event__c ev2 = createEvent(venue2.Id, 'Open');
        Ticket_Type__c tt1 = createTicketType(ev1.Id, 50, 0, 'Available');

        // Registration points to ev2 but uses Ticket Type from ev1
        Registration__c reg = createRegistration(ev2.Id, tt1.Id, 'Pending');

        Test.startTest();
        Boolean dmlFailed = false;
        try {
            insert reg;
        } catch (DmlException e) {
            dmlFailed = true;
            System.assert(
                e.getMessage().contains('does not belong to the selected event'),
                'Error message should flag event mismatch.'
            );
        }
        Test.stopTest();

        System.assert(dmlFailed, 'Registration with mismatched event and ticket type should fail.');
    }

    @IsTest
    static void testClosedRegistrationEvent_Fails() {
        Venue__c venue = createVenue(100);
        Event__c ev = createEvent(venue.Id, 'Closed');
        Ticket_Type__c tt = createTicketType(ev.Id, 50, 0, 'Available');

        Registration__c reg = createRegistration(ev.Id, tt.Id, 'Pending');

        Test.startTest();
        Boolean dmlFailed = false;
        try {
            insert reg;
        } catch (DmlException e) {
            dmlFailed = true;
            System.assert(
                e.getMessage().contains('not currently open for registration'),
                'Error message should indicate registration is not open.'
            );
        }
        Test.stopTest();

        System.assert(dmlFailed, 'Registration against a closed event should fail.');
    }

    @IsTest
    static void testSoldOutTicketTypeStatus_Fails() {
        Venue__c venue = createVenue(100);
        Event__c ev = createEvent(venue.Id, 'Open');
        Ticket_Type__c tt = createTicketType(ev.Id, 50, 10, 'Sold Out');

        Registration__c reg = createRegistration(ev.Id, tt.Id, 'Pending');

        Test.startTest();
        Boolean dmlFailed = false;
        try {
            insert reg;
        } catch (DmlException e) {
            dmlFailed = true;
            System.assert(
                e.getMessage().contains('no longer available'),
                'Error message should indicate ticket type is no longer available.'
            );
        }
        Test.stopTest();

        System.assert(dmlFailed, 'Registration against a Sold Out ticket type should fail.');
    }

    @IsTest
    static void testClosedTicketTypeStatus_Fails() {
        Venue__c venue = createVenue(100);
        Event__c ev = createEvent(venue.Id, 'Open');
        Ticket_Type__c tt = createTicketType(ev.Id, 50, 10, 'Closed');

        Registration__c reg = createRegistration(ev.Id, tt.Id, 'Pending');

        Test.startTest();
        Boolean dmlFailed = false;
        try {
            insert reg;
        } catch (DmlException e) {
            dmlFailed = true;
            System.assert(
                e.getMessage().contains('no longer available'),
                'Error message should indicate ticket type is no longer available.'
            );
        }
        Test.stopTest();

        System.assert(dmlFailed, 'Registration against a Closed ticket type should fail.');
    }

    @IsTest
    static void testBulkRegistrationsAgainstSameTicketType_Succeeds() {
        Venue__c venue = createVenue(100);
        Event__c ev = createEvent(venue.Id, 'Open');
        Ticket_Type__c tt = createTicketType(ev.Id, 10, 0, 'Available');

        List<Registration__c> batch = new List<Registration__c>();
        for (Integer i = 0; i < 5; i++) {
            batch.add(createRegistration(ev.Id, tt.Id, 'Pending'));
        }

        Test.startTest();
        insert batch;
        Test.stopTest();

        Ticket_Type__c updatedTT = [SELECT Booked_Seats__c, Status__c FROM Ticket_Type__c WHERE Id = :tt.Id];
        System.assertEquals(5, updatedTT.Booked_Seats__c, 'Booked seats should reflect all 5 batch registrations.');
        System.assertEquals('Available', updatedTT.Status__c, 'Status should remain Available when quota (10) is not reached.');
    }

    @IsTest
    static void testBulkRegistrationsExceedingQuota_Fails() {
        Venue__c venue = createVenue(100);
        Event__c ev = createEvent(venue.Id, 'Open');
        Ticket_Type__c tt = createTicketType(ev.Id, 2, 0, 'Available');

        List<Registration__c> batch = new List<Registration__c>{
            createRegistration(ev.Id, tt.Id, 'Pending'),
            createRegistration(ev.Id, tt.Id, 'Pending'),
            createRegistration(ev.Id, tt.Id, 'Pending')
        }; // 3 registrations against quota of 2

        Test.startTest();
        Boolean dmlFailed = false;
        try {
            insert batch;
        } catch (DmlException e) {
            dmlFailed = true;
        }
        Test.stopTest();

        System.assert(dmlFailed, 'Bulk insert exceeding available quota should fail.');
    }

    @IsTest
    static void testRegistrationWithoutTicketType_HandledSafely() {
        Registration__c reg = new Registration__c(
            Registration_Status__c = 'Pending',
            Booked_Price__c = 100
        );

        Test.startTest();
        RegistrationTriggerHandler.beforeInsert(new List<Registration__c>{ reg });
        Test.stopTest();

        System.assertEquals(null, reg.Ticket_Type__c, 'Registration without ticket type should safely bypass inventory check.');
    }

    // =====================================================
    // AFTER UPDATE TESTS — Seat Release on Cancellation
    // =====================================================

    @IsTest
    static void testCancelRegistration_ReleasesSeats() {
        Venue__c venue = createVenue(100);
        Event__c ev = createEvent(venue.Id, 'Open');
        Ticket_Type__c tt = createTicketType(ev.Id, 10, 0, 'Available');

        Registration__c reg = createRegistration(ev.Id, tt.Id, 'Pending');
        insert reg;

        // Verify seat was consumed
        Ticket_Type__c afterInsert = [SELECT Booked_Seats__c FROM Ticket_Type__c WHERE Id = :tt.Id];
        System.assertEquals(1, afterInsert.Booked_Seats__c, 'Should have 1 booked seat after insert.');

        Test.startTest();
        reg.Registration_Status__c = 'Cancelled';
        update reg;
        Test.stopTest();

        Ticket_Type__c afterCancel = [SELECT Booked_Seats__c, Status__c FROM Ticket_Type__c WHERE Id = :tt.Id];
        System.assertEquals(0, afterCancel.Booked_Seats__c, 'Booked seats should decrement after cancellation.');
        System.assertEquals('Available', afterCancel.Status__c, 'Status should remain Available.');
    }

    @IsTest
    static void testCancelWhenSoldOut_ReopensTicketType() {
        Venue__c venue = createVenue(100);
        Event__c ev = createEvent(venue.Id, 'Open');
        Ticket_Type__c tt = createTicketType(ev.Id, 2, 0, 'Available');

        // Book both seats to trigger Sold Out
        Registration__c reg1 = createRegistration(ev.Id, tt.Id, 'Pending');
        Registration__c reg2 = createRegistration(ev.Id, tt.Id, 'Pending');
        insert new List<Registration__c>{ reg1, reg2 };

        Ticket_Type__c afterFull = [SELECT Booked_Seats__c, Status__c FROM Ticket_Type__c WHERE Id = :tt.Id];
        System.assertEquals(2, afterFull.Booked_Seats__c, 'Should be fully booked.');
        System.assertEquals('Sold Out', afterFull.Status__c, 'Should be Sold Out.');

        Test.startTest();
        reg1.Registration_Status__c = 'Cancelled';
        update reg1;
        Test.stopTest();

        Ticket_Type__c afterCancel = [SELECT Booked_Seats__c, Status__c FROM Ticket_Type__c WHERE Id = :tt.Id];
        System.assertEquals(1, afterCancel.Booked_Seats__c, 'Should release one seat.');
        System.assertEquals('Available', afterCancel.Status__c, 'Should reopen from Sold Out to Available.');
    }

    @IsTest
    static void testBulkCancellation_ReleasesAllSeats() {
        Venue__c venue = createVenue(100);
        Event__c ev = createEvent(venue.Id, 'Open');
        Ticket_Type__c tt = createTicketType(ev.Id, 10, 0, 'Available');

        List<Registration__c> batch = new List<Registration__c>();
        for (Integer i = 0; i < 5; i++) {
            batch.add(createRegistration(ev.Id, tt.Id, 'Pending'));
        }
        insert batch;

        Ticket_Type__c afterInsert = [SELECT Booked_Seats__c FROM Ticket_Type__c WHERE Id = :tt.Id];
        System.assertEquals(5, afterInsert.Booked_Seats__c, 'Should have 5 booked seats.');

        Test.startTest();
        for (Registration__c r : batch) {
            r.Registration_Status__c = 'Cancelled';
        }
        update batch;
        Test.stopTest();

        Ticket_Type__c afterCancel = [SELECT Booked_Seats__c, Status__c FROM Ticket_Type__c WHERE Id = :tt.Id];
        System.assertEquals(0, afterCancel.Booked_Seats__c, 'All 5 seats should be released.');
        System.assertEquals('Available', afterCancel.Status__c, 'Status should be Available.');
    }

    @IsTest
    static void testStatusChangeNotCancellation_NoSeatRelease() {
        Venue__c venue = createVenue(100);
        Event__c ev = createEvent(venue.Id, 'Open');
        Ticket_Type__c tt = createTicketType(ev.Id, 10, 0, 'Available');

        Registration__c reg = createRegistration(ev.Id, tt.Id, 'Pending');
        insert reg;

        Test.startTest();
        // Change to Confirmed — should NOT release seats
        reg.Registration_Status__c = 'Confirmed';
        update reg;
        Test.stopTest();

        Ticket_Type__c afterUpdate = [SELECT Booked_Seats__c FROM Ticket_Type__c WHERE Id = :tt.Id];
        System.assertEquals(1, afterUpdate.Booked_Seats__c, 'Non-cancellation status change should not release seats.');
    }

    // =====================================================
    // AFTER DELETE TESTS — Seat Release on Deletion
    // =====================================================

    @IsTest
    static void testDeleteRegistration_ReleasesSeats() {
        Venue__c venue = createVenue(100);
        Event__c ev = createEvent(venue.Id, 'Open');
        Ticket_Type__c tt = createTicketType(ev.Id, 10, 0, 'Available');

        Registration__c reg = createRegistration(ev.Id, tt.Id, 'Pending');
        insert reg;

        Test.startTest();
        delete reg;
        Test.stopTest();

        Ticket_Type__c afterDelete = [SELECT Booked_Seats__c FROM Ticket_Type__c WHERE Id = :tt.Id];
        System.assertEquals(0, afterDelete.Booked_Seats__c, 'Deleting a registration should release the seat.');
    }

    @IsTest
    static void testDeleteCancelledRegistration_NoDoubleDec() {
        Venue__c venue = createVenue(100);
        Event__c ev = createEvent(venue.Id, 'Open');
        Ticket_Type__c tt = createTicketType(ev.Id, 10, 0, 'Available');

        Registration__c reg = createRegistration(ev.Id, tt.Id, 'Pending');
        insert reg;

        // Cancel first (releases seat)
        reg.Registration_Status__c = 'Cancelled';
        update reg;

        Ticket_Type__c afterCancel = [SELECT Booked_Seats__c FROM Ticket_Type__c WHERE Id = :tt.Id];
        System.assertEquals(0, afterCancel.Booked_Seats__c, 'Cancel should release seat.');

        Test.startTest();
        // Now delete the already-cancelled registration — should NOT double-decrement
        delete reg;
        Test.stopTest();

        Ticket_Type__c afterDelete = [SELECT Booked_Seats__c FROM Ticket_Type__c WHERE Id = :tt.Id];
        System.assertEquals(0, afterDelete.Booked_Seats__c, 'Deleting a cancelled registration should not double-release seats.');
    }

    // =====================================================
    // VALIDATION RULE TESTS — Ticket Type Locking
    // =====================================================

    @IsTest
    static void testCannotChangeTicketTypeWhenConfirmed() {
        Venue__c venue = createVenue(100);
        Event__c ev = createEvent(venue.Id, 'Open');
        Ticket_Type__c tt1 = createTicketType(ev.Id, 10, 0, 'Available');
        Ticket_Type__c tt2 = createTicketType(ev.Id, 10, 0, 'Available');

        Registration__c reg = createRegistration(ev.Id, tt1.Id, 'Confirmed');
        insert reg;

        reg.Ticket_Type__c = tt2.Id;

        Test.startTest();
        Boolean validationFailed = false;
        try {
            update reg;
        } catch (DmlException e) {
            validationFailed = true;
            System.assert(e.getMessage().contains('Ticket Type cannot be changed directly on a confirmed or cancelled registration'),
                'Expected lock validation error message but got: ' + e.getMessage());
        }
        Test.stopTest();

        System.assert(validationFailed, 'Updating Ticket_Type__c on a Confirmed registration should fail validation.');
    }

    @IsTest
    static void testCannotChangeTicketTypeWhenCancelled() {
        Venue__c venue = createVenue(100);
        Event__c ev = createEvent(venue.Id, 'Open');
        Ticket_Type__c tt1 = createTicketType(ev.Id, 10, 0, 'Available');
        Ticket_Type__c tt2 = createTicketType(ev.Id, 10, 0, 'Available');

        Registration__c reg = createRegistration(ev.Id, tt1.Id, 'Cancelled');
        insert reg;

        reg.Ticket_Type__c = tt2.Id;

        Test.startTest();
        Boolean validationFailed = false;
        try {
            update reg;
        } catch (DmlException e) {
            validationFailed = true;
            System.assert(e.getMessage().contains('Ticket Type cannot be changed directly on a confirmed or cancelled registration'),
                'Expected lock validation error message but got: ' + e.getMessage());
        }
        Test.stopTest();

        System.assert(validationFailed, 'Updating Ticket_Type__c on a Cancelled registration should fail validation.');
    }

    @IsTest
    static void testCancelRegistrationVoidsChildTickets() {
        Venue__c venue = createVenue(100);
        Event__c ev = createEvent(venue.Id, 'Open');
        Ticket_Type__c tt = createTicketType(ev.Id, 10, 0, 'Available');

        Registration__c reg = createRegistration(ev.Id, tt.Id, 'Confirmed');
        insert reg;

        Ticket__c tkt = new Ticket__c(Registration__c = reg.Id, Ticket_Status__c = 'Active');
        insert tkt;

        Test.startTest();
        reg.Registration_Status__c = 'Cancelled';
        update reg;
        Test.stopTest();

        Ticket__c cancelledTkt = [SELECT Ticket_Status__c FROM Ticket__c WHERE Id = :tkt.Id];
        System.assertEquals('Cancelled', cancelledTkt.Ticket_Status__c, 'Child ticket must be marked Cancelled when registration is cancelled.');
    }

    @IsTest
    static void testCannotChangeBookedPriceAfterInsert() {
        Venue__c venue = createVenue(100);
        Event__c ev = createEvent(venue.Id, 'Open');
        Ticket_Type__c tt = createTicketType(ev.Id, 10, 0, 'Available');

        Registration__c reg = createRegistration(ev.Id, tt.Id, 'Pending');
        insert reg;

        reg.Booked_Price__c = 50;

        Test.startTest();
        Boolean validationFailed = false;
        try {
            update reg;
        } catch (DmlException e) {
            validationFailed = true;
            System.assert(e.getMessage().contains('Booked Price is locked'),
                'Expected Booked Price lock message but got: ' + e.getMessage());
        }
        Test.stopTest();

        System.assert(validationFailed, 'Updating Booked_Price__c on an existing registration should fail validation.');
    }

    @IsTest
    static void testCannotChangeAttendeeOnConfirmedRegistration() {
        Venue__c venue = createVenue(100);
        Event__c ev1 = createEvent(venue.Id, 'Open');
        Ticket_Type__c tt = createTicketType(ev1.Id, 10, 0, 'Available');

        Attendee__c att2 = createAttendee();

        Registration__c reg = createRegistration(ev1.Id, tt.Id, 'Confirmed');
        insert reg;

        reg.Attendee__c = att2.Id;

        Test.startTest();
        Boolean validationFailed = false;
        try {
            update reg;
        } catch (DmlException e) {
            validationFailed = true;
            System.assert(e.getMessage().contains('Attendee cannot be changed'),
                'Expected Attendee lock message but got: ' + e.getMessage());
        }
        Test.stopTest();

        System.assert(validationFailed, 'Changing Attendee__c on a confirmed registration should fail validation.');
    }
}

