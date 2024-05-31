import { LightningElement,api,track,wire } from 'lwc';
import FIRST_NAME from '@salesforce/schema/Grant_Application__c.First_Name__c';
import LAST_NAME from '@salesforce/schema/Grant_Application__c.Last_Name__c';
import PHONE_NUMBER from '@salesforce/schema/Grant_Application__c.Phone_Number__c';
import POSTAL_CODE from '@salesforce/schema/Grant_Application__c.Postal_Code__c';
import MONTHLY_INCOME from	'@salesforce/schema/Grant_Application__c.Monthly_Income__c';
import SUPPORT_OPTION from '@salesforce/schema/Grant_Application__c.Support_Option__c';

import {ShowToastEvent} from 'lightning/platformShowToastEvent';

import createGrantApplication from '@salesforce/apex/GrantApplicationController.createGrantApplication';
import getOptionsFromCMT from '@salesforce/apex/GrantApplicationController.getOptionsFromCMT';

export default class SupportApplicationForm extends LightningElement {
    @api objectApiName;
    @api recordId;
    selectedPicklistValue='';
    buttonFlag = true;
    @track incomeInvalidMessageflag = false;
    maxAllowedIncome = 2000
    errorMsg;

    searchPhoneKey;

    @track errorClass='';

    @track searchApplication = true;
    @track newApplication = true;

    ApplicantDetails={
        First_Name:FIRST_NAME,
        Last_Name:LAST_NAME,
        Phone:PHONE_NUMBER,
        Postal_Code:POSTAL_CODE,
        Monthly_Income:MONTHLY_INCOME,
        Support_Option:SUPPORT_OPTION
    }

    handlePhoneSearch(event){
        //call an apex class to check if phone number already exist in grant
        //application> if yes show pre existing data in a card and give user 
        //2 button 1) to update the data - this will redirect user to prefilled form
        //2) go back to landing page to search new phone
    }

    handleFirstName(event){
        this.ApplicantDetails.First_Name = event.target.value;
        if(this.checkFieldfValidity()){
            this.buttonFlag = false;
        }
        else{
            this.buttonFlag = true;

        }
    }

    handleLastName(event){
        this.ApplicantDetails.Last_Name = event.target.value;
        if(this.checkFieldfValidity()){
            this.buttonFlag = false;
        }
        else{
            this.buttonFlag = true;

        }
    }

    handlePhone(event){
        
        this.ApplicantDetails.Phone = event.target.value;
        if(this.checkFieldfValidity()){
            this.buttonFlag = false;
        }
        else{
            this.buttonFlag = true;

        }

    }
    

    handlePostalCode(event){
        this.ApplicantDetails.Postal_Code = event.target.value;
        if(this.checkFieldfValidity()){
            this.buttonFlag = false;
        }
        else{
            this.buttonFlag = true;

        }
    }

    handleMonthlyIncome(event){
        this.ApplicantDetails.Monthly_Income = event.target.value;
        if(this.checkFieldfValidity() && !(this.selectedPicklistValue==='')){
            if(this.ApplicantDetails.Monthly_Income<this.maxAllowedIncome){
            this.buttonFlag = false;}
            else{
                this.buttonFlag = true;
            }

        }
        else{
            this.buttonFlag = true;
        }

        if(this.ApplicantDetails.Monthly_Income>=this.maxAllowedIncome){
            this.incomeInvalidMessageflag = true;
           this.buttonFlag = true;
            this.errorClass='slds-has-error slds-p-around_xx-small';
        }
        else{
            this.incomeInvalidMessageflag = false;
            this.errorClass='';

        }
    }

    // monthlyIncomeCheck(value){
    //     if(value>=this.maxAllowedIncome){
    //         this.errorClass='slds-has-error';
    //         this.incomeInvalidMessageflag = true;

    //         return false
    //     }
    //     else{
    //         this.errorClass='';

    //         this.incomeInvalidMessageflag = false;
    //         return true
    //     }
    // }

    options = [];
    @wire(getOptionsFromCMT)
    wiredOptions({ error, data }) {
        if (data) {
            this.options = data;
        } else if (error) {
            console.error('Error fetching options:', error);
        }
    }

    handleSupportOptionChange(event) {
        this.selectedPicklistValue = event.detail.value;
        this.ApplicantDetails.Support_Option = event.detail.value;
        if(this.checkFieldfValidity() && !(this.selectedPicklistValue==='') && this.ApplicantDetails.Monthly_Income<this.maxAllowedIncome ){
            this.buttonFlag = false;
        }
        else{
            this.buttonFlag = true;

        }
    }

    fields = [FIRST_NAME,LAST_NAME,PHONE_NUMBER,POSTAL_CODE,MONTHLY_INCOME,SUPPORT_OPTION];

    handleSubmit(){
        createGrantApplication({
            FirstName:this.ApplicantDetails.First_Name,
            LastName:this.ApplicantDetails.Last_Name,
            Phone:this.ApplicantDetails.Phone,
            PostalCode:this.ApplicantDetails.Postal_Code,
            MonthlyIncome:this.ApplicantDetails.Monthly_Income,
            SupportOption:this.ApplicantDetails.Support_Option
        })
        .then((result)=>{
            console.log('Applicant Details Object **** '+JSON.stringify(this.ApplicantDetails));
            const toastevent = new ShowToastEvent({
                title : 'Grant Application Submitted',
                message : 'Application for '+this.ApplicantDetails.First_Name +' is created successfully.',
                variant : 'success'
            });
            this.dispatchEvent(toastevent);
        })
        .catch((error)=>{
            this.handleErrors(error);
            const toastevent = new ShowToastEvent({
                title: 'Error',
                message: 'Error while submitting application :'+this.errorMsg,
                variant: 'error'
            });
            this.dispatchEvent(toastevent);

        })
    }

    handleErrors(err){
        if(Array.isArray(err.body)){
            this.errorMsg = err.body.map(e=>e.message).join(', ');
        }
        else if(typeof err.body.message==='string'){
            this.errorMsg = err.body.message;
        }
    }

    checkFieldfValidity(){
        var isInputsCorrect = [...this.template.querySelectorAll("lightning-input")].reduce((validSoFar,inputField)=>{
            inputField.validity.valid;
            return validSoFar && inputField.validity.valid;
        },true);
        return isInputsCorrect;
    }

}