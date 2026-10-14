trigger EventSpeakerTrigger on Event_Speaker__c (before insert, before update) {
    if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
        EventSpeakerTriggerHandler.beforeInsertUpdate(Trigger.new);
    }
}
