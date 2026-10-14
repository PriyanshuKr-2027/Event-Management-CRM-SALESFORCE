/**
 * @description Handler class for EventSpeakerTrigger.
 *              Prevents double-booking a Speaker across overlapping Events.
 */
public class EventSpeakerTriggerHandler {

    /**
     * @description Validates that no speaker is assigned to two events whose
     *              date/time ranges overlap.
     * @param newRecords The list of Event_Speaker__c records being inserted or updated.
     */
    public static void beforeInsertUpdate(List<Event_Speaker__c> newRecords) {

        // 1. Collect Speaker IDs and Event IDs from the incoming records
        Set<Id> speakerIds = new Set<Id>();
        Set<Id> eventIds   = new Set<Id>();

        for (Event_Speaker__c rec : newRecords) {
            if (rec.Speaker__c != null) {
                speakerIds.add(rec.Speaker__c);
            }
            if (rec.Event__c != null) {
                eventIds.add(rec.Event__c);
            }
        }

        if (speakerIds.isEmpty() || eventIds.isEmpty()) {
            return;
        }

        // 2. Query the Events referenced by the incoming records so we know their date range
        Map<Id, Event__c> eventMap = new Map<Id, Event__c>([
            SELECT Id, Name, Start_Date_Time__c, End_Date_Time__c
            FROM Event__c
            WHERE Id IN :eventIds
        ]);

        // 3. Collect current record IDs to exclude from the "existing" query (for updates)
        Set<Id> currentRecordIds = new Set<Id>();
        for (Event_Speaker__c rec : newRecords) {
            if (rec.Id != null) {
                currentRecordIds.add(rec.Id);
            }
        }

        // 4. Query existing Event_Speaker__c assignments for the same speakers,
        //    joining to Event__c so we get date ranges for overlap comparison.
        //    Exclude the current records themselves (relevant during updates).
        List<Event_Speaker__c> existingAssignments = [
            SELECT Id,
                   Speaker__c,
                   Event__c,
                   Event__r.Name,
                   Event__r.Start_Date_Time__c,
                   Event__r.End_Date_Time__c
            FROM Event_Speaker__c
            WHERE Speaker__c IN :speakerIds
              AND Id NOT IN :currentRecordIds
        ];

        // 5. Build a map: Speaker Id → list of existing assignments (with event dates)
        Map<Id, List<Event_Speaker__c>> speakerToExisting = new Map<Id, List<Event_Speaker__c>>();
        for (Event_Speaker__c existing : existingAssignments) {
            if (!speakerToExisting.containsKey(existing.Speaker__c)) {
                speakerToExisting.put(existing.Speaker__c, new List<Event_Speaker__c>());
            }
            speakerToExisting.get(existing.Speaker__c).add(existing);
        }

        // 6. For each incoming record, check for overlapping assignments
        for (Event_Speaker__c rec : newRecords) {
            Event__c newEvent = eventMap.get(rec.Event__c);
            if (newEvent == null
                || newEvent.Start_Date_Time__c == null
                || newEvent.End_Date_Time__c == null) {
                continue;
            }

            DateTime newStart = newEvent.Start_Date_Time__c;
            DateTime newEnd   = newEvent.End_Date_Time__c;

            // Check against existing assignments for this speaker
            if (speakerToExisting.containsKey(rec.Speaker__c)) {
                for (Event_Speaker__c existing : speakerToExisting.get(rec.Speaker__c)) {
                    DateTime existingStart = existing.Event__r.Start_Date_Time__c;
                    DateTime existingEnd   = existing.Event__r.End_Date_Time__c;

                    if (existingStart == null || existingEnd == null) {
                        continue;
                    }

                    // Overlap: existingStart < newEnd AND existingEnd > newStart
                    if (existingStart < newEnd && existingEnd > newStart) {
                        rec.addError(
                            'Speaker is already assigned to "'
                            + existing.Event__r.Name + '" from '
                            + existingStart.format() + ' to '
                            + existingEnd.format()
                            + '. Please choose a different speaker or adjust the event schedule.'
                        );
                        break; // One error per record is enough
                    }
                }
            }

            // Also check for overlaps among the incoming batch itself
            // (e.g., two records in the same batch assign the same speaker to overlapping events)
            for (Event_Speaker__c other : newRecords) {
                // Skip self-comparison
                if (other === rec) {
                    continue;
                }
                if (other.Speaker__c != rec.Speaker__c) {
                    continue;
                }
                if (other.Event__c == rec.Event__c) {
                    continue;
                }

                Event__c otherEvent = eventMap.get(other.Event__c);
                if (otherEvent == null
                    || otherEvent.Start_Date_Time__c == null
                    || otherEvent.End_Date_Time__c == null) {
                    continue;
                }

                DateTime otherStart = otherEvent.Start_Date_Time__c;
                DateTime otherEnd   = otherEvent.End_Date_Time__c;

                if (otherStart < newEnd && otherEnd > newStart) {
                    rec.addError(
                        'Speaker is already assigned to "'
                        + otherEvent.Name + '" from '
                        + otherStart.format() + ' to '
                        + otherEnd.format()
                        + '. Please choose a different speaker or adjust the event schedule.'
                    );
                    break;
                }
            }
        }
    }
}
