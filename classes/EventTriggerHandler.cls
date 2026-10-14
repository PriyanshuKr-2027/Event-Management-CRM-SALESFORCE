/**
 * Trigger handler for Event__c object.
 * Enforces venue conflict prevention (no two active events in the same physical venue
 * on overlapping dates/times) and venue capacity downgrade protection (cannot change
 * venue to a hall smaller than existing ticket quotas or booked seats).
 */
public with sharing class EventTriggerHandler {

    @TestVisible
    public static Boolean bypassVenueOverlapCheck = false;

    public static void beforeInsert(List<Event__c> newRecords) {
        if (!bypassVenueOverlapCheck) {
            validateVenueDoubleBooking(newRecords, null);
        }
    }

    public static void beforeUpdate(List<Event__c> newRecords, Map<Id, Event__c> oldMap) {
        if (!bypassVenueOverlapCheck) {
            validateVenueDoubleBooking(newRecords, oldMap);
        }
        validateVenueCapacityDowngrade(newRecords, oldMap);
    }

    /**
     * Prevents scheduling multiple active events at the same physical venue during overlapping time windows.
     * Criteria: Venue is set, Start & End times are populated, and Approval Status is not Cancelled or Rejected.
     */
    private static void validateVenueDoubleBooking(List<Event__c> newRecords, Map<Id, Event__c> oldMap) {
        Set<Id> venueIds = new Set<Id>();
        List<Event__c> candidates = new List<Event__c>();

        for (Event__c ev : newRecords) {
            if (ev.Venue__c == null || ev.Start_Date_Time__c == null || ev.End_Date_Time__c == null) {
                continue;
            }
            if ('Cancelled'.equalsIgnoreCase(ev.Approval_Status__c) || 'Rejected'.equalsIgnoreCase(ev.Approval_Status__c)) {
                continue;
            }

            Boolean isInsert = (oldMap == null);
            if (isInsert) {
                venueIds.add(ev.Venue__c);
                candidates.add(ev);
            } else {
                Event__c oldEv = oldMap.get(ev.Id);
                Boolean venueChanged = (ev.Venue__c != oldEv.Venue__c);
                Boolean datesChanged = (ev.Start_Date_Time__c != oldEv.Start_Date_Time__c || ev.End_Date_Time__c != oldEv.End_Date_Time__c);
                Boolean statusChanged = (ev.Approval_Status__c != oldEv.Approval_Status__c);

                if (venueChanged || datesChanged || statusChanged) {
                    venueIds.add(ev.Venue__c);
                    candidates.add(ev);
                }
            }
        }

        if (candidates.isEmpty()) {
            return;
        }

        // Query existing active events for these venues
        List<Event__c> existingEvents = [
            SELECT Id, Name, Venue__c, Start_Date_Time__c, End_Date_Time__c, Approval_Status__c
            FROM Event__c
            WHERE Venue__c IN :venueIds
              AND Approval_Status__c NOT IN ('Cancelled', 'Rejected')
              AND Start_Date_Time__c != null
              AND End_Date_Time__c != null
        ];

        Map<Id, List<Event__c>> venueEventsMap = new Map<Id, List<Event__c>>();
        for (Event__c ex : existingEvents) {
            if (!venueEventsMap.containsKey(ex.Venue__c)) {
                venueEventsMap.put(ex.Venue__c, new List<Event__c>());
            }
            venueEventsMap.get(ex.Venue__c).add(ex);
        }

        // Track events in the current batch to prevent intra-batch overlaps
        Map<Id, List<Event__c>> batchEventsByVenue = new Map<Id, List<Event__c>>();

        for (Event__c candidate : candidates) {
            DateTime candStart = candidate.Start_Date_Time__c;
            DateTime candEnd   = candidate.End_Date_Time__c;
            Id vId = candidate.Venue__c;

            // 1. Check against existing records in database
            if (venueEventsMap.containsKey(vId)) {
                for (Event__c existing : venueEventsMap.get(vId)) {
                    if (existing.Id == candidate.Id) {
                        continue;
                    }
                    // Overlap: existingStart < candEnd AND existingEnd > candStart
                    if (existing.Start_Date_Time__c < candEnd && existing.End_Date_Time__c > candStart) {
                        String eventName = String.isNotBlank(existing.Name) ? existing.Name : 'another event';
                        candidate.addError('Venue is already booked for "' + eventName + '" during this time window ('
                            + existing.Start_Date_Time__c.format('MMM d, yyyy h:mm a') + ' to '
                            + existing.End_Date_Time__c.format('MMM d, yyyy h:mm a') + ').');
                        break;
                    }
                }
            }

            // 2. Check against other records in the same batch
            if (batchEventsByVenue.containsKey(vId)) {
                for (Event__c sibling : batchEventsByVenue.get(vId)) {
                    if (sibling.Start_Date_Time__c < candEnd && sibling.End_Date_Time__c > candStart) {
                        candidate.addError('Another event in this batch is already scheduled for the same venue and overlapping time window.');
                        break;
                    }
                }
            }

            if (!batchEventsByVenue.containsKey(vId)) {
                batchEventsByVenue.put(vId, new List<Event__c>());
            }
            batchEventsByVenue.get(vId).add(candidate);
        }
    }

    /**
     * Prevents organizers from switching an event to a smaller venue if existing ticket
     * quotas or booked seats exceed the new venue's capacity.
     */
    private static void validateVenueCapacityDowngrade(List<Event__c> newRecords, Map<Id, Event__c> oldMap) {
        if (oldMap == null) {
            return;
        }

        Set<Id> changedEventIds = new Set<Id>();
        Set<Id> newVenueIds = new Set<Id>();

        for (Event__c ev : newRecords) {
            Event__c oldEv = oldMap.get(ev.Id);
            if (ev.Venue__c != null && ev.Venue__c != oldEv.Venue__c) {
                changedEventIds.add(ev.Id);
                newVenueIds.add(ev.Venue__c);
            }
        }

        if (changedEventIds.isEmpty()) {
            return;
        }

        Map<Id, Venue__c> venuesMap = new Map<Id, Venue__c>([
            SELECT Id, Name, Venue_Capacity__c
            FROM Venue__c
            WHERE Id IN :newVenueIds
        ]);

        List<Ticket_Type__c> ticketTypes = [
            SELECT Id, Event__c, Quota__c, Booked_Seats__c
            FROM Ticket_Type__c
            WHERE Event__c IN :changedEventIds
        ];

        Map<Id, Decimal> totalQuotaByEvent = new Map<Id, Decimal>();
        Map<Id, Decimal> totalBookedByEvent = new Map<Id, Decimal>();

        for (Ticket_Type__c tt : ticketTypes) {
            Decimal quota = (tt.Quota__c != null) ? tt.Quota__c : 0;
            Decimal booked = (tt.Booked_Seats__c != null) ? tt.Booked_Seats__c : 0;

            Decimal currQuota = totalQuotaByEvent.containsKey(tt.Event__c) ? totalQuotaByEvent.get(tt.Event__c) : 0;
            totalQuotaByEvent.put(tt.Event__c, currQuota + quota);

            Decimal currBooked = totalBookedByEvent.containsKey(tt.Event__c) ? totalBookedByEvent.get(tt.Event__c) : 0;
            totalBookedByEvent.put(tt.Event__c, currBooked + booked);
        }

        for (Event__c ev : newRecords) {
            if (!changedEventIds.contains(ev.Id)) {
                continue;
            }

            Venue__c newVenue = venuesMap.get(ev.Venue__c);
            if (newVenue == null || newVenue.Venue_Capacity__c == null) {
                continue;
            }

            Decimal capacity = newVenue.Venue_Capacity__c;
            Decimal totalQuota = totalQuotaByEvent.containsKey(ev.Id) ? totalQuotaByEvent.get(ev.Id) : 0;
            Decimal totalBooked = totalBookedByEvent.containsKey(ev.Id) ? totalBookedByEvent.get(ev.Id) : 0;

            if (totalQuota > capacity) {
                ev.addError('Cannot change venue to "' + newVenue.Name + '" (Capacity: ' + capacity
                    + '). Existing ticket quotas for this event (' + totalQuota + ') exceed the new venue capacity.');
            } else if (totalBooked > capacity) {
                ev.addError('Cannot change venue to "' + newVenue.Name + '" (Capacity: ' + capacity
                    + '). Already booked seats (' + totalBooked + ') exceed the new venue capacity.');
            }
        }
    }
}
