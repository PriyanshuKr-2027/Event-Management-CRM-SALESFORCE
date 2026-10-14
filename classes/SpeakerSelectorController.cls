public with sharing class SpeakerSelectorController {

    /**
     * Searches for speakers by name, expertise, or organization.
     * Marks speakers already assigned to the event or unavailable due to scheduling conflicts.
     */
    @AuraEnabled
    public static List<SpeakerSearchResult> searchSpeakers(String searchTerm, Id eventId) {
        List<SpeakerSearchResult> results = new List<SpeakerSearchResult>();

        if (String.isBlank(searchTerm)) {
            return results;
        }

        String likeFilter = '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';

        List<Speaker__c> speakers = [
            SELECT Id, Name, Email__c, Organization__c, Expertise__c, Photo_URL__c, Bio__c
            FROM Speaker__c
            WHERE (Name LIKE :likeFilter
                   OR Expertise__c LIKE :likeFilter
                   OR Organization__c LIKE :likeFilter)
              AND Status__c != 'Inactive'
            LIMIT 20
        ];

        if (speakers.isEmpty()) {
            return results;
        }

        // Collect speaker Ids for sub-queries
        Set<Id> speakerIds = new Set<Id>();
        for (Speaker__c s : speakers) {
            speakerIds.add(s.Id);
        }

        // Find speakers already assigned to this event
        Set<Id> assignedSpeakerIds = new Set<Id>();
        for (Event_Speaker__c es : [
            SELECT Speaker__c
            FROM Event_Speaker__c
            WHERE Event__c = :eventId
              AND Speaker__c IN :speakerIds
        ]) {
            assignedSpeakerIds.add(es.Speaker__c);
        }

        // Get this event's date range for conflict checking
        Event__c thisEvent = [
            SELECT Start_Date_Time__c, End_Date_Time__c
            FROM Event__c
            WHERE Id = :eventId
            LIMIT 1
        ];

        // Find speakers with overlapping event conflicts
        Map<Id, String> conflictReasons = new Map<Id, String>();
        if (thisEvent.Start_Date_Time__c != null && thisEvent.End_Date_Time__c != null) {
            for (Event_Speaker__c es : [
                SELECT Speaker__c, Event__r.Name,
                       Event__r.Start_Date_Time__c, Event__r.End_Date_Time__c
                FROM Event_Speaker__c
                WHERE Speaker__c IN :speakerIds
                  AND Event__c != :eventId
                  AND Event__r.Start_Date_Time__c < :thisEvent.End_Date_Time__c
                  AND Event__r.End_Date_Time__c > :thisEvent.Start_Date_Time__c
            ]) {
                String reason = 'Booked for \'' + es.Event__r.Name + '\' on '
                    + es.Event__r.Start_Date_Time__c.format('MMM d')
                    + ' - ' + es.Event__r.End_Date_Time__c.format('MMM d');
                conflictReasons.put(es.Speaker__c, reason);
            }
        }

        // Build result wrappers
        for (Speaker__c s : speakers) {
            SpeakerSearchResult r = new SpeakerSearchResult();
            r.speakerId = s.Id;
            r.name = s.Name;
            r.email = s.Email__c;
            r.organization = s.Organization__c;
            r.expertise = s.Expertise__c;
            r.photoUrl = s.Photo_URL__c;
            r.bio = s.Bio__c;
            r.isAlreadyAssigned = assignedSpeakerIds.contains(s.Id);
            r.isUnavailable = conflictReasons.containsKey(s.Id);
            r.conflictReason = conflictReasons.get(s.Id);
            results.add(r);
        }

        return results;
    }

    /**
     * Returns all speakers assigned to the given event, ordered by Display_Order__c.
     */
    @AuraEnabled
    public static List<AssignedSpeakerDTO> getAssignedSpeakers(Id eventId) {
        List<AssignedSpeakerDTO> assigned = new List<AssignedSpeakerDTO>();

        for (Event_Speaker__c es : [
            SELECT Id, Speaker__c, Speaker__r.Name, Speaker__r.Email__c,
                   Speaker__r.Organization__c, Speaker__r.Expertise__c,
                   Speaker__r.Photo_URL__c, Role__c, Session_Title__c, Display_Order__c
            FROM Event_Speaker__c
            WHERE Event__c = :eventId
            ORDER BY Display_Order__c ASC
        ]) {
            AssignedSpeakerDTO dto = new AssignedSpeakerDTO();
            dto.eventSpeakerId = es.Id;
            dto.speakerId = es.Speaker__c;
            dto.speakerName = es.Speaker__r.Name;
            dto.email = es.Speaker__r.Email__c;
            dto.organization = es.Speaker__r.Organization__c;
            dto.expertise = es.Speaker__r.Expertise__c;
            dto.photoUrl = es.Speaker__r.Photo_URL__c;
            dto.role = es.Role__c;
            dto.sessionTitle = es.Session_Title__c;
            dto.displayOrder = es.Display_Order__c;
            assigned.add(dto);
        }

        return assigned;
    }

    /**
     * Assigns a speaker to an event by inserting an Event_Speaker__c junction record.
     * Display_Order__c is set to MAX(existing) + 1.
     */
    @AuraEnabled
    public static void assignSpeaker(Id eventId, Id speakerId, String role, String sessionTitle) {
        // Determine next display order
        AggregateResult[] maxOrder = [
            SELECT MAX(Display_Order__c) maxVal
            FROM Event_Speaker__c
            WHERE Event__c = :eventId
        ];

        Decimal nextOrder = 1;
        if (maxOrder[0].get('maxVal') != null) {
            nextOrder = ((Decimal) maxOrder[0].get('maxVal')) + 1;
        }

        Event_Speaker__c junction = new Event_Speaker__c(
            Event__c = eventId,
            Speaker__c = speakerId,
            Role__c = role,
            Session_Title__c = sessionTitle,
            Display_Order__c = nextOrder
        );
        insert junction;
    }

    /**
     * Removes a speaker assignment by deleting the Event_Speaker__c record.
     */
    @AuraEnabled
    public static void removeSpeaker(Id eventSpeakerId) {
        delete [SELECT Id FROM Event_Speaker__c WHERE Id = :eventSpeakerId LIMIT 1];
    }

    /**
     * Updates role, session title, and display order on an existing speaker assignment.
     */
    @AuraEnabled
    public static void updateSpeakerAssignment(Id eventSpeakerId, String role, String sessionTitle, Decimal displayOrder) {
        Event_Speaker__c es = new Event_Speaker__c(
            Id = eventSpeakerId,
            Role__c = role,
            Session_Title__c = sessionTitle,
            Display_Order__c = displayOrder
        );
        update es;
    }

    // ── Inner wrapper classes ──────────────────────────────────────────────

    public class SpeakerSearchResult {
        @AuraEnabled public Id speakerId { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String organization { get; set; }
        @AuraEnabled public String expertise { get; set; }
        @AuraEnabled public String photoUrl { get; set; }
        @AuraEnabled public String bio { get; set; }
        @AuraEnabled public Boolean isAlreadyAssigned { get; set; }
        @AuraEnabled public Boolean isUnavailable { get; set; }
        @AuraEnabled public String conflictReason { get; set; }
    }

    public class AssignedSpeakerDTO {
        @AuraEnabled public Id eventSpeakerId { get; set; }
        @AuraEnabled public Id speakerId { get; set; }
        @AuraEnabled public String speakerName { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String organization { get; set; }
        @AuraEnabled public String expertise { get; set; }
        @AuraEnabled public String photoUrl { get; set; }
        @AuraEnabled public String role { get; set; }
        @AuraEnabled public String sessionTitle { get; set; }
        @AuraEnabled public Decimal displayOrder { get; set; }
    }
}
