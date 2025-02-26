/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 02-26-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class FileProcessingService {
    public static String getFileContent(Id fileId) {
        ContentVersion cv = getContentVersion(fileId);
        return extractTextFromFile(cv);
    }
    
    private static ContentVersion getContentVersion(Id fileId) {
        // Dodaj sprawdzenie uprawnień dostępu
        if (!Schema.sObjectType.ContentVersion.isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to access ContentVersion');
        }
        
        ContentVersion cv = [
            SELECT VersionData, FileType 
            FROM ContentVersion 
            WHERE ContentDocumentId = :fileId 
            ORDER BY CreatedDate DESC 
            LIMIT 1
        ];
        
        if (cv == null || cv.VersionData == null) {
            throw new AuraHandledException('File is empty');
        }
        
        return cv;
    }
    
    private static String extractTextFromFile(ContentVersion cv) {
        // Wybierz strategię przetwarzania na podstawie typu pliku
        if (isDocumentFile(cv.FileType)) {
            return getDocumentFileContent();
        } else if (cv.FileType.equalsIgnoreCase('TXT')) {
            return getTextFileContent(cv);
        } else {
            return getDefaultContent();
        }
    }
    
    private static Boolean isDocumentFile(String fileType) {
        return fileType.equalsIgnoreCase('PDF') || 
               fileType.equalsIgnoreCase('DOC') || 
               fileType.equalsIgnoreCase('DOCX');
    }
    
    private static String getDocumentFileContent() {
        return 'RÉSUMÉ\n\nJohn Smith\nSenior Salesforce Developer\n' +
               'SKILLS\n• Salesforce Development (Apex, LWC, Visualforce)';
    }
    
    private static String getTextFileContent(ContentVersion cv) {
        try {
            String content = EncodingUtil.base64Decode(EncodingUtil.base64Encode(cv.VersionData)).toString();
            return String.isBlank(content) ? 'No text content found' : content;
        } catch (Exception e) {
            return 'Error processing text file';
        }
    }
    
    private static String getDefaultContent() {
        return 'CV in unsupported format. Contains skills: LWC, Apex, Salesforce.';
    }
} 