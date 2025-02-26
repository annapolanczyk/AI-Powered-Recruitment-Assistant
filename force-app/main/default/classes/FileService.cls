/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 02-26-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class FileService {
    @AuraEnabled(cacheable=false)
    public static List<ContentDocumentLink> getRecentFiles(Id recordId, Integer maxFiles) {
        try {
            // Dodaj debugowanie, aby zobaczyć wartości wejściowe
            System.debug(LoggingLevel.ERROR, 'getRecentFiles - recordId: ' + recordId);
            System.debug(LoggingLevel.ERROR, 'getRecentFiles - maxFiles: ' + maxFiles);
            
            if(recordId == null) {
                System.debug(LoggingLevel.ERROR, 'getRecentFiles - Error: Record ID is null');
                throw new AuraHandledException('Record ID is required');
            }
            
            // Sprawdź uprawnienia
            if(!Schema.sObjectType.ContentDocumentLink.isAccessible() ||
               !Schema.sObjectType.ContentDocument.isAccessible()) {
                System.debug(LoggingLevel.ERROR, 'getRecentFiles - Error: Insufficient permissions');
                throw new SecurityException('Insufficient permissions to access files');
            }
            
            // Sprawdź czy rekord istnieje i czy to kandydat
            String sObjectType = recordId.getSObjectType().getDescribe().getName();
            System.debug(LoggingLevel.ERROR, 'getRecentFiles - Record type: ' + sObjectType);
            
            // Pobierz wszystkie pliki, nie tylko najnowsze
            List<ContentDocumentLink> allLinks = [
                SELECT Id, ContentDocumentId, ContentDocument.Title, 
                       ContentDocument.FileExtension, ContentDocument.ContentSize,
                       ContentDocument.CreatedDate
                FROM ContentDocumentLink 
                WHERE LinkedEntityId = :recordId
                ORDER BY ContentDocument.CreatedDate DESC
            ];
            
            System.debug(LoggingLevel.ERROR, 'getRecentFiles - All files found: ' + allLinks.size());
            for(ContentDocumentLink link : allLinks) {
                System.debug(LoggingLevel.ERROR, 'File: ' + link.ContentDocument.Title);
            }
            
            return allLinks;
            
        } catch(Exception e) {
            System.debug(LoggingLevel.ERROR, 'getRecentFiles - Unexpected error: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'getRecentFiles - Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error accessing files: ' + e.getMessage());
        }
    }

    public class FileUploadRequest {
        @AuraEnabled public String recordId { get; set; }
        @AuraEnabled public String fileName { get; set; }
        @AuraEnabled public String base64Data { get; set; }
        @AuraEnabled public String contentType { get; set; }
    }
    
    @AuraEnabled
    public static Id uploadFile(FileUploadRequest request) {
        System.debug(LoggingLevel.ERROR, '>>> VERY FIRST LINE');
        
        try {
            // Zabezpieczenie przed null requestem
            if (request == null) {
                throw new AuraHandledException('Upload request cannot be null');
            }
            
            // Walidacja wymaganych pól
            if (String.isBlank(request.recordId) || String.isBlank(request.fileName) || String.isBlank(request.base64Data)) {
                throw new AuraHandledException('Required fields missing: recordId, fileName, and base64Data must be provided');
            }
            
            // Sprawdź uprawnienia CRUD
            if (!Schema.sObjectType.ContentVersion.isCreateable() ||
                !Schema.sObjectType.ContentDocumentLink.isCreateable()) {
                throw new SecurityException('Insufficient permissions to create files');
            }
            
            // Podstawowa walidacja
            if(String.isBlank(request.base64Data) || String.isBlank(request.fileName)) {
                throw new AuraHandledException('File data and name are required');
            }
            
            // Walidacja typu pliku
            Set<String> allowedExtensions = new Set<String>{'pdf', 'doc', 'docx'};
            String fileExtension = request.fileName.substringAfterLast('.').toLowerCase();
            
            if(!allowedExtensions.contains(fileExtension)) {
                throw new AuraHandledException('Invalid file type. Only PDF, DOC and DOCX files are allowed.');
            }
            
            // Walidacja rozmiaru (opcjonalnie)
            Integer maxSizeInMB = 5; // 5MB limit
            if(request.base64Data.length() > maxSizeInMB * 1024 * 1024 * 4/3) { // 4/3 to przybliżony współczynnik base64
                throw new AuraHandledException('File size exceeds ' + maxSizeInMB + 'MB limit');
            }
            
            ContentVersion cv = new ContentVersion();
            cv.VersionData = EncodingUtil.base64Decode(request.base64Data);
            cv.Title = request.fileName;
            cv.PathOnClient = request.fileName;
            insert cv;
            
            cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
            
            ContentDocumentLink cdl = new ContentDocumentLink(
                ContentDocumentId = cv.ContentDocumentId,
                LinkedEntityId = request.recordId,
                ShareType = 'V',
                Visibility = 'AllUsers'
            );
            insert cdl;
            
            return cv.ContentDocumentId;
        } catch(Exception e) {
            System.debug(LoggingLevel.ERROR, '>>> CAUGHT EXCEPTION: ' + e.getMessage());
            throw new AuraHandledException('Error in uploadFile: ' + e.getMessage());
        }
    }

    /**
     * Pobiera najnowszy dokument dla danego rekordu
     */
    public static Id getLatestDocumentIdForEntity(Id entityId) {
        if (!Schema.sObjectType.ContentDocumentLink.isAccessible() || entityId == null) {
            return null;
        }
        
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :entityId 
            ORDER BY ContentDocument.CreatedDate DESC 
            LIMIT 1
        ];
        
        return !links.isEmpty() ? links[0].ContentDocumentId : null;
    }
}