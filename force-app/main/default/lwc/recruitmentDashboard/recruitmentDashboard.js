import { LightningElement, wire } from 'lwc';
import getActiveJobs from '@salesforce/apex/JobService.getActiveJobs';
import calculateRecruitmentMetrics from '@salesforce/apex/RecruitmentHelper.calculateRecruitmentMetrics';

export default class RecruitmentDashboard extends LightningElement {
    metrics = {
        activeJobs: 0,
        totalCandidates: 0,
        conversionRate: 0
    };

    @wire(getActiveJobs)
    activeJobs;

    connectedCallback() {
        this.loadMetrics();
    }

    loadMetrics() {
        calculateRecruitmentMetrics()
            .then(result => {
                this.metrics = {
                    activeJobs: result.Active_Jobs || 0,
                    totalCandidates: result.Total_Candidates || 0,
                    conversionRate: result.Conversion_Rate || 0
                };
            })
            .catch(error => {
                console.error('Error loading metrics', error);
            });
    }

    viewJobDetails(event) {
        const jobId = event.currentTarget.dataset.jobId;
        // Implementacja nawigacji do szczegółów oferty pracy
        // Można użyć NavigationMixin lub EventBus
    }
}