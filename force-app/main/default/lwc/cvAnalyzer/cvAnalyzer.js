import { LightningElement, api, track, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { getRecord } from "lightning/uiRecordApi";
import getRecentFiles from "@salesforce/apex/FileService.getRecentFiles";
import analyzeCV from "@salesforce/apex/CandidateService.analyzeCV";
import updateCandidateAnalysisResults from "@salesforce/apex/CandidateService.updateCandidateAnalysisResults";
import uploadFile from '@salesforce/apex/FileService.uploadFile';
import FIRST_NAME_FIELD from '@salesforce/schema/Candidate__c.First_Name__c';
import LAST_NAME_FIELD from '@salesforce/schema/Candidate__c.Last_Name__c';
import JOB_FIELD from '@salesforce/schema/Candidate__c.Job__c';

export default class CvAnalyzer extends LightningElement {
    @api recordId;
    @api candidateId;
    
    @track isLoading = false;
    @track analysisResults;
    @track uploadedFileId;
    @track contentDocumentId;
    @track skillsList = [];
    @track matchScore = 0;
    @track recommendation = '';
    @track hasResults = false;
    
    @wire(getRecord, { 
        recordId: '$effectiveRecordId', 
        fields: [FIRST_NAME_FIELD, LAST_NAME_FIELD, JOB_FIELD] 
    })
    candidateRecord;

    get isCandidateValid() {
        console.log('Checking candidate validity, data:', this.candidateRecord?.data);
        return this.candidateRecord?.data?.fields?.First_Name__c?.value && 
               this.candidateRecord?.data?.fields?.Last_Name__c?.value &&
               this.candidateRecord?.data?.fields?.Job__c?.value;
    }
    
    get isAnalyzeDisabled() {
        return !this.uploadedFileId;
    }
    
    get effectiveRecordId() {
        return this.recordId || this.candidateId;
    }
    
    connectedCallback() {
        console.log('CV Analyzer initialized with:', {
            recordId: this.recordId,
            candidateId: this.candidateId,
            effectiveRecordId: this.effectiveRecordId
        });
    }
    
    handleUploadFinished(event) {
        if (event.detail.files && event.detail.files.length > 0) {
            this.uploadedFileId = event.detail.files[0].documentId;
            this.showToast('Success', 'File uploaded successfully', 'success');
        }
    }
    
    handleAnalyzeCV() {
        if (!this.effectiveRecordId || !this.uploadedFileId) {
            this.showToast('Error', 'Missing candidate ID or file', 'error');
            return;
        }
        
        this.isLoading = true;
        this.hasResults = false;
        
        analyzeCV({ candidateId: this.effectiveRecordId, fileId: this.uploadedFileId })
            .then(result => {
                this.analysisResults = result;
                this.processResults(result);
                this.hasResults = true;
                this.showToast('Success', 'CV analysis completed', 'success');
            })
            .catch(error => {
                this.showToast('Error', 'CV analysis failed: ' + this.getErrorMessage(error), 'error');
                console.error('CV analysis error', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    
    processResults(results) {
        // Process skills
        if (results.skills && Array.isArray(results.skills)) {
            this.skillsList = results.skills.map(skill => typeof skill === 'string' ? skill : JSON.stringify(skill));
        } else if (typeof results.skills === 'string') {
            this.skillsList = results.skills.split(',').map(skill => skill.trim());
        } else {
            this.skillsList = [];
        }
        
        // Process match score
        this.matchScore = typeof results.matchScore === 'number' ? 
            Math.round(results.matchScore) : 
            (parseInt(results.matchScore) || 0);
        
        // Process recommendation
        this.recommendation = results.recommendation || '';
    }
    
    handleSaveResults() {
        if (!this.effectiveRecordId || !this.analysisResults) {
            this.showToast('Error', 'No results to save', 'error');
            return;
        }
        
        this.isLoading = true;
        
        updateCandidateAnalysisResults({ 
            candidateId: this.effectiveRecordId, 
            analysisResults: this.analysisResults 
        })
            .then(() => {
                this.showToast('Success', 'Analysis results saved to candidate record', 'success');
            })
            .catch(error => {
                this.showToast('Error', 'Failed to save results: ' + this.getErrorMessage(error), 'error');
                console.error('Save error', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
    
    getErrorMessage(error) {
        return (error.body && error.body.message) ? error.body.message : 
               (error.message ? error.message : 'Unknown error');
    }
    
    getLatestFile() {
        // Pobieramy najnowszy plik powiązany z rekordem kandydata
        // Uwaga: Musisz utworzyć klasę FileService z metodą getRecentFiles
        getRecentFiles({
            recordId: this.effectiveRecordId,
            maxFiles: 1
        })
        .then(files => {
            if (files && files.length > 0) {
                this.contentDocumentId = files[0].ContentDocumentId;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: "File Ready",
                        message: "File ready for analysis",
                        variant: "success"
                    })
                );
            } else {
                this.contentDocumentId = null;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: "Warning",
                        message: "No files found. Please upload a file first.",
                        variant: "warning"
                    })
                );
            }
        })
        .catch(error => {
            console.error('Error retrieving files', error);
            this.contentDocumentId = null;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Error",
                    message: "Error retrieving files: " + (error.body ? error.body.message : error.message),
                    variant: "error"
                })
            );
        });
    }

    get progressStyle() {
        return `width: ${this.matchScore}%;`;
    }

    get acceptedFormats() {
        return ['.pdf', '.doc', '.docx', '.txt'];
    }

    renderedCallback() {
        console.log('CV Analyzer rendered:', {
            uploadedFileId: this.uploadedFileId,
            hasResults: this.hasResults
        });
        
        if (this.hasResults) {
            const progressBar = this.template.querySelector('.progress-fill');
            if (progressBar) {
                progressBar.style.width = `${this.matchScore}%`;
            }
        }
    }

    triggerFileUpload() {
        const fileInput = this.template.querySelector('lightning-file-upload');
        if (fileInput) {
            fileInput.click();
        }
    }
}