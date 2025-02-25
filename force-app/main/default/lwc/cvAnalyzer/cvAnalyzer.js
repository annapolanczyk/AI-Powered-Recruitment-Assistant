import { LightningElement, api, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class CvAnalyzer extends LightningElement {
    @api recordId;
    @api candidateId;
    
    @track isLoading = false;
    @track analysisResults;
    @track uploadedFile;
    
    get isAnalyzeDisabled() {
        return !this.uploadedFile;
    }
    
    handleFileUpload(event) {
        const file = event.target.files[0];
        if (file) {
            this.uploadedFile = file;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "File Ready",
                    message: "File \"" + file.name + "\" ready for analysis",
                    variant: "success"
                })
            );
        }
    }
    
    analyzeCV() {
        if (!this.uploadedFile) return;
        
        this.isLoading = true;
        this.analysisResults = null;
        
        // Simulate AI analysis response
        setTimeout(() => {
            this.analysisResults = {
                skills: ["JavaScript", "Apex", "Salesforce", "Lightning Web Components", "API Integration"],
                matchScore: 85,
                recommendation: "This candidate has strong technical skills that match the job requirements. Recommend scheduling a technical interview."
            };
            
            this.isLoading = false;
            
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Analysis Complete",
                    message: "CV analysis completed successfully",
                    variant: "success"
                })
            );
        }, 2000); // Simulate 2 second processing time
    }
    
    saveResults() {
        if (!this.analysisResults) return;
        
        // For demo purposes, we will just show a success message
        this.dispatchEvent(
            new ShowToastEvent({
                title: "Results Saved",
                message: "Analysis results saved to candidate record",
                variant: "success"
            })
        );
    }
}