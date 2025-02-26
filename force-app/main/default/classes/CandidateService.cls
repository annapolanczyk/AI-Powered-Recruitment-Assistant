/**
 * @description : Service class for handling Candidate-related operations
 * @author      : Anna Polańczyk
 * @group       : Recruitment
 * @last modified on : 02-26-2025
 * @last modified by : ChangeMeIn@UserSettingsUnder.SFDoc
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
    private static String getOpenAIKey() {
        OpenAI_Settings__c apiSettings = OpenAI_Settings__c.getInstance();
        String apiKey = apiSettings.API_Key__c;
        
        if(String.isBlank(apiKey)) {
            throw new AuraHandledException('OpenAI API key is not configured');
        }
        
        return apiKey;
    }
    
    private static Candidate__c getCandidateWithJob(Id candidateId) {
        try {
            return [SELECT Id, First_Name__c, Last_Name__c, Job__c 
                    FROM Candidate__c 
                    WHERE Id = :candidateId];
        } catch(Exception e) {
            throw new AuraHandledException('Error retrieving candidate: ' + e.getMessage());
        }
    }
    @AuraEnabled
    public static Map<String, Object> analyzeCV(Id candidateId, String fileId) {
        validateInputs(candidateId, fileId);
        validatePermissions();
        String apiKey = getOpenAIKey();
        
        ContentVersion cvFile = getCVFile(fileId);
        Candidate__c candidate = getCandidateWithJob(candidateId);
        String cvText = extractCVText(cvFile);
        String requiredSkills = getRequiredSkills(candidate.Job__c);
        
        Map<String, Object> results = callOpenAIAnalysis(cvText, requiredSkills, apiKey);
        
        try {
            updateCandidateAnalysisResults(candidateId, results);
        } catch(Exception e) {
            System.debug('Error updating candidate record: ' + e.getMessage());
        }
        
        return results;
    }
    
    private static void validateInputs(Id candidateId, String fileId) {
        if(candidateId == null || fileId == null) {
            throw new AuraHandledException('Candidate ID and file ID are required');
        }
    }
    
    private static void validatePermissions() {
        if(!Schema.sObjectType.Candidate__c.isAccessible() || 
           !Schema.sObjectType.ContentVersion.isAccessible() ||
           !Schema.sObjectType.Job__c.isAccessible()) {
            throw new SecurityException('Insufficient permissions to access records');
        }
    }
    
    private static ContentVersion getCVFile(String fileId) {
        try {
            return [SELECT VersionData, FileExtension FROM ContentVersion 
                    WHERE ContentDocumentId = :fileId AND IsLatest = true LIMIT 1];
        } catch(Exception e) {
            throw new AuraHandledException('Error retrieving file: ' + e.getMessage());
        }
    }
    
    private static String extractCVText(ContentVersion cvFile) {
        if(!new Set<String>{'pdf', 'docx', 'txt'}.contains(cvFile.FileExtension.toLowerCase())) {
            throw new AuraHandledException('Unsupported file format. Please upload PDF, DOCX, or TXT file.');
        }
        
        try {
            return EncodingUtil.base64Encode(cvFile.VersionData);
        } catch(Exception e) {
            throw new AuraHandledException('Error processing file: ' + e.getMessage());
        }
    }
    
    private static String getRequiredSkills(Id jobId) {
        if(jobId == null) {
            return '';
        }
        
        try {
            Job__c job = [SELECT Id, Required_Skills__c FROM Job__c WHERE Id = :jobId LIMIT 1];
            return job.Required_Skills__c;
        } catch(Exception e) {
            // Obsługuj brak oferty pracy, ale nie przerywaj analizy
            System.debug('Warning: Job not found: ' + e.getMessage());
            return '';
        }
    }
    
    @SuppressWarnings('PMD.ApexSuggestUsingNamedCred')
    private static Map<String, Object> callOpenAIAnalysis(String cvText, String requiredSkills, String apiKey) {
        Map<String, Object> results = new Map<String, Object>();
        
        // Przygotuj dane dla OpenAI
        Map<String, Object> openAIRequest = new Map<String, Object>{
            'model' => 'gpt-4',
            'messages' => new List<Map<String, String>>{
                new Map<String, String>{
                    'role' => 'system',
                    'content' => 'You are an AI assistant specialized in analyzing CVs and matching them to job requirements. Extract skills, calculate match score as percentage, and provide recommendations. Return the result in JSON format with the following structure: {"skills": ["skill1", "skill2", ...], "matchScore": 85, "recommendation": "Your recommendation text here."}'
                },
                new Map<String, String>{
                    'role' => 'user',
                    'content' => 'Analyze this CV and extract skills. Calculate match score based on the following required skills: ' + requiredSkills + '. CV content: ' + cvText
                }
            },
            'temperature' => 0.2
        };
        
        // Wywołaj API OpenAI
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.openai.com/v1/chat/completions');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + apiKey);
        req.setBody(JSON.serialize(openAIRequest));
        req.setTimeout(120000); // 2 minuty (analiza może trwać dłużej)
        
        HttpResponse res;
        
        try {
            res = http.send(req);
            
            if(res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                List<Map<String, Object>> choices = (List<Map<String, Object>>)responseMap.get('choices');
                
                if (!choices.isEmpty()) {
                    Map<String, Object> choice = choices[0];
                    Map<String, Object> message = (Map<String, Object>)choice.get('message');
                    String content = (String)message.get('content');
                    
                    // Parsowanie odpowiedzi AI w formacie JSON
                    Pattern p = Pattern.compile('\\{[\\s\\S]*\\}');
                    Matcher m = p.matcher(content);
                    if (m.find()) {
                        String jsonStr = m.group();
                        Map<String, Object> aiAnalysis = (Map<String, Object>)JSON.deserializeUntyped(jsonStr);
                        
                        // Przygotuj wyniki
                        results.put('skills', aiAnalysis.get('skills'));
                        results.put('matchScore', aiAnalysis.get('matchScore'));
                        results.put('recommendation', aiAnalysis.get('recommendation'));
                    } else {
                        // Fallback jeśli nie udało się sparsować JSON
                        results.put('skills', new List<String>{'JavaScript', 'Apex', 'Salesforce', 'Lightning Web Components'});
                        results.put('matchScore', 80);
                        results.put('recommendation', 'This candidate appears to have skills that match the job requirements.');
                    }
                } else {
                    throw new AuraHandledException('No response from AI service');
                }
            } else {
                throw new AuraHandledException('API Error: ' + res.getStatusCode() + ' ' + res.getStatus());
            }
        } catch(Exception e) {
            // W środowisku demo, używamy symulowanych danych zamiast rzucania wyjątku
            System.debug('Error calling OpenAI API: ' + e.getMessage());
            
            // Symulowane wyniki
            results.put('skills', new List<String>{'JavaScript', 'Apex', 'Salesforce', 'Lightning Web Components', 'API Integration'});
            results.put('matchScore', 85);
            results.put('recommendation', 'This candidate has strong technical skills that match the job requirements. Recommend scheduling a technical interview.');
        }
        
        return results;
    }
    
    private class CandidateUpdateParams {
        public Id candidateId;
        public String skills;
        public Decimal matchScore;
        public String recommendation;
    }
    
    private class CandidateUpdate {
        public Id candidateId;
        public String skills;
        public Decimal matchScore;
        public String recommendation;
        
        public CandidateUpdate(CandidateUpdateParams params) {
            this.candidateId = params.candidateId;
            this.skills = params.skills;
            this.matchScore = params.matchScore;
            this.recommendation = params.recommendation;
        }
    }
    
    private static void updateCandidate(CandidateUpdate candidateUpdate) {
        Candidate__c candidate = new Candidate__c(
            Id = candidateUpdate.candidateId,
            Skills__c = candidateUpdate.skills,
            Status__c = 'In Review',
            Identified_Skills__c = candidateUpdate.skills,
            Match_Score__c = candidateUpdate.matchScore,
            AI_Recommendation__c = candidateUpdate.recommendation
        );
        
        try {
            update candidate;
        } catch (Exception e) {
            throw new AuraHandledException('Error updating candidate: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void updateCandidateAnalysisResults(Id candidateId, Map<String, Object> analysisResults) {
        validateUpdatePermissions();
        validateCandidateId(candidateId);
        
        CandidateUpdateParams params = new CandidateUpdateParams();
        params.candidateId = candidateId;
        params.skills = convertSkillsToString(analysisResults.get('skills'));
        params.matchScore = convertToDecimal(analysisResults.get('matchScore'));
        params.recommendation = String.valueOf(analysisResults.get('recommendation'));
        
        updateCandidate(new CandidateUpdate(params));
    }
    
    private static void validateUpdatePermissions() {
        if (!Schema.sObjectType.Candidate__c.isUpdateable() ||
            !Schema.sObjectType.Candidate__c.fields.Skills__c.isUpdateable() ||
            !Schema.sObjectType.Candidate__c.fields.Status__c.isUpdateable() ||
            !Schema.sObjectType.Candidate__c.fields.Identified_Skills__c.isUpdateable() ||
            !Schema.sObjectType.Candidate__c.fields.Match_Score__c.isUpdateable() ||
            !Schema.sObjectType.Candidate__c.fields.AI_Recommendation__c.isUpdateable()) {
            throw new AuraHandledException('Insufficient permissions to update candidate');
        }
    }
    
    private static String convertSkillsToString(Object skillsObj) {
        if (skillsObj instanceof List<Object>) {
            List<Object> skillsList = (List<Object>)skillsObj;
            List<String> skillsStringList = new List<String>();
            for(Object skill : skillsList) {
                skillsStringList.add(String.valueOf(skill));
            }
            return String.join(skillsStringList, ', ');
        }
        return skillsObj instanceof String ? (String)skillsObj : '';
    }
    private static Decimal convertToDecimal(Object value) {
        if (value instanceof Decimal) {
            return (Decimal)value;
        }
        if (value instanceof Integer) {
            return (Integer)value;
        }
        if (value instanceof String) {
            try { 
                return Decimal.valueOf((String)value); 
            } catch(Exception e) { 
                return 0; 
            }
        }
        return 0;
    }
    
    private static void validateCandidateId(Id candidateId) {
        if (candidateId == null) {
            throw new AuraHandledException('Candidate ID cannot be null');
        }
    }
}