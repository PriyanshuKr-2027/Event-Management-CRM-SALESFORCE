/**
 * Final gatekeeper for registration availability (prd.md §14).
 *
 * Runs before insert on Registration__c. Re-validates everything the UI
 * already checked (Event open, Ticket Type belongs to Event, Ticket Type
 * available, quota not exceeded) because none of that is safe to trust from
 * the client, and additionally protects against CONCURRENT booking attempts
 * for the last seat(s) via row-level locking (FOR UPDATE) — something no
 * Validation Rule can do, since a VR evaluates against transaction-start
 * state with no locking mechanism (validationrules.md Resolved §2).
 *
 * This class also owns the write to Ticket_Type__c.Booked_Seats__c. That
 * field is a plain Number, NOT a native Roll-Up Summary — Registration→
 * Ticket Type is a Lookup, not Master-Detail (relationship.md), so a native
 * rollup isn't available here, and prd.md's "one source of truth for
 * inventory" principle means only this class ever writes it (never the
 * Record-Triggered Flow — see flows.md Flow 2's scope note).
 *
 * Bulk-safe: one locking query, all validation done in-memory against
 * running counters (so multiple Registrations in the same batch against the
 * same Ticket Type are still counted correctly), one bulk update.
 *
 * Also handles seat RELEASE on cancellation, deletion, and undeletion
 * to prevent the "seat black hole" where cancelled bookings permanently
 * consume capacity.
 */
public class RegistrationTriggerHandler {

    public static void beforeInsert(List<Registration__c> newRecords) {
        Set<Id> ticketTypeIds = new Set<Id>();
        for (Registration__c reg : newRecords) {
            if (reg.Ticket_Type__c != null) {
                ticketTypeIds.add(reg.Ticket_Type__c);
            }
        }
        if (ticketTypeIds.isEmpty()) {
            return;
        }

        // Row-level lock. Any other transaction trying to insert a
        // Registration against one of these same Ticket Types blocks here
        // until this transaction commits or rolls back — this is what
        // makes the last-seat race condition safe.
        Map<Id, Ticket_Type__c> lockedTicketTypes = new Map<Id, Ticket_Type__c>([
            SELECT Id, Event__c, Quota__c, Booked_Seats__c, Status__c,
                   Event__r.Registration_Status__c
            FROM Ticket_Type__c
            WHERE Id IN :ticketTypeIds
            FOR UPDATE
        ]);

        // Seed running counters from the locked snapshot, then increment
        // in-memory as each Registration in THIS batch is validated — this
        // is what keeps bulk registrations against the same Ticket Type
        // safe within a single transaction.
        Map<Id, Decimal> runningBookedSeats = new Map<Id, Decimal>();
        for (Ticket_Type__c tt : lockedTicketTypes.values()) {
            runningBookedSeats.put(tt.Id, tt.Booked_Seats__c != null ? tt.Booked_Seats__c : 0);
        }

        Set<Id> ticketTypeIdsToUpdate = new Set<Id>();

        for (Registration__c reg : newRecords) {
            Ticket_Type__c tt = lockedTicketTypes.get(reg.Ticket_Type__c);

            if (tt == null) {
                reg.addError('Selected ticket type could not be found.');
                continue;
            }
            if (reg.Event__c != tt.Event__c) {
                reg.addError('Selected ticket type does not belong to the selected event.');
                continue;
            }
            if (tt.Event__r.Registration_Status__c != 'Open') {
                reg.addError('This event is not currently open for registration.');
                continue;
            }
            if (tt.Status__c == 'Sold Out' || tt.Status__c == 'Closed') {
                reg.addError('This ticket type is no longer available. Please choose another ticket type.');
                continue;
            }

            Decimal currentBooked = runningBookedSeats.get(tt.Id);
            Decimal quota = tt.Quota__c != null ? tt.Quota__c : 0;

            if (currentBooked + 1 > quota) {
                reg.addError('This ticket type just sold out. Please choose another ticket type.');
                continue;
            }

            // Reserve the seat for this Registration.
            runningBookedSeats.put(tt.Id, currentBooked + 1);
            ticketTypeIdsToUpdate.add(tt.Id);
        }

        if (ticketTypeIdsToUpdate.isEmpty()) {
            return;
        }

        List<Ticket_Type__c> updates = new List<Ticket_Type__c>();
        for (Id ttId : ticketTypeIdsToUpdate) {
            Ticket_Type__c original = lockedTicketTypes.get(ttId);
            Decimal newBookedSeats = runningBookedSeats.get(ttId);

            Ticket_Type__c updateRecord = new Ticket_Type__c(
                Id = ttId,
                Booked_Seats__c = newBookedSeats
            );
            if (original.Quota__c != null && newBookedSeats >= original.Quota__c) {
                updateRecord.Status__c = 'Sold Out';
            }
            updates.add(updateRecord);
        }

        // Single bulk DML — same transaction as the Registration insert, so
        // if the Registration insert itself later fails for any other
        // reason, this update rolls back with it.
        update updates;
    }

    /**
     * After Update: Release seats when registration status changes TO 'Cancelled'.
     * Re-increment seats if a registration is un-cancelled (status changes FROM 'Cancelled'
     * back to an active status).
     */
    public static void afterUpdate(List<Registration__c> newRecords, Map<Id, Registration__c> oldMap) {
        // Collect ticket type IDs that need seat adjustments
        Map<Id, Integer> seatDeltas = new Map<Id, Integer>();
        Set<Id> newlyCancelledRegIds = new Set<Id>();
        Set<Id> uncancelledRegIds = new Set<Id>();

        for (Registration__c reg : newRecords) {
            Registration__c oldReg = oldMap.get(reg.Id);
            if (reg.Ticket_Type__c == null) continue;

            Boolean wasCancelled = 'Cancelled'.equalsIgnoreCase(oldReg.Registration_Status__c);
            Boolean isCancelled = 'Cancelled'.equalsIgnoreCase(reg.Registration_Status__c);

            if (!wasCancelled && isCancelled) {
                // Newly cancelled — release a seat and void child tickets
                Integer delta = seatDeltas.containsKey(reg.Ticket_Type__c) ? seatDeltas.get(reg.Ticket_Type__c) : 0;
                seatDeltas.put(reg.Ticket_Type__c, delta - 1);
                newlyCancelledRegIds.add(reg.Id);
            } else if (wasCancelled && !isCancelled) {
                // Un-cancelled (reactivated) — reclaim a seat and restore child tickets
                Integer delta = seatDeltas.containsKey(reg.Ticket_Type__c) ? seatDeltas.get(reg.Ticket_Type__c) : 0;
                seatDeltas.put(reg.Ticket_Type__c, delta + 1);
                uncancelledRegIds.add(reg.Id);
            }
        }

        if (!seatDeltas.isEmpty()) {
            adjustBookedSeats(seatDeltas);
        }

        if (!newlyCancelledRegIds.isEmpty()) {
            cancelChildTickets(newlyCancelledRegIds);
        }

        if (!uncancelledRegIds.isEmpty()) {
            reactivateChildTickets(uncancelledRegIds);
        }
    }

    /**
     * Voids child tickets when a registration is cancelled so cancelled
     * tickets cannot pass gate check-in.
     */
    private static void cancelChildTickets(Set<Id> regIds) {
        List<Ticket__c> ticketsToCancel = [
            SELECT Id, Ticket_Status__c
            FROM Ticket__c
            WHERE Registration__c IN :regIds
              AND Ticket_Status__c != 'Cancelled'
        ];
        if (!ticketsToCancel.isEmpty()) {
            for (Ticket__c t : ticketsToCancel) {
                t.Ticket_Status__c = 'Cancelled';
            }
            update ticketsToCancel;
        }
    }

    /**
     * Restores child tickets to Active when a registration is uncancelled.
     */
    private static void reactivateChildTickets(Set<Id> regIds) {
        List<Ticket__c> ticketsToReactivate = [
            SELECT Id, Ticket_Status__c
            FROM Ticket__c
            WHERE Registration__c IN :regIds
              AND Ticket_Status__c = 'Cancelled'
        ];
        if (!ticketsToReactivate.isEmpty()) {
            for (Ticket__c t : ticketsToReactivate) {
                t.Ticket_Status__c = 'Active';
            }
            update ticketsToReactivate;
        }
    }

    /**
     * After Delete: Release seats for all deleted registrations that were NOT
     * already in 'Cancelled' status (cancelled ones already had their seats released).
     */
    public static void afterDelete(List<Registration__c> oldRecords) {
        Map<Id, Integer> seatDeltas = new Map<Id, Integer>();

        for (Registration__c reg : oldRecords) {
            if (reg.Ticket_Type__c == null) continue;
            // Only release seats for non-cancelled registrations (cancelled ones were already released)
            if (!'Cancelled'.equalsIgnoreCase(reg.Registration_Status__c)) {
                Integer delta = seatDeltas.containsKey(reg.Ticket_Type__c) ? seatDeltas.get(reg.Ticket_Type__c) : 0;
                seatDeltas.put(reg.Ticket_Type__c, delta - 1);
            }
        }

        if (!seatDeltas.isEmpty()) {
            adjustBookedSeats(seatDeltas);
        }
    }

    /**
     * After Undelete: Re-claim seats for restored registrations that are NOT
     * in 'Cancelled' status.
     */
    public static void afterUndelete(List<Registration__c> newRecords) {
        Map<Id, Integer> seatDeltas = new Map<Id, Integer>();

        for (Registration__c reg : newRecords) {
            if (reg.Ticket_Type__c == null) continue;
            // Only reclaim seats for non-cancelled registrations
            if (!'Cancelled'.equalsIgnoreCase(reg.Registration_Status__c)) {
                Integer delta = seatDeltas.containsKey(reg.Ticket_Type__c) ? seatDeltas.get(reg.Ticket_Type__c) : 0;
                seatDeltas.put(reg.Ticket_Type__c, delta + 1);
            }
        }

        if (!seatDeltas.isEmpty()) {
            adjustBookedSeats(seatDeltas);
        }
    }

    /**
     * Shared utility: applies seat count adjustments to Ticket_Type__c records
     * using row-level locking for concurrency safety.
     * Positive delta = seats consumed, Negative delta = seats released.
     * Automatically toggles Status__c between 'Sold Out' and 'Available'.
     */
    private static void adjustBookedSeats(Map<Id, Integer> seatDeltas) {
        // Lock the ticket types to prevent concurrent modifications
        Map<Id, Ticket_Type__c> lockedTypes = new Map<Id, Ticket_Type__c>([
            SELECT Id, Quota__c, Booked_Seats__c, Status__c
            FROM Ticket_Type__c
            WHERE Id IN :seatDeltas.keySet()
            FOR UPDATE
        ]);

        List<Ticket_Type__c> updates = new List<Ticket_Type__c>();
        for (Id ttId : seatDeltas.keySet()) {
            Ticket_Type__c tt = lockedTypes.get(ttId);
            if (tt == null) continue;

            Decimal currentBooked = tt.Booked_Seats__c != null ? tt.Booked_Seats__c : 0;
            Decimal newBooked = currentBooked + seatDeltas.get(ttId);
            // Floor at zero — should never go negative, but be safe
            if (newBooked < 0) {
                newBooked = 0;
            }

            Decimal quota = tt.Quota__c != null ? tt.Quota__c : 0;

            Ticket_Type__c updateRecord = new Ticket_Type__c(
                Id = ttId,
                Booked_Seats__c = newBooked
            );

            // Toggle status based on new seat count
            if (newBooked >= quota && quota > 0) {
                updateRecord.Status__c = 'Sold Out';
            } else if (tt.Status__c == 'Sold Out' && newBooked < quota) {
                // Was Sold Out but seats freed up — reopen
                updateRecord.Status__c = 'Available';
            }

            updates.add(updateRecord);
        }

        if (!updates.isEmpty()) {
            update updates;
        }
    }
}
