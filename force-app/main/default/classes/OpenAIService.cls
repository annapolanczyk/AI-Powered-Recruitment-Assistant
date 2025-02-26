/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 02-26-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class OpenAIService {
    public static String getAPIKey() {
        OpenAI_Settings__c apiSettings = OpenAI_Settings__c.getInstance();
        if (apiSettings == null || String.isBlank(apiSettings.API_Key__c)) {
            throw new AuraHandledException('OpenAI API key is not configured');
        }
        return apiSettings.API_Key__c;
    }
    
    public static Map<String, Object> prepareAnalysisRequestBody(String cvText, String requiredSkills) {
        return new Map<String, Object>{
            'model' => 'gpt-4',
            'messages' => new List<Map<String, String>>{
                new Map<String, String>{
                    'role' => 'system',
                    'content' => 'You are an expert CV analyzer. Analyze if the candidate has the SPECIFIC required skills only. ' +
                                 'Return your response in VALID JSON format with these exact keys: ' +
                                 '{"skills": [], "matchScore": 0, "recommendation": ""}. ' +
                                 'Make sure your response is ONLY valid JSON without any text before or after.'
                },
                new Map<String, String>{
                    'role' => 'user',
                    'content' => 'Analyze this CV for skills: ' + requiredSkills + '\n\nCV:\n' + cvText
                }
            },
            'temperature' => 0.1
        };
    }
    
    @SuppressWarnings('PMD.ApexSuggestUsingNamedCred')
    public static HttpResponse sendRequest(Map<String, Object> requestBody, String apiKey) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.openai.com/v1/chat/completions');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + apiKey);
        req.setBody(JSON.serialize(requestBody));
        req.setTimeout(120000);
        
        return new Http().send(req);
    }
    
    public static void validateResponse(HttpResponse response) {
        if (response.getStatusCode() != 200) {
            throw new AuraHandledException('OpenAI API Error: ' + response.getStatusCode());
        }
    }
    
    public static Map<String, Object> extractContentFromResponse(HttpResponse response) {
        try {
            Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(response.getBody());
            Map<String, Object> message = (Map<String, Object>)((Map<String, Object>)((List<Object>)responseMap.get('choices'))[0]).get('message');
            String content = (String)message.get('content');
            
            // Dodaj debugowanie, aby zobaczyć co otrzymujemy
            System.debug(LoggingLevel.INFO, '>>> Response content: ' + content);
            
            // Obsłuż przypadek, gdy zawartość nie jest prawidłowym JSON
            try {
                return (Map<String, Object>)JSON.deserializeUntyped(content);
            } catch (JSONException je) {
                System.debug(LoggingLevel.ERROR, '>>> JSON parsing error: ' + je.getMessage());
                
                // Utworzenie standardowej odpowiedzi na wypadek błędu parsowania
                Map<String, Object> fallbackResponse = new Map<String, Object>{
                    'skills' => new List<String>(),
                    'matchScore' => 0,
                    'recommendation' => 'Could not analyze CV. Error parsing OpenAI response: ' + je.getMessage()
                };
                
                return fallbackResponse;
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '>>> Error processing OpenAI response: ' + e.getMessage());
            throw new AuraHandledException('Error processing OpenAI response: ' + e.getMessage());
        }
    }
} 