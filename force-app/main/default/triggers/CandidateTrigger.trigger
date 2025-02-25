/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 02-25-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
trigger CandidateTrigger on Candidate__c (after insert, after update) {
    if(Trigger.isAfter) {
        if(Trigger.isInsert) {
            for(Candidate__c candidate : Trigger.new) {
                CandidateService.analyzeCandidateCV(candidate.Id);
            }
        }
    }
}