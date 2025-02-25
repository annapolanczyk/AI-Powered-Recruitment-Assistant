import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import FIRST_NAME_FIELD from '@salesforce/schema/Candidate__c.First_Name__c';
import LAST_NAME_FIELD from '@salesforce/schema/Candidate__c.Last_Name__c';
import EMAIL_FIELD from '@salesforce/schema/Candidate__c.Email__c';
import STATUS_FIELD from '@salesforce/schema/Candidate__c.Status__c';

export default class CandidateDetails extends LightningElement {
    @api recordId;

    @wire(getRecord, { 
        recordId: '$recordId', 
        fields: [FIRST_NAME_FIELD, LAST_NAME_FIELD, EMAIL_FIELD, STATUS_FIELD] 
    })
    candidate;

    get candidateName() {
        return getFieldValue(this.candidate.data, FIRST_NAME_FIELD) + ' ' + 
               getFieldValue(this.candidate.data, LAST_NAME_FIELD);
    }
}