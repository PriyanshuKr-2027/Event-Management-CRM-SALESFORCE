/**
 * @description Test class for EventSpeakerTriggerHandler.
 *              Validates speaker double-booking prevention logic.
 */
@isTest
private class EventSpeakerTriggerHandlerTest {

    // ─── Helper Methods ──────────────────────────────────────────────

    /**
     * @description Creates and inserts a Venue__c record.
     */
    private static Venue__c createVenue(Integer capacity) {
        Venue__c venue = new Venue__c(
            Name           = 'Test Venue ' + capacity,
            City__c        = 'Test City',
            Venue_Capacity__c = capacity,
            Status__c      = 'Active'
        );
        insert venue;
        return venue;
    }

    /**
     * @description Creates and inserts an Event__c record tied to the given Venue.
     */
    private static Event__c createEvent(Id venueId, DateTime startDt, DateTime endDt) {
        Event__c evt = new Event__c(
            Name                  = 'Test Event ' + startDt.format(),
            Category__c           = 'Conference',
            Venue__c              = venueId,
            Organizer__c          = UserInfo.getUserId(),
            Proposed_Budget__c    = 1000,
            Approval_Status__c    = 'Approved',
            Publication_Status__c = 'Unpublished',
            Registration_Status__c = 'Open',
            Start_Date_Time__c    = startDt,
            End_Date_Time__c      = endDt
        );
        insert evt;
        return evt;
    }

    /**
     * @description Creates and inserts a Speaker__c record.
     */
    private static Speaker__c createSpeaker(String name, String email) {
        Speaker__c speaker = new Speaker__c(
            Name     = name,
            Email__c = email,
            Status__c = 'Active'
        );
        insert speaker;
        return speaker;
    }

    // ─── Test Methods ────────────────────────────────────────────────

    /**
     * @description Assign speaker to event A (Jan 1-3), then try to assign same
     *              speaker to event B (Jan 2-4). Should fail with overlap error.
     */
    @isTest
    static void testSameSpeakerOverlappingDates_Blocked() {
        Venue__c venueA = createVenue(100);
        Venue__c venueB = createVenue(100);
        Event__c eventA = createEvent(
            venueA.Id,
            DateTime.newInstance(2026, 1, 1, 9, 0, 0),
            DateTime.newInstance(2026, 1, 3, 17, 0, 0)
        );
        Event__c eventB = createEvent(
            venueB.Id,
            DateTime.newInstance(2026, 1, 2, 9, 0, 0),
            DateTime.newInstance(2026, 1, 4, 17, 0, 0)
        );
        Speaker__c speaker = createSpeaker('Jane Doe', 'jane.doe@test.com');

        // First assignment — should succeed
        Event_Speaker__c assignA = new Event_Speaker__c(
            Event__c   = eventA.Id,
            Speaker__c = speaker.Id,
            Role__c    = 'Keynote'
        );
        insert assignA;

        // Second assignment — overlapping dates, should fail
        Event_Speaker__c assignB = new Event_Speaker__c(
            Event__c   = eventB.Id,
            Speaker__c = speaker.Id,
            Role__c    = 'Panelist'
        );

        Test.startTest();
        try {
            insert assignB;
            Assert.fail('Expected DmlException for overlapping speaker assignment');
        } catch (DmlException ex) {
            Assert.isTrue(
                ex.getMessage().contains('Speaker is already assigned to'),
                'Error message should mention existing assignment. Actual: ' + ex.getMessage()
            );
        }
        Test.stopTest();
    }

    /**
     * @description Assign speaker to event A (Jan 1-3), then assign same speaker
     *              to event B (Jan 5-7). Should succeed — no overlap.
     */
    @isTest
    static void testSameSpeakerNonOverlappingDates_Allowed() {
        Venue__c venue = createVenue(100);
        Event__c eventA = createEvent(
            venue.Id,
            DateTime.newInstance(2026, 1, 1, 9, 0, 0),
            DateTime.newInstance(2026, 1, 3, 17, 0, 0)
        );
        Event__c eventB = createEvent(
            venue.Id,
            DateTime.newInstance(2026, 1, 5, 9, 0, 0),
            DateTime.newInstance(2026, 1, 7, 17, 0, 0)
        );
        Speaker__c speaker = createSpeaker('John Smith', 'john.smith@test.com');

        insert new Event_Speaker__c(
            Event__c   = eventA.Id,
            Speaker__c = speaker.Id,
            Role__c    = 'Keynote'
        );

        Test.startTest();
        Event_Speaker__c assignB = new Event_Speaker__c(
            Event__c   = eventB.Id,
            Speaker__c = speaker.Id,
            Role__c    = 'Panelist'
        );
        insert assignB;
        Test.stopTest();

        Assert.isNotNull(assignB.Id, 'Non-overlapping assignment should succeed');
    }

    /**
     * @description Two different speakers assigned to the same event.
     *              Should succeed — different speakers cannot conflict.
     */
    @isTest
    static void testDifferentSpeakersSameDates_Allowed() {
        Venue__c venue = createVenue(200);
        Event__c evt = createEvent(
            venue.Id,
            DateTime.newInstance(2026, 2, 1, 9, 0, 0),
            DateTime.newInstance(2026, 2, 3, 17, 0, 0)
        );
        Speaker__c speakerA = createSpeaker('Alice', 'alice@test.com');
        Speaker__c speakerB = createSpeaker('Bob', 'bob@test.com');

        Test.startTest();
        List<Event_Speaker__c> assignments = new List<Event_Speaker__c>{
            new Event_Speaker__c(Event__c = evt.Id, Speaker__c = speakerA.Id, Role__c = 'Keynote'),
            new Event_Speaker__c(Event__c = evt.Id, Speaker__c = speakerB.Id, Role__c = 'Panelist')
        };
        insert assignments;
        Test.stopTest();

        Assert.areEqual(2, [SELECT COUNT() FROM Event_Speaker__c WHERE Event__c = :evt.Id],
            'Both assignments for different speakers should succeed');
    }

    /**
     * @description Bulk insert 3 assignments — 2 valid, 1 overlapping.
     *              Uses Database.insert with allOrNone = false for partial failure.
     */
    @isTest
    static void testBulkAssignments_Mixed() {
        Venue__c venue = createVenue(300);
        Venue__c venueB = createVenue(300);

        Event__c eventA = createEvent(
            venue.Id,
            DateTime.newInstance(2026, 3, 1, 9, 0, 0),
            DateTime.newInstance(2026, 3, 3, 17, 0, 0)
        );
        Event__c eventB = createEvent(
            venueB.Id,
            DateTime.newInstance(2026, 3, 2, 9, 0, 0),
            DateTime.newInstance(2026, 3, 4, 17, 0, 0)
        );
        Event__c eventC = createEvent(
            venue.Id,
            DateTime.newInstance(2026, 3, 10, 9, 0, 0),
            DateTime.newInstance(2026, 3, 12, 17, 0, 0)
        );

        Speaker__c speakerX = createSpeaker('Speaker X', 'speakerx@test.com');
        Speaker__c speakerY = createSpeaker('Speaker Y', 'speakery@test.com');

        // Pre-assign speakerX to eventA
        insert new Event_Speaker__c(
            Event__c   = eventA.Id,
            Speaker__c = speakerX.Id,
            Role__c    = 'Keynote'
        );

        // Bulk insert: 3 assignments
        List<Event_Speaker__c> bulkRecords = new List<Event_Speaker__c>{
            // Valid: speakerY to eventA (different speaker, no conflict)
            new Event_Speaker__c(Event__c = eventA.Id, Speaker__c = speakerY.Id, Role__c = 'Panelist'),
            // Invalid: speakerX to eventB (overlaps with eventA assignment)
            new Event_Speaker__c(Event__c = eventB.Id, Speaker__c = speakerX.Id, Role__c = 'Panelist'),
            // Valid: speakerX to eventC (no date overlap with eventA)
            new Event_Speaker__c(Event__c = eventC.Id, Speaker__c = speakerX.Id, Role__c = 'Keynote')
        };

        Test.startTest();
        List<Database.SaveResult> results = Database.insert(bulkRecords, false);
        Test.stopTest();

        // First record: valid
        Assert.isTrue(results[0].isSuccess(), 'SpeakerY → EventA should succeed');
        // Second record: overlap
        Assert.isFalse(results[1].isSuccess(), 'SpeakerX → EventB should fail (overlaps EventA)');
        Assert.isTrue(
            results[1].getErrors()[0].getMessage().contains('Speaker is already assigned to'),
            'Error should mention existing assignment'
        );
        // Third record: valid
        Assert.isTrue(results[2].isSuccess(), 'SpeakerX → EventC should succeed (no overlap)');
    }
}
