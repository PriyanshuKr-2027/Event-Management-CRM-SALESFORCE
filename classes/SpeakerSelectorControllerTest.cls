@IsTest
private class SpeakerSelectorControllerTest {

    // ── Test helper methods ────────────────────────────────────────────

    private static Venue__c createVenue(Decimal capacity) {
        Venue__c v = new Venue__c(
            Name = 'Test Venue',
            City__c = 'San Francisco',
            Venue_Capacity__c = capacity,
            Status__c = 'Active'
        );
        insert v;
        return v;
    }

    private static Event__c createEvent(Id venueId, Datetime startDt, Datetime endDt) {
        Event__c e = new Event__c(
            Name = 'Test Event ' + String.valueOf(Datetime.now().getTime()),
            Start_Date_Time__c = startDt,
            End_Date_Time__c = endDt,
            Venue__c = venueId
        );
        insert e;
        return e;
    }

    private static Speaker__c createSpeaker(String name, String email, String org, String expertise) {
        Speaker__c s = new Speaker__c(
            Name = name,
            Email__c = email,
            Organization__c = org,
            Expertise__c = expertise,
            Status__c = 'Active'
        );
        insert s;
        return s;
    }

    // ── Tests ──────────────────────────────────────────────────────────

    @IsTest
    static void testSearchSpeakers_ReturnsResults() {
        Venue__c venue = createVenue(100);
        Event__c evt = createEvent(venue.Id, Datetime.now().addDays(10), Datetime.now().addDays(12));
        Speaker__c speaker = createSpeaker('Alice Johnson', 'alice@test.com', 'Acme Corp', 'Cloud Computing');

        Test.startTest();
        List<SpeakerSelectorController.SpeakerSearchResult> results =
            SpeakerSelectorController.searchSpeakers('Alice', evt.Id);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should find one speaker matching "Alice"');
        System.assertEquals(speaker.Id, results[0].speakerId, 'Speaker Id should match');
        System.assertEquals('Alice Johnson', results[0].name, 'Name should match');
        System.assertEquals(false, results[0].isAlreadyAssigned, 'Should not be already assigned');
        System.assertEquals(false, results[0].isUnavailable, 'Should be available');
    }

    @IsTest
    static void testSearchSpeakers_BlankTerm() {
        Venue__c venue = createVenue(100);
        Event__c evt = createEvent(venue.Id, Datetime.now().addDays(10), Datetime.now().addDays(12));
        createSpeaker('Bob Smith', 'bob@test.com', 'Tech Inc', 'Java');

        Test.startTest();
        List<SpeakerSelectorController.SpeakerSearchResult> results =
            SpeakerSelectorController.searchSpeakers('', evt.Id);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Blank search should return empty list');
    }

    @IsTest
    static void testSearchSpeakers_MarksAlreadyAssigned() {
        Venue__c venue = createVenue(100);
        Event__c evt = createEvent(venue.Id, Datetime.now().addDays(10), Datetime.now().addDays(12));
        Speaker__c speaker = createSpeaker('Carol Davis', 'carol@test.com', 'DataCo', 'AI');

        // Assign speaker to the event
        insert new Event_Speaker__c(
            Event__c = evt.Id,
            Speaker__c = speaker.Id,
            Role__c = 'Panelist',
            Display_Order__c = 1
        );

        Test.startTest();
        List<SpeakerSelectorController.SpeakerSearchResult> results =
            SpeakerSelectorController.searchSpeakers('Carol', evt.Id);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should find one speaker');
        System.assertEquals(true, results[0].isAlreadyAssigned, 'Should be marked as already assigned');
    }

    @IsTest
    static void testSearchSpeakers_MarksUnavailable() {
        Venue__c venue = createVenue(100);
        Venue__c venue2 = createVenue(100);

        // Target event: Jan 10-12
        Datetime targetStart = Datetime.newInstance(2030, 1, 10, 9, 0, 0);
        Datetime targetEnd = Datetime.newInstance(2030, 1, 12, 17, 0, 0);
        Event__c targetEvent = createEvent(venue.Id, targetStart, targetEnd);

        // Conflicting event: Jan 11-13 (overlaps)
        Datetime conflictStart = Datetime.newInstance(2030, 1, 11, 9, 0, 0);
        Datetime conflictEnd = Datetime.newInstance(2030, 1, 13, 17, 0, 0);
        Event__c conflictEvent = new Event__c(
            Name = 'Tech Summit',
            Start_Date_Time__c = conflictStart,
            End_Date_Time__c = conflictEnd,
            Venue__c = venue2.Id
        );
        insert conflictEvent;

        Speaker__c speaker = createSpeaker('Dave Wilson', 'dave@test.com', 'StartupXYZ', 'DevOps');

        // Assign speaker to overlapping event
        insert new Event_Speaker__c(
            Event__c = conflictEvent.Id,
            Speaker__c = speaker.Id,
            Role__c = 'Keynote',
            Display_Order__c = 1
        );

        Test.startTest();
        List<SpeakerSelectorController.SpeakerSearchResult> results =
            SpeakerSelectorController.searchSpeakers('Dave', targetEvent.Id);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should find one speaker');
        System.assertEquals(true, results[0].isUnavailable, 'Should be marked as unavailable');
        System.assert(
            results[0].conflictReason != null && results[0].conflictReason.contains('Tech Summit'),
            'Conflict reason should mention the conflicting event name'
        );
    }

    @IsTest
    static void testAssignAndRemoveSpeaker() {
        Venue__c venue = createVenue(100);
        Event__c evt = createEvent(venue.Id, Datetime.now().addDays(10), Datetime.now().addDays(12));
        Speaker__c speaker = createSpeaker('Eve Green', 'eve@test.com', 'NetCorp', 'Security');

        Test.startTest();

        // Assign
        SpeakerSelectorController.assignSpeaker(evt.Id, speaker.Id, 'Workshop Lead', 'Intro to Security');

        List<Event_Speaker__c> junctions = [
            SELECT Id, Role__c, Session_Title__c, Display_Order__c
            FROM Event_Speaker__c
            WHERE Event__c = :evt.Id AND Speaker__c = :speaker.Id
        ];
        System.assertEquals(1, junctions.size(), 'Should have one junction record');
        System.assertEquals('Workshop Lead', junctions[0].Role__c, 'Role should match');
        System.assertEquals('Intro to Security', junctions[0].Session_Title__c, 'Session title should match');
        System.assertEquals(1, junctions[0].Display_Order__c, 'Display order should be 1');

        // Remove
        SpeakerSelectorController.removeSpeaker(junctions[0].Id);

        Test.stopTest();

        List<Event_Speaker__c> remaining = [
            SELECT Id FROM Event_Speaker__c WHERE Event__c = :evt.Id AND Speaker__c = :speaker.Id
        ];
        System.assertEquals(0, remaining.size(), 'Junction should be deleted');
    }

    @IsTest
    static void testGetAssignedSpeakers_OrderedByDisplayOrder() {
        Venue__c venue = createVenue(100);
        Event__c evt = createEvent(venue.Id, Datetime.now().addDays(10), Datetime.now().addDays(12));

        Speaker__c s1 = createSpeaker('Speaker A', 'a@test.com', 'OrgA', 'Topic A');
        Speaker__c s2 = createSpeaker('Speaker B', 'b@test.com', 'OrgB', 'Topic B');
        Speaker__c s3 = createSpeaker('Speaker C', 'c@test.com', 'OrgC', 'Topic C');

        // Insert with non-sequential display orders
        insert new List<Event_Speaker__c>{
            new Event_Speaker__c(Event__c = evt.Id, Speaker__c = s1.Id, Role__c = 'Keynote', Display_Order__c = 3),
            new Event_Speaker__c(Event__c = evt.Id, Speaker__c = s2.Id, Role__c = 'Panelist', Display_Order__c = 1),
            new Event_Speaker__c(Event__c = evt.Id, Speaker__c = s3.Id, Role__c = 'Guest Speaker', Display_Order__c = 2)
        };

        Test.startTest();
        List<SpeakerSelectorController.AssignedSpeakerDTO> assigned =
            SpeakerSelectorController.getAssignedSpeakers(evt.Id);
        Test.stopTest();

        System.assertEquals(3, assigned.size(), 'Should return 3 assigned speakers');
        System.assertEquals(1, assigned[0].displayOrder, 'First should have display order 1');
        System.assertEquals(2, assigned[1].displayOrder, 'Second should have display order 2');
        System.assertEquals(3, assigned[2].displayOrder, 'Third should have display order 3');
        System.assertEquals('Speaker B', assigned[0].speakerName, 'First should be Speaker B (order 1)');
        System.assertEquals('Speaker C', assigned[1].speakerName, 'Second should be Speaker C (order 2)');
        System.assertEquals('Speaker A', assigned[2].speakerName, 'Third should be Speaker A (order 3)');
    }

    @IsTest
    static void testUpdateSpeakerAssignment() {
        Venue__c venue = createVenue(100);
        Event__c evt = createEvent(venue.Id, Datetime.now().addDays(10), Datetime.now().addDays(12));
        Speaker__c speaker = createSpeaker('Frank Hall', 'frank@test.com', 'BigTech', 'ML');

        Event_Speaker__c es = new Event_Speaker__c(
            Event__c = evt.Id,
            Speaker__c = speaker.Id,
            Role__c = 'Guest Speaker',
            Session_Title__c = 'Old Title',
            Display_Order__c = 1
        );
        insert es;

        Test.startTest();
        SpeakerSelectorController.updateSpeakerAssignment(es.Id, 'Keynote', 'New Title', 5);
        Test.stopTest();

        Event_Speaker__c updated = [
            SELECT Role__c, Session_Title__c, Display_Order__c
            FROM Event_Speaker__c
            WHERE Id = :es.Id
        ];
        System.assertEquals('Keynote', updated.Role__c, 'Role should be updated');
        System.assertEquals('New Title', updated.Session_Title__c, 'Session title should be updated');
        System.assertEquals(5, updated.Display_Order__c, 'Display order should be updated');
    }
}
