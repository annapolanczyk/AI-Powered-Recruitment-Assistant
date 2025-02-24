/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 02-24-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class CandidateService {
    public static void analyzeCandidateCV(Id candidateId) {
        // Sprawdzanie uprawnień
        if(!Schema.sObjectType.Candidate__c.isAccessible() || 
           !Schema.sObjectType.ContentDocumentLink.isAccessible()) {
            throw new SecurityException('Insufficient permissions');
        }
        if(!Schema.sObjectType.Candidate__c.isUpdateable()) {
            throw new SecurityException('Insufficient permissions to update Candidate');
        }
                                
        Candidate__c candidate = [SELECT Id, First_Name__c, Last_Name__c, Job__c, Skills__c, Status__c 
                                FROM Candidate__c 
                                WHERE Id = :candidateId];
                                
        List<ContentDocumentLink> documentLinks = [
            SELECT ContentDocumentId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :candidateId
        ];
        
        if(!documentLinks.isEmpty()) {
            updateCandidateStatus(candidate);
            matchJobSkills(candidate);
        }
    }
    
    private static void updateCandidateStatus(Candidate__c candidate) {
        if(!Schema.sObjectType.Candidate__c.isUpdateable()) {
            throw new SecurityException('Insufficient permissions to update Candidate');
        }
        candidate.Status__c = 'In Review';
        update candidate;
    }
    
    private static void matchJobSkills(Candidate__c candidate) {
        if(!Schema.sObjectType.Job__c.isAccessible()) {
            throw new SecurityException('Insufficient permissions to access Job');
        }

        if(candidate.Job__c != null) {
            Job__c relatedJob = [SELECT Id, Required_Skills__c 
                                FROM Job__c 
                                WHERE Id = :candidate.Job__c];
        }
    }
    
    public static List<Candidate__c> searchCandidates(String searchTerm) {
        if(!Schema.sObjectType.Candidate__c.isAccessible()) {
            throw new SecurityException('Insufficient permissions to access Candidate');
        }

        String searchQuery = '%' + searchTerm + '%';
        return [SELECT Id, First_Name__c, Last_Name__c, Email__c, Status__c 
                FROM Candidate__c 
                WHERE First_Name__c LIKE :searchQuery 
                OR Last_Name__c LIKE :searchQuery 
                LIMIT 50];
    }
}