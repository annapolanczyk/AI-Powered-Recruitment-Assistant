/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 02-24-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
@isTest
private class JobServiceTest {
    @TestSetup
    static void setupTestData() {
        // Create test Jobs
        List<Job__c> testJobs = new List<Job__c>();
        testJobs.add(new Job__c(
            Title__c = 'Senior Developer',
            Description__c = 'Senior Developer Position',
            Required_Skills__c = 'Apex, Lightning, Integration',
            Status__c = 'Open'
        ));
        testJobs.add(new Job__c(
            Title__c = 'Junior Developer',
            Description__c = 'Junior Developer Position',
            Required_Skills__c = 'Apex, HTML, CSS',
            Status__c = 'Open'
        ));
        insert testJobs;
        
        // Create test Candidates
        List<Candidate__c> testCandidates = new List<Candidate__c>();
        testCandidates.add(new Candidate__c(
            First_Name__c = 'John',
            Last_Name__c = 'Doe',
            Email__c = 'john.doe@test.com',
            Skills__c = 'Apex, Lightning',
            Status__c = 'New',
            Job__c = testJobs[0].Id
        ));
        testCandidates.add(new Candidate__c(
            First_Name__c = 'Jane',
            Last_Name__c = 'Smith',
            Email__c = 'jane.smith@test.com',
            Skills__c = 'Apex, HTML',
            Status__c = 'New',
            Job__c = testJobs[0].Id
        ));
        insert testCandidates;
    }
    
    @isTest
    static void testGetActiveJobs() {
        Test.startTest();
        List<Job__c> activeJobs = JobService.getActiveJobs();
        Test.stopTest();
        
        System.assertEquals(2, activeJobs.size(), 'Should return 2 active jobs');
    }
    
    @isTest
    static void testGetJobCandidates() {
        Job__c testJob = [SELECT Id FROM Job__c WHERE Title__c = 'Senior Developer' LIMIT 1];
        
        Test.startTest();
        List<Candidate__c> candidates = JobService.getJobCandidates(testJob.Id);
        Test.stopTest();
        
        System.assertEquals(2, candidates.size(), 'Should return 2 candidates for the job');
    }
    
    @isTest
    static void testCloseJob() {
        Job__c testJob = [SELECT Id FROM Job__c WHERE Title__c = 'Senior Developer' LIMIT 1];
        
        Test.startTest();
        JobService.closeJob(testJob.Id);
        Test.stopTest();
        
        // Verify job status
        Job__c closedJob = [SELECT Status__c FROM Job__c WHERE Id = :testJob.Id];
        System.assertEquals('Closed', closedJob.Status__c, 'Job should be closed');
        
        // Verify candidates status
        List<Candidate__c> updatedCandidates = [SELECT Status__c FROM Candidate__c WHERE Job__c = :testJob.Id];
        for(Candidate__c candidate : updatedCandidates) {
            System.assertEquals('Rejected', candidate.Status__c, 'Candidates should be rejected');
        }
    }
    
    @isTest
    static void testSearchJobs() {
        Test.startTest();
        List<Job__c> searchResults = JobService.searchJobs('Developer');
        Test.stopTest();
        
        System.assertEquals(2, searchResults.size(), 'Should find 2 jobs with Developer in the title');
    }
}