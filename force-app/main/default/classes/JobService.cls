/**
 * @description : Service class for handling Job-related operations
 * @author      : Anna Polańczyk
 * @group       : Recruitment
 * @last modified on  : 02-26-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class JobService {
    @AuraEnabled(cacheable=true)
    public static List<Job__c> getActiveJobs() {
        if(!Schema.sObjectType.Job__c.isAccessible() ||
           !Schema.sObjectType.Job__c.fields.Id.isAccessible() ||
           !Schema.sObjectType.Job__c.fields.Title__c.isAccessible() ||
           !Schema.sObjectType.Job__c.fields.Description__c.isAccessible() ||
           !Schema.sObjectType.Job__c.fields.Required_Skills__c.isAccessible() ||
           !Schema.sObjectType.Job__c.fields.Status__c.isAccessible() ||
           !Schema.sObjectType.Job__c.fields.Name.isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to access Job fields');
        }

        return [SELECT Id, Title__c, Description__c, Required_Skills__c, Status__c, Name 
                FROM Job__c 
                WHERE Status__c = 'Open' 
                ORDER BY CreatedDate DESC 
                LIMIT 1000];
    }
    
    public static List<Candidate__c> getJobCandidates(Id jobId) {
        if(jobId == null) {
            throw new IllegalArgumentException('Job Id cannot be null');
        }

        if(!Schema.sObjectType.Candidate__c.isAccessible() ||
           !Schema.sObjectType.Candidate__c.fields.Id.isAccessible() ||
           !Schema.sObjectType.Candidate__c.fields.First_Name__c.isAccessible() ||
           !Schema.sObjectType.Candidate__c.fields.Last_Name__c.isAccessible() ||
           !Schema.sObjectType.Candidate__c.fields.Email__c.isAccessible() ||
           !Schema.sObjectType.Candidate__c.fields.Status__c.isAccessible() ||
           !Schema.sObjectType.Candidate__c.fields.Skills__c.isAccessible() ||
           !Schema.sObjectType.Candidate__c.fields.Job__c.isAccessible()) {
            throw new SecurityException('Insufficient permissions to access Candidate fields');
        }

        return [SELECT Id, First_Name__c, Last_Name__c, Email__c, Status__c, Skills__c
                FROM Candidate__c
                WHERE Job__c = :jobId
                ORDER BY CreatedDate DESC];
    }
    
    public static void closeJob(Id jobId) {
        if(jobId == null) {
            throw new IllegalArgumentException('Job Id cannot be null');
        }

        if(!Schema.sObjectType.Job__c.isAccessible() ||
           !Schema.sObjectType.Job__c.fields.Id.isAccessible() ||
           !Schema.sObjectType.Job__c.fields.Status__c.isAccessible() ||
           !Schema.sObjectType.Job__c.isUpdateable() || 
           !Schema.sObjectType.Job__c.fields.Status__c.isUpdateable() ||
           !Schema.sObjectType.Candidate__c.isAccessible() ||
           !Schema.sObjectType.Candidate__c.isUpdateable() ||
           !Schema.sObjectType.Candidate__c.fields.Id.isAccessible() ||
           !Schema.sObjectType.Candidate__c.fields.Job__c.isAccessible() ||
           !Schema.sObjectType.Candidate__c.fields.Status__c.isAccessible() ||
           !Schema.sObjectType.Candidate__c.fields.Status__c.isUpdateable()) {
            throw new SecurityException('Insufficient permissions to update records');
        }

        Job__c job = [SELECT Id, Status__c FROM Job__c WHERE Id = :jobId LIMIT 1];
        if(job == null) {
            throw new IllegalArgumentException('Job with provided Id does not exist');
        }
        if(job.Status__c == 'Closed') {
            throw new IllegalArgumentException('Job is already closed');
        }

        job.Status__c = 'Closed';
        update job;
        
        List<Candidate__c> candidates = [SELECT Id, Status__c FROM Candidate__c 
                                       WHERE Job__c = :jobId 
                                       AND Status__c != 'Accepted'];
        for(Candidate__c candidate : candidates) {
            candidate.Status__c = 'Rejected';
        }
        if(!candidates.isEmpty()) {
            update candidates;
        }
    }
    
    public static List<Job__c> searchJobs(String searchTerm) {
        if(String.isBlank(searchTerm)) {
            throw new IllegalArgumentException('Search term cannot be blank');
        }

        if(!Schema.sObjectType.Job__c.isAccessible() ||
           !Schema.sObjectType.Job__c.fields.Id.isAccessible() ||
           !Schema.sObjectType.Job__c.fields.Title__c.isAccessible() ||
           !Schema.sObjectType.Job__c.fields.Description__c.isAccessible() ||
           !Schema.sObjectType.Job__c.fields.Required_Skills__c.isAccessible() ||
           !Schema.sObjectType.Job__c.fields.Status__c.isAccessible()) {
            throw new SecurityException('Insufficient permissions to access Job fields');
        }

        String searchQuery = '%' + searchTerm + '%';
        return [SELECT Id, Title__c, Description__c, Required_Skills__c, Status__c
                FROM Job__c
                WHERE Title__c LIKE :searchQuery
                OR Required_Skills__c LIKE :searchQuery
                ORDER BY CreatedDate DESC
                LIMIT 50];
    }

    /**
     * Pobiera wymagane umiejętności dla danego stanowiska
     */
    public static String getRequiredSkillsForJob(Id jobId) {
        if (!Schema.sObjectType.Job__c.isAccessible() || jobId == null) {
            return '';
        }
        
        Job__c job = [SELECT Required_Skills__c FROM Job__c WHERE Id = :jobId LIMIT 1];
        String skills = job.Required_Skills__c != null ? job.Required_Skills__c : '';
        System.debug(LoggingLevel.INFO, '>>> Required skills: ' + skills);
        return skills;
    }
}