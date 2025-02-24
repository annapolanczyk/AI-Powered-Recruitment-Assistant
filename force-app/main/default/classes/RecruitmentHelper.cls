/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 02-24-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class RecruitmentHelper {
    public static Map<String, Decimal> calculateRecruitmentMetrics() {
        Map<String, Decimal> metrics = new Map<String, Decimal>();
        
        // Sprawdzanie uprawnień do odczytu
        if(!Schema.sObjectType.Job__c.isAccessible() || 
           !Schema.sObjectType.Candidate__c.isAccessible()) {
            throw new SecurityException('Insufficient permissions to access Job or Candidate objects');
        }
        
        // Calculate total number of active jobs
        Integer activeJobs = [SELECT COUNT() FROM Job__c WHERE Status__c = 'Open'];
        metrics.put('Active_Jobs', activeJobs);
        
        // Calculate total number of candidates
        Integer totalCandidates = [SELECT COUNT() FROM Candidate__c];
        metrics.put('Total_Candidates', totalCandidates);
        
        // Calculate conversion rate
        Integer acceptedCandidates = [SELECT COUNT() FROM Candidate__c WHERE Status__c = 'Accepted'];
        Decimal conversionRate = totalCandidates > 0 ? 
            (Decimal.valueOf(acceptedCandidates) / Decimal.valueOf(totalCandidates)) * 100 : 0;
        metrics.put('Conversion_Rate', conversionRate.setScale(2));
        
        return metrics;
    }
    
    public static List<Map<String, Object>> getRecruitmentTimeline(Id jobId) {
        // Sprawdzanie uprawnień do odczytu
        if(!Schema.sObjectType.Candidate__c.isAccessible()) {
            throw new SecurityException('Insufficient permissions to access Candidate object');
        }
        
        List<Map<String, Object>> timeline = new List<Map<String, Object>>();
        
        List<Candidate__c> candidates = [
            SELECT Id, First_Name__c, Last_Name__c, Status__c, CreatedDate,
                   LastModifiedDate
            FROM Candidate__c
            WHERE Job__c = :jobId
            ORDER BY CreatedDate DESC
        ];
        
        for(Candidate__c candidate : candidates) {
            timeline.add(new Map<String, Object>{
                'candidateId' => candidate.Id,
                'name' => candidate.First_Name__c + ' ' + candidate.Last_Name__c,
                'status' => candidate.Status__c,
                'applicationDate' => candidate.CreatedDate,
                'lastUpdated' => candidate.LastModifiedDate
            });
        }
        
        return timeline;
    }
    
    public static void sendStatusUpdateEmail(Id candidateId, String newStatus) {
        // Sprawdzanie uprawnień do odczytu
        if(!Schema.sObjectType.Candidate__c.isAccessible() || 
           !Schema.sObjectType.Job__c.isAccessible()) {
            throw new SecurityException('Insufficient permissions to access objects');
        }
        
        Candidate__c candidate = [
            SELECT Id, First_Name__c, Last_Name__c, Email__c, Job__c,
                   Job__r.Title__c
            FROM Candidate__c
            WHERE Id = :candidateId
        ];
        
        if(String.isNotBlank(candidate.Email__c)) {
            String subject = 'Application Status Update - ' + candidate.Job__r.Title__c;
            String body = 'Dear ' + candidate.First_Name__c + ',\n\n' +
                         'Your application status for ' + candidate.Job__r.Title__c +
                         ' has been updated to: ' + newStatus + '.\n\n' +
                         'Best regards,\nRecruitment Team';
            
            // Send email logic here
            // Note: Implementation will depend on your email sending configuration
        }
    }
}