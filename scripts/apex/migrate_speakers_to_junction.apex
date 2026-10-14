// Migration script: Converts old Speaker__c.Event__c lookup records into Event_Speaker__c junction records.
// Run this ONCE after deploying Event_Speaker__c to migrate existing data.
// Safe to re-run — checks for existing junction records to avoid duplicates.

List<Speaker__c> oldSpeakers = [SELECT Id, Name, Event__c FROM Speaker__c WHERE Event__c != null];

// Check for existing junction records to avoid duplicates
Set<String> existingKeys = new Set<String>();
for (Event_Speaker__c es : [SELECT Event__c, Speaker__c FROM Event_Speaker__c]) {
    existingKeys.add(String.valueOf(es.Event__c) + '-' + String.valueOf(es.Speaker__c));
}

List<Event_Speaker__c> junctions = new List<Event_Speaker__c>();
Integer order = 1;
for (Speaker__c s : oldSpeakers) {
    String key = String.valueOf(s.Event__c) + '-' + String.valueOf(s.Id);
    if (!existingKeys.contains(key)) {
        junctions.add(new Event_Speaker__c(
            Event__c = s.Event__c,
            Speaker__c = s.Id,
            Role__c = 'Guest Speaker',
            Display_Order__c = order++
        ));
    }
}

if (!junctions.isEmpty()) {
    insert junctions;
    System.debug('Migrated ' + junctions.size() + ' speaker assignments to Event_Speaker__c junction records.');
} else {
    System.debug('No new speaker assignments to migrate.');
}
