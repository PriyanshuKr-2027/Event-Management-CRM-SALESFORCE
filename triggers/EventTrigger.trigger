trigger EventTrigger on Event__c (before insert, before update) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            EventTriggerHandler.beforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            EventTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}
