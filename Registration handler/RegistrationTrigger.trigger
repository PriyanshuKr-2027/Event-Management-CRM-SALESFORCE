trigger RegistrationTrigger on Registration__c (before insert, after update, after delete, after undelete) {
    if (Trigger.isBefore && Trigger.isInsert) {
        RegistrationTriggerHandler.beforeInsert(Trigger.new);
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
        RegistrationTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
    }
    if (Trigger.isAfter && Trigger.isDelete) {
        RegistrationTriggerHandler.afterDelete(Trigger.old);
    }
    if (Trigger.isAfter && Trigger.isUndelete) {
        RegistrationTriggerHandler.afterUndelete(Trigger.new);
    }
}
