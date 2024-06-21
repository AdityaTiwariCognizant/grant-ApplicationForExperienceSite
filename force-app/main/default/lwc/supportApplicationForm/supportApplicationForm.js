import { LightningElement,api,track,wire } from 'lwc';
import FIRST_NAME from '@salesforce/schema/Grant_Application__c.First_Name__c';
import LAST_NAME from '@salesforce/schema/Grant_Application__c.Last_Name__c';
import PHONE_NUMBER from '@salesforce/schema/Grant_Application__c.Phone_Number__c';
import POSTAL_CODE from '@salesforce/schema/Grant_Application__c.Postal_Code__c';
import MONTHLY_INCOME from	'@salesforce/schema/Grant_Application__c.Monthly_Income__c';
import SUPPORT_OPTION from '@salesforce/schema/Grant_Application__c.Support_Option__c';

import {ShowToastEvent} from 'lightning/platformShowToastEvent';

import ToastContainer from 'lightning/toastContainer';

import Toast from 'lightning/toast';


import createGrantApplication from '@salesforce/apex/GrantApplicationController.createGrantApplication';
import getOptionsFromCMT from '@salesforce/apex/GrantApplicationController.getOptionsFromCMT';
import searchPhoneInGrantApplication from '@salesforce/apex/GrantApplicationController.searchPhoneInGrantApplication';


export default class SupportApplicationForm extends LightningElement {

    @api flexipageRegionWidth;

    @api objectApiName;
    @api recordId;
    selectedPicklistValue='';
    buttonFlag = true;
    @track incomeInvalidMessageflag = false;
    maxAllowedIncome = 2000
    errorMsg;
    @track buttonFlag2 = true;
    @track toastMessageType = 'updated';

    searchPhoneKey;


    @track editMessage = true;

    @track errorClass='';

    @track searchApplication = true;
    @track newApplication = false;

    @track regretMessageFlag = false;

    @track showExistingApplication = false;

    ApplicantDetails={
        First_Name:FIRST_NAME,
        Last_Name:LAST_NAME,
        Phone:PHONE_NUMBER,
        Postal_Code:POSTAL_CODE,
        Monthly_Income:MONTHLY_INCOME,
        Support_Option:SUPPORT_OPTION
    }


    @track existingApplication={
        FirstName:'',
        LastName:'',
        Phone:'',
        PostalCode:'',
        MonthlyIncome:'',
        SupportOption:''
    }

    handlecreateAppButtn(){
        this.searchApplication = false;
        this.newApplication = true;
        this.regretMessageFlag = false;
        this.existingApplication.FirstName = '';
        this.existingApplication.LastName = '';
        this.existingApplication.Phone = '';
        this.existingApplication.PostalCode = '';
        this.existingApplication.MonthlyIncome = '';
        this.existingApplication.SupportOption = '';

        this.ApplicantDetails.First_Name = '';
        this.ApplicantDetails.Last_Name = '';
        this.ApplicantDetails.Phone = '';
        this.ApplicantDetails.Postal_Code = '';
        this.ApplicantDetails.Monthly_Income = '';
        this.ApplicantDetails.Support_Option = '';
        this.selectedPicklistValue = '';

        this.showExistingApplication = false;
        this.toastMessageType = 'created';
    }

    handlePhoneSearch(event){
        //call an apex class to check if phone number already exist in grant
        //application> if yes show pre existing data in a card and give user 
        //2 button 1) to update the data - this will redirect user to prefilled form
        //2) go back to landing page to search new phone
        this.searchPhoneKey = event.target.value;
        

    }

        handlePhoneSearchSubmit(){

            if(!this.checkPhoneValidity()){
                Toast.show({
                    label : 'Invalid Phone Number Entered',
                    message : 'Phone number '+this.searchPhoneKey+' is invalid, please enter phone number in correct format.',
                    variant:'error',
                    mode:'dismissible'
                    
                })
                return;
            }

        searchPhoneInGrantApplication({
           
            Phone:this.searchPhoneKey
           
        })
        .then((result)=>{

            
            console.log(result);
            console.log(JSON.stringify(result));
            this.existingApplication.FirstName = result[0].First_Name__c;
            this.existingApplication.LastName = result[0].Last_Name__c;
            this.existingApplication.Phone = result[0].Phone_Number__c;
            this.existingApplication.PostalCode = result[0].Postal_Code__c;
            this.existingApplication.MonthlyIncome = result[0].Monthly_Income__c;
            this.existingApplication.SupportOption = result[0].Support_Option__c;

            this.showExistingApplication = true;
            this.regretMessageFlag = false;
            // this.searchApplication=false;
            this.toastMessageType='updated';

            })
        .catch((error)=>{
            
            this.regretMessageFlag = true;
            this.showExistingApplication=false;
            this.existingApplication.FirstName='';
            this.existingApplication.LastName='';
            this.existingApplication.Phone='';
            this.existingApplication.PostalCode='';
            this.existingApplication.MonthlyIncome='';
            this.existingApplication.SupportOption='';
            console.log('error occured');
            this.toastMessageType='created';


            // const toastevent = new ShowToastEvent({
            //     title : 'Grant Application does not exist',
            //     message : 'Application for phone number '+this.searchPhoneKey +' does not exist.',
            //     variant : 'error'
            // });
            // this.dispatchEvent(toastevent);
            
            Toast.show({
                label : 'Grant Application does not exist',
                message : 'Application for phone number '+this.searchPhoneKey +' does not exist,click Create Application to Register',
                variant:'error',
                mode:'dismissible'
                
            })

        })
        this.editMessage = true;
        this.searchApplication = true;
        this.toastMessageType = 'created';
    }

    handleSearchPhoneClearBtn(){
        this.searchPhoneKey = '';
        this.existingApplication.FirstName='';
        this.existingApplication.LastName='';
        this.existingApplication.Phone='';
        this.existingApplication.PostalCode = '';
        this.existingApplication.MonthlyIncome = '';
        this.existingApplication.SupportOption='';
        this.showExistingApplication = false;
        this.regretMessageFlag = false;

    }

    handleBackBtn(){
        this.newApplication = false;
        this.searchApplication = true;
        this.searchPhoneKey = '';
        this.showExistingApplication = false;
        this.regretMessageFlag = false;

    }

    handleEditApplication(){
        this.searchApplication = false;
        this.newApplication = true;
        this.regretMessageFlag = false;

        this.editMessage = false;

        //update the object with existing one
        this.ApplicantDetails.First_Name = this.existingApplication.FirstName;
        this.ApplicantDetails.Last_Name = this.existingApplication.LastName;
        this.ApplicantDetails.Phone = this.existingApplication.Phone;
        this.ApplicantDetails.Postal_Code = this.existingApplication.PostalCode;
        this.ApplicantDetails.Monthly_Income = this.existingApplication.MonthlyIncome;
        this.ApplicantDetails.Support_Option = this.existingApplication.SupportOption;
        this.selectedPicklistValue = this.existingApplication.SupportOption;
        this.toastMessageType = 'updated';
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

    options = [];
    @wire(getOptionsFromCMT)
    wiredOptions({ error, data }) {
        if (data) {
            console.log('Data Custom Metadata Type: '+JSON.stringify(data));
            this.options = data;
            console.log('Options for Combobox : '+JSON.stringify(this.options));

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
            // const toastevent = new ShowToastEvent({
            //     title : 'Grant Application Submitted',
            //     message : 'Application for '+this.ApplicantDetails.First_Name +' is '+this.toastMessageType+' successfully.',
            //     variant : 'success'
            // });
            //this.dispatchEvent(toastevent);

            //success toast that will show up on LWR here
            Toast.show({
                
                label : 'Grant Application Submitted',
                title : 'Grant Application Submitted',
                message : 'Application for '+this.ApplicantDetails.First_Name +' is '+this.toastMessageType+' successfully.',
                variant : 'success',
                mode : 'dismissible'

            })

        this.newApplication = false;
        this.searchApplication = true;
        
        this.existingApplication.FirstName = '';
        this.existingApplication.LastName = '';
        this.existingApplication.Phone = '';
        this.existingApplication.PostalCode = '';
        this.existingApplication.MonthlyIncome = ''; 
        this.existingApplication.SupportOption = ''; 

        this.ApplicantDetails.First_Name='';
        this.ApplicantDetails.Last_Name='';
        this.ApplicantDetails.Phone='';
        this.ApplicantDetails.Postal_Code='';
        this.ApplicantDetails.Monthly_Income='';
        this.ApplicantDetails.Support_Option='';

        

        this.showExistingApplication = false;

        this.searchPhoneKey='';
        })
        .catch((error)=>{
            this.handleErrors(error);
            // const toastevent = new ShowToastEvent({
            //     title: 'Error',
            //     message: 'Error while submitting application :'+this.errorMsg,
            //     variant: 'error'
            // });
            // this.dispatchEvent(toastevent);

            //error toast that will show up on LWR here
            Toast.show({
                title: 'Error',
                message: 'Error while submitting application :'+this.errorMsg,
                variant: 'error',
                mode:'dismissable'
            })

        })

       
    }


    handleNewAppCancelBtn(){
        this.newApplication = false;
        this.searchApplication = true;
        
        this.existingApplication.FirstName = '';
        this.existingApplication.LastName = '';
        this.existingApplication.Phone = '';
        this.existingApplication.PostalCode = '';
        this.existingApplication.MonthlyIncome = ''; 
        this.existingApplication.SupportOption = ''; 
        

        this.showExistingApplication = false;

        this.searchPhoneKey='';
        this.toastMessageType = '';
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

    checkPhoneValidity(){
        var pattern = /^\d{2}\d{10}$/;
        
        if(!this.searchPhoneKey){
            console.log('Phone key blank')
            return false;
            
        }

        if(pattern.test(this.searchPhoneKey)){
            console.log('Phone key valid');
            return true;

        }
        else{
            console.log('Phone key invalid');

            return false;
        }
        }
    

}