import { LightningElement, api, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import analyzeCV from "@salesforce/apex/CandidateService.analyzeCV";
import updateCandidateAnalysisResults from "@salesforce/apex/CandidateService.updateCandidateAnalysisResults";

export default class CvAnalyzer extends LightningElement {
    @api recordId;
    @api candidateId;
    
    @track isLoading = false;
    @track analysisResults;
    @track uploadedFile;
    @track contentDocumentId;
    
    get isAnalyzeDisabled() {
        return !this.contentDocumentId;
    }
    
    get effectiveRecordId() {
        return this.recordId || this.candidateId;
    }
    
    handleFileUpload(event) {
        if (event.target.files.length > 0) {
            this.uploadedFile = event.target.files[0];
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "File Selected",
                    message: `File "${this.uploadedFile.name}" selected`,
                    variant: "info"
                })
            );
            
            // Przy użyciu standardowych komponentów lightning-input type="file",
            // plik zostanie automatycznie powiązany z rekordem przez ContentDocumentLink
            // Teraz należy pobrać ContentDocumentId tego pliku
            this.getLatestFile();
        }
    }
    
    getLatestFile() {
        // Ta metoda jest wywoływana w setTimeout, aby dać czas na przetworzenie pliku
        // Alternatywnie, możesz użyć EventListener na zdarzenie FILES_ATTACHED_TO_RECORD
        setTimeout(() => {
            // W rzeczywistej implementacji należałoby pobrać ContentDocumentId
            // za pomocą apex. W tej wersji demo zakładamy, że mamy ID.
            this.contentDocumentId = 'simulatedDocumentId';
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "File Ready",
                    message: "File ready for analysis",
                    variant: "success"
                })
            );
        }, 1000);
    }
    
    analyzeCV() {
        if (!this.effectiveRecordId || !this.contentDocumentId) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Error",
                    message: "Candidate ID and file are required",
                    variant: "error"
                })
            );
            return;
        }
        
        this.isLoading = true;
        this.analysisResults = null;
        
        // W środowisku demo, symulujemy wywołanie API
        if (this.contentDocumentId === 'simulatedDocumentId') {
            setTimeout(() => {
                this.simulateAnalysisResults();
            }, 2000);
            return;
        }
        
        // W rzeczywistej implementacji wywołujemy API
        analyzeCV({
            candidateId: this.effectiveRecordId,
            fileId: this.contentDocumentId
        })
        .then(result => {
            this.analysisResults = result;
            this.isLoading = false;
            
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Analysis Complete",
                    message: "CV analysis completed successfully",
                    variant: "success"
                })
            );
        })
        .catch(error => {
            this.isLoading = false;
            console.error('Error analyzing CV', error);
            
            // W demo, symulujemy wyniki nawet w przypadku błędu
            this.simulateAnalysisResults();
            
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Demo Mode",
                    message: "Using simulated results (error occurred in API call)",
                    variant: "warning"
                })
            );
        });
    }
    
    simulateAnalysisResults() {
        this.analysisResults = {
            skills: ["JavaScript", "Apex", "Salesforce", "Lightning Web Components", "API Integration"],
            matchScore: 85,
            recommendation: "This candidate has strong technical skills that match the job requirements. Recommend scheduling a technical interview."
        };
        
        this.isLoading = false;
    }
    
    saveResults() {
        if (!this.analysisResults || !this.effectiveRecordId) {
            return;
        }
        
        this.isLoading = true;
        
        // Przygotowanie danych do zapisu
        const resultsMap = {
            skills: this.analysisResults.skills,
            matchScore: this.analysisResults.matchScore,
            recommendation: this.analysisResults.recommendation
        };
        
        // Zapisz wyniki
        updateCandidateAnalysisResults({
            candidateId: this.effectiveRecordId,
            analysisResults: resultsMap
        })
        .then(() => {
            this.isLoading = false;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Success",
                    message: "Analysis results saved to candidate record",
                    variant: "success"
                })
            );
        })
        .catch(error => {
            this.isLoading = false;
            console.error('Error saving results', error);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Error",
                    message: "Error saving results: " + (error.body ? error.body.message : error.message),
                    variant: "error"
                })
            );
        });
    }
}