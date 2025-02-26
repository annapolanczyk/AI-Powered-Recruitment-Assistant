/**
 * @description : Service class for handling Candidate-related operations
 * @author      : Anna Polańczyk
 * @group       : Recruitment
 * @last modified on : 02-26-2025
 * @last modified by : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class CandidateService {
    
    // Stałe dla poprawy czytelności
    private static final String ERROR_INSUFFICIENT_PERMISSIONS = 'Insufficient permissions';
    private static final String ERROR_MISSING_PARAMETERS = 'Missing required parameters';
    private static final Integer MAX_CV_TEXT_LENGTH = 8000;
    
    /**
     * Wyszukaj kandydatów na podstawie terminu wyszukiwania
     */
    public static List<Candidate__c> searchCandidates(String searchTerm) {
        checkCandidateAccess();
        
        String searchQuery = '%' + searchTerm + '%';
        return [SELECT Id, First_Name__c, Last_Name__c, Email__c, Status__c 
                FROM Candidate__c 
                WHERE First_Name__c LIKE :searchQuery 
                OR Last_Name__c LIKE :searchQuery 
                LIMIT 50];
    }
    
    /**
     * Główna metoda analizy CV
     */
    @AuraEnabled
    public static Map<String, Object> analyzeCV(Id candidateId, Id fileId) {
        validateCRUDPermissions();
        
        // 1. Walidacja parametrów
        Candidate__c candidate = getCandidateRecord(candidateId);
        if (candidate.Job__c == null) {
            throw new AuraHandledException(ERROR_MISSING_PARAMETERS + ': No job linked to candidate');
        }
        
        // 2. Pobierz wymagane umiejętności
        String requiredSkills = JobService.getRequiredSkillsForJob(candidate.Job__c);
        
        // 3. Pobierz i przetwórz zawartość pliku
        String fileContent = FileProcessingService.getFileContent(fileId);
        
        // 4. Wykonaj analizę OpenAI
        return performOpenAIAnalysis(fileContent, requiredSkills);
    }
    
    /**
     * Aktualizuj wyniki analizy CV dla kandydata
     */
    @AuraEnabled
    public static void updateCandidateAnalysisResults(Id candidateId, Map<String, Object> analysisResults) {
        if (candidateId == null || analysisResults == null) {
            throw new AuraHandledException('Invalid parameters');
        }
        
        checkCandidateUpdateAccess();
        
        updateCandidateWithAnalysisResults(candidateId, analysisResults);
    }
    
    /**
     * Asynchroniczna analiza CV
     */
    @future(callout=true)
    public static void analyzeCVAsync(Id candidateId, Id fileId) {
        try {
            Map<String, Object> results = analyzeCV(candidateId, fileId);
            updateCandidateAnalysisResults(candidateId, results);
        } catch(Exception e) {
            logError('Async CV analysis error', e);
        }
    }
    
    /**
     * Analiza CV kandydata na podstawie ostatniego przesłanego pliku
     */
    public static void analyzeCandidateCV(Id candidateId) {
        if(candidateId == null) {
            return;
        }
        
        checkContentDocumentLinkAccess();
        
        Id latestDocumentId = FileService.getLatestDocumentIdForEntity(candidateId);
        if(latestDocumentId != null) {
            analyzeCV(candidateId, latestDocumentId);
        }
    }
    
    // METODY POMOCNICZE
    
    /**
     * Wykonaj analizę OpenAI
     */
    private static Map<String, Object> performOpenAIAnalysis(String fileContent, String requiredSkills) {
        try {
            String apiKey = OpenAIService.getAPIKey();
            HttpResponse response = callOpenAI(fileContent, requiredSkills, apiKey);
            return parseOpenAIResponse(response);
        } catch(Exception e) {
            throw new AuraHandledException('OpenAI analysis failed: ' + e.getMessage());
        }
    }
    
    /**
     * Wywołaj API OpenAI
     */
    private static HttpResponse callOpenAI(String cvText, String requiredSkills, String apiKey) {
        String truncatedCvText = truncateText(cvText, MAX_CV_TEXT_LENGTH);
        Map<String, Object> requestBody = OpenAIService.prepareAnalysisRequestBody(truncatedCvText, requiredSkills);
        
        return OpenAIService.sendRequest(requestBody, apiKey);
    }
    
    /**
     * Parsuj odpowiedź OpenAI
     */
    private static Map<String, Object> parseOpenAIResponse(HttpResponse res) {
        OpenAIService.validateResponse(res);
        return OpenAIService.extractContentFromResponse(res);
    }
    
    /**
     * Pobierz rekord kandydata
     */
    private static Candidate__c getCandidateRecord(Id candidateId) {
        try {
            return [SELECT Id, First_Name__c, Last_Name__c, Job__c 
                    FROM Candidate__c 
                    WHERE Id = :candidateId];
        } catch(Exception e) {
            throw new AuraHandledException('Error retrieving candidate: ' + e.getMessage());
        }
    }
    
    /**
     * Aktualizuj kandydata z wynikami analizy
     */
    private static void updateCandidateWithAnalysisResults(Id candidateId, Map<String, Object> results) {
        // Sprawdź uprawnienia przed operacją DML
        if (!Schema.sObjectType.Candidate__c.isUpdateable()) {
            throw new AuraHandledException(ERROR_INSUFFICIENT_PERMISSIONS);
        }
        
        String skills = DataConverter.convertSkillsToString(results.get('skills'));
        Decimal matchScore = DataConverter.toDecimal(results.get('matchScore'));
        String recommendation = String.valueOf(results.get('recommendation'));
        
        Candidate__c candidate = new Candidate__c(
            Id = candidateId,
            Skills__c = skills,
            Status__c = 'In Review',
            Identified_Skills__c = skills,
            Match_Score__c = matchScore,
            AI_Recommendation__c = recommendation
        );
        
        try {
            update candidate;
        } catch (Exception e) {
            throw new AuraHandledException('Update error: ' + e.getMessage());
        }
    }
    
    // METODY WALIDACYJNE
    
    private static void checkCandidateAccess() {
        if(!Schema.sObjectType.Candidate__c.isAccessible()) {
            throw new SecurityException(ERROR_INSUFFICIENT_PERMISSIONS);
        }
    }
    
    private static void checkCandidateUpdateAccess() {
        if (!Schema.sObjectType.Candidate__c.isUpdateable()) {
            throw new AuraHandledException(ERROR_INSUFFICIENT_PERMISSIONS);
        }
    }
    
    private static void checkContentDocumentLinkAccess() {
        if(!Schema.sObjectType.ContentDocumentLink.isAccessible()) {
            logError('Insufficient permissions to access ContentDocumentLink', null);
        }
    }
    
    private static void validateCRUDPermissions() {
        if (!Schema.sObjectType.Candidate__c.isAccessible() ||
            !Schema.sObjectType.ContentVersion.isAccessible() ||
            !Schema.sObjectType.Job__c.isAccessible()) {
            throw new SecurityException(ERROR_INSUFFICIENT_PERMISSIONS);
        }
    }
    
    // METODY NARZĘDZIOWE
    
    private static String truncateText(String text, Integer maxLength) {
        return text.length() > maxLength ? text.substring(0, maxLength) : text;
    }
    
    private static void logError(String message, Exception e) {
        String errorDetails = e != null ? e.getMessage() : '';
        System.debug(LoggingLevel.ERROR, message + ': ' + errorDetails);
    }
}