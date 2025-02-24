/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 02-24-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
@isTest
private class CandidateServiceTest {
    @TestSetup
    static void setupTestData() {
        // Create test Job
        Job__c testJob = new Job__c(
            Title__c = 'Test Developer',
            Description__c = 'Test Job Description',
            Required_Skills__c = 'Java, Apex, Salesforce',
            Status__c = 'Open'
        );
        insert testJob;
        
        // Create test Candidate
        Candidate__c testCandidate = new Candidate__c(
            First_Name__c = 'John',
            Last_Name__c = 'Doe',
            Email__c = 'john.doe@test.com',
            Skills__c = 'Java, Apex, Salesforce',
            Status__c = 'New',
            Job__c = testJob.Id
        );
        insert testCandidate;
    }
    
    @isTest
    static void testAnalyzeCandidateCV() {
        Candidate__c testCandidate = [SELECT Id FROM Candidate__c LIMIT 1];
        
        // Create test ContentVersion
        ContentVersion cv = new ContentVersion(
            Title = 'Test CV',
            PathOnClient = 'TestCV.pdf',
            VersionData = Blob.valueOf('Test CV Content'),
            IsMajorVersion = true
        );
        insert cv;
        
        // Get ContentDocument Id
        Id conDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        
        // Create ContentDocumentLink
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = conDocId,
            LinkedEntityId = testCandidate.Id,
            ShareType = 'V'
        );
        insert cdl;
        
        Test.startTest();
        CandidateService.analyzeCandidateCV(testCandidate.Id);
        Test.stopTest();
        
        // Verify status update
        Candidate__c updatedCandidate = [SELECT Status__c FROM Candidate__c WHERE Id = :testCandidate.Id];
        System.assertEquals('In Review', updatedCandidate.Status__c, 'Candidate status should be updated to In Review');
    }
    
    @isTest
    static void testSearchCandidates() {
        Test.startTest();
        List<Candidate__c> searchResults = CandidateService.searchCandidates('John');
        Test.stopTest();
        
        System.assertEquals(1, searchResults.size(), 'Should find one candidate with name John');
    }
}