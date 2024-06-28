/*
*********************************************************
Apex Class Name    : GrantApplicationController
Created Date       : May 10, 2024
@description       : This is class is used for handling operations like : 
                     creating,updating of Grant Applications and related Objects
                     from an LWC component residing on Experience Site

@author            : Aditya Tiwari
Modification Log:
Ver   Date         Author                               Modification

*********************************************************
*/
public without sharing class GrantApplicationController {
    
    private static final Integer MAX_ELIGIBLE_INCOME = 2000;
    public static Id currentUserId = UserInfo.getUserId();

    public static string grantContactId;
    public static string updateGrantContactId;
    public static string updateGrantApplicationId;
    
    //storing custom metadata records
    public static List<Grant_Application_Params__mdt> customMDTList = [
                                                                        SELECT  
                                                                            Label,Amount_each_month__c,  
                                                                            Months_of_grant__c  
                                                                        FROM Grant_Application_Params__mdt  
                                                                        WITH USER_MODE 
                                                                       ];
    
    // map with label,records of custom metadata - required to create grant disbursed records                                                              
    public static Map<String,Grant_Application_Params__mdt> mdtMap = prepareCustomMetadata();
    
    
    
   

/*
*********************************************************
@Method Name    : prepareCustomMetadata
@author         : Aditya Tiwari
@description    : Method that will return label,metadata pair as map (used to populate mdtMap Map)
@param          : None
@return         : Map<String, Grant_Application_Params__mdt
********************************************************
*/
    public static Map<String, Grant_Application_Params__mdt> prepareCustomMetadata() {
        
        Map<String, Grant_Application_Params__mdt> tempMetaDataMap = new Map<String, Grant_Application_Params__mdt>(
                                                                                                                    [
                                                                                                                    SELECT 
                                                                                                                        Label,Amount_each_month__c, 
                                                                                                                        Months_of_grant__c 
                                                                                                                    FROM Grant_Application_Params__mdt 
                                                                                                                    WITH USER_MODE
                                                                                                                    ]
                                                                                                                    );
                                                                                                        
            Map<String, Grant_Application_Params__mdt> returnToMdtMap = new Map<String,Grant_Application_Params__mdt>();
            for(String key:tempMetaDataMap.keySet()){
                String label = 'SGD '+tempMetaDataMap.get(key).Amount_each_month__c+' per month for '+tempMetaDataMap.get(key).Months_of_grant__c +' months';
                
                returnToMdtMap.put(label,tempMetaDataMap.get(key));
            }
            return returnToMdtMap;
        }
        
/*
*********************************************************
@Method Name    : calculateDisbursalDate
@author         : Aditya Tiwari
@description    : This method returns date for first day of immediate next month from current month
@param          : None
@return         : Date
********************************************************
*/
    public static Date calculateDisbursalDate(){
        Date currentDate = Date.today();
            
        Integer nextMonth;
        Integer nextYear;
            
        if (currentDate.month() == 12) {
            nextMonth = 1;
            nextYear = currentDate.year() + 1;
        } else {
            nextMonth = currentDate.month() + 1;
            nextYear = currentDate.year();
        }
        return Date.newInstance(nextYear, nextMonth, 1);
    }
        
/*
*********************************************************
@Method Name    : createGrantApplication
@author         : Aditya Tiwari
@description    : Based on the fact that phone parameter already exist or not 
                  for Phone parameter matching in Contact field; This method will
                  create a new Grant Application and contact record with related
                  Grant Disbursed records
                  If its an update with changing values, there are calculations 
                  on remaining months as well as remaining grant amount that needs
                  to disbursed in the upcoming time
@param          : FirstName 
@param          : LastName
@param          : Phone
@param          : Postal Code
@param          : MonthlyIncome
@param          : Support Option
@return         : None
********************************************************
*/
    @AuraEnabled(cacheable=false)
    public static void createGrantApplication(String FirstName,String LastName,String Phone,Decimal PostalCode,Decimal MonthlyIncome,String SupportOption) {
        try{
            // Finding metadata with the matching label of support option
            List<Grant_Application_Params__mdt> supportOptionCustomMetadata = [
                                                                                SELECT 
                                                                                   label,Amount_each_month__c,
                                                                                   Months_of_grant__c 
                                                                                FROM Grant_Application_Params__mdt 
                                                                                WHERE label= :SupportOption 
                                                                                WITH USER_MODE
                                                                              ];
            //Finding if Phone number is already present over Grant Application and Contact records
            List<List<sObject>> searchPhoneinContactAndGrantApplication = [FIND :Phone IN PHONE FIELDS
                RETURNING Contact(Phone),Grant_Application__c(Phone_Number__c)];
                
            //A person is only eligible for support if he have monthly income lower than SGD 2000
            if (Integer.valueOf(MonthlyIncome)>=MAX_ELIGIBLE_INCOME) {
                throw new SubmitCustomException('You are not eligible for grant if your monthly income is SGD2000 and above');
            }
            // Conditinal : if phone search resulted nothing, go the route of creating new grant application,
            // contact and grant disbursed with the provided information                 
            if (searchPhoneinContactAndGrantApplication[0].isEmpty()) {
                Grant_Application__c grantApp = new Grant_Application__c(
                    First_Name__c = FirstName,
                    Last_Name__c = LastName,
                    Phone_Number__c = Phone,
                    Postal_Code__c = PostalCode,
                    Monthly_Income__c = MonthlyIncome,
                    Support_Option__c = SupportOption
                );                        
                insert as user grantApp;
  
                Contact applicantContact = new Contact(
                    FirstName = FirstName,
                    LastName = LastName,
                    Phone = Phone,
                    MailingPostalCode = String.valueOf(PostalCode)
                );
                applicantContact.OwnerId = currentUserId;
                insert as user applicantContact;  
                grantContactId = applicantContact.Id;      
            }

            // Conditional : if an existing phone number is found, update the record 
            // according to the new information provided
            else if (searchPhoneinContactAndGrantApplication[0][0].get('Phone')==Phone) {
                updateGrantContactId = searchPhoneinContactAndGrantApplication[0][0].Id;
                updateGrantApplicationId = searchPhoneinContactAndGrantApplication[1][0].Id;
                evaluateSupportParameters(SupportOption,updateGrantContactId,mdtMap);
                updateGrandAppAndContact(FirstName,LastName,Phone,PostalCode,MonthlyIncome,SupportOption,
                                         updateGrantContactId,updateGrantApplicationId);
            }
            if (searchPhoneinContactAndGrantApplication[0].isEmpty()) {
                String metadataJson = JSON.serialize(mdtMap);
                insertGrantDisbursed(metadataJson,SupportOption,grantContactId);
            }        
        }    
        catch(DmlException e) {
            System.debug('Exception message'+e.getMessage());     
       }
    }


/*
*********************************************************
@Method Name    : updateGrandAppAndContact
@author         : Aditya Tiwari
@description    : This method update the Contact and Grant Application object when a matching phone number
@param          : None
@param          : FirstName
@param          : LastName
@param          : Phone
@param          : PostalCode
@param          : MonthlyIncome
@param          : SupportOption
@param          : updateGrantContactId
@param          : updateGrantApplicationId

@return         : None
********************************************************
*/
public static void updateGrandAppAndContact(String FirstName,String LastName,String Phone,Decimal PostalCode,Decimal MonthlyIncome,String SupportOption,Id updateGrantContactId,Id updateGrantApplicationId){
    Grant_Application__c newGAObject = new Grant_Application__c(
        Id = updateGrantApplicationId,
        First_Name__c = FirstName,
        Last_Name__c = LastName,
        Phone_Number__c = Phone,
        Postal_Code__c = PostalCode,
        Monthly_Income__c = MonthlyIncome,
        Support_Option__c = SupportOption
    );
    Contact newGAContactObj = new Contact(
        Id = updateGrantContactId,
        FirstName = FirstName,
        LastName = LastName,
        Phone = Phone,
        MailingPostalCode = String.valueOf(PostalCode)
    );
    update newGAObject;
    update newGAContactObj;
}

/*
*********************************************************
@Method Name    : evaluateSupportParameters
@author         : Aditya Tiwari
@description    : This method returns date for first day of immediate next month from current month
@param          : SupportOption
@param          : updateGrantContactId
@param          : mdtMap

@return         : None
********************************************************
*/

    public static void evaluateSupportParameters(String SupportOption,Id updateGrantContactId,Map<String,Grant_Application_Params__mdt> mdtMap){
        Decimal amountAlreadyDisbursed=0;
        Decimal totalAmountPromised=0;
        Integer monthDisbursedCount=0;
        Decimal remainingGrantFund = 0;
        Integer remainingMonths = 0;
        Decimal updatedMonthlyGrant=0;                
        List<Grant_Disbursed__c> gdListForContact = [
                                                        SELECT 
                                                            Disbursed_Amount__c,
                                                            Contact_for_Grant_Applicant__r.Full_Name__c,
                                                            Is_Grant_disbursed__c from Grant_Disbursed__c 
                                                        WHERE Contact_for_Grant_Applicant__c = :updateGrantContactId 
                                                        WITH USER_MODE
                                                    ];               
        for (Grant_Disbursed__c gd : gdListForContact) {
            if (gd.Is_Grant_disbursed__c==true) {
                   monthDisbursedCount+=1;
                   amountAlreadyDisbursed+=gd.Disbursed_Amount__c;
            }
            totalAmountPromised += gd.Disbursed_Amount__c;                        
        }
        String month = String.valueOf(mdtMap.get(supportOption).Months_of_grant__c);
        Decimal amount = (Decimal)mdtMap.get(supportOption).Amount_each_month__c;
        remainingGrantFund = amount * Decimal.valueOf(month) - amountAlreadyDisbursed;
        remainingMonths = Integer.valueOf(month) - monthDisbursedCount;

        if (remainingMonths<=0) {
            throw new SubmitCustomException('Grant months(duration) already exceeds chosen option');
        }   
        if (amountAlreadyDisbursed> amount* Integer.valueOf(month)) {
            throw new SubmitCustomException('Grant amount already exceeds chosen option');
        }
        List <Grant_Disbursed__c> deleteOldGDList = [
                                                        SELECT Id from Grant_Disbursed__c 
                                                        WHERE Contact_for_Grant_Applicant__c = :updateGrantContactId 
                                                        AND Is_Grant_disbursed__c = false 
                                                        WITH USER_MODE
                                                    ];
        delete deleteOldGDList;

        updatedMonthlyGrant = Math.ceil(remainingGrantFund/remainingMonths);
        Date firstDayOfNextMonth = calculateDisbursalDate();               
        List<Grant_Disbursed__c> toBeUpdatedGrantDisbursedRecordList = new List<Grant_Disbursed__c>(); 

            Integer subsequentMonth = 1;
            for (;remainingMonths>0;remainingMonths--) {
                Grant_Disbursed__c gdObject = new Grant_Disbursed__c(
                    Contact_for_Grant_Applicant__c = updateGrantContactId,
                    Disbursed_Amount__c = updatedMonthlyGrant,
                    Disbursed_Date__c = firstDayOfNextMonth.addMonths(subsequentMonth)
                );
                toBeUpdatedGrantDisbursedRecordList.add(gdObject);
                subsequentMonth++;
            }
            insert toBeUpdatedGrantDisbursedRecordList;
}


/*
*********************************************************
@Method Name    : insertGrantDisbursed
@author         : Aditya Tiwari
@description    : Main objective is to insert grant disbursed object records. This method runs 
                  asynchronously in future context, takes a string that has been serialized from 
                  mdtMap storing label,metadata record values so that metadata info can be used 
                  to create grant disbursed records
@param          : metadataJson,String ,String grantContactId
@param          : SupportOption
@param          : grantContactId
@return         : None
********************************************************
*/    

    @future
    public static void insertGrantDisbursed(String metadataJson,String SupportOption,String grantContactId){
        try {
                
            Map<String, Grant_Application_Params__mdt> metadataMap = (Map<String, Grant_Application_Params__mdt>)JSON.deserialize(metadataJson, Map<String, Grant_Application_Params__mdt>.class);
                
                
            Integer monthsOfGrant = Integer.valueOf(metadataMap.get(supportOption).Months_of_grant__c);
            Integer amountPerMonth = Integer.valueOf(metadataMap.get(supportOption).Amount_each_month__c);
                
            List<Grant_Disbursed__c> newGrantDisbursedList = new List<Grant_Disbursed__c>();
                
            for (Integer i=0;i<monthsOfGrant;i++) {
                Date currentDate = Date.today();
                
                Integer nextMonth;
                Integer nextYear;
                    
                if (currentDate.month() == 12) {
                    nextMonth = 1;
                    nextYear = currentDate.year() + 1;
                } else {
                    nextMonth = currentDate.month() + 1;
                    nextYear = currentDate.year();
                }
                    
                Date firstDayOfNextMonth = Date.newInstance(nextYear, nextMonth, 1);
                    
                Grant_Disbursed__c gdObject = new Grant_Disbursed__c(
                    Contact_for_Grant_Applicant__c = grantContactId,
                    Disbursed_Amount__c = (Decimal)amountPerMonth,
                    Disbursed_Date__c = firstDayOfNextMonth.addMonths(i)
                );
                    
                newGrantDisbursedList.add(gdObject);
                    
            }
                
            insert newGrantDisbursedList;
                
                
        } catch (Exception e) {
                System.debug('Error From Future Method **** '+e.getMessage());
                System.debug('Error Stack From Future Method #### '+e.getStackTraceString());
                
        }
    }

/*
*********************************************************
@Method Name    : getOptionsFromCMT
@author         : Aditya Tiwari
@description    : This method returns a Map of label,value for the Support Options that needs to be displayed
                  on the component UI inside the combobox in the form of a picklist, the label and values are 
                  taken from custom metadata named Grant_Application_Params__mdt
@param          : None
@return         : Map<String, String>
********************************************************
*/

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getOptionsFromCMT() {
        Map<String, String> options = new Map<String, String>();
            
        List<Grant_Application_Params__mdt> metaDataOptionsList = customMDTList;
        for (Grant_Application_Params__mdt option : metaDataOptionsList) {
            options.put('SGD '+String.valueOf(option.Amount_each_month__c)+' per month for '+String.valueOf(option.Months_of_grant__c)+' months', 'SGD '+String.valueOf(option.Amount_each_month__c)+' per month for '+String.valueOf(option.Months_of_grant__c)+' months');
        }
        return options;
    }
     
/*
*********************************************************
@Method Name    : searchPhoneInGrantApplication
@author         : Aditya Tiwari
@description    : This method is used to search a grant aplication record with input matching Phone number.
                  This method returns a list of grant application records, we use this list in js to verify
                  if a record with entered Phone number already exist or not and show user friendly message 
                  accordingly
@param          : String Phone
@return         : List<Grant_Application__c>
********************************************************
*/

    @AuraEnabled
    public static List<Grant_Application__c> searchPhoneInGrantApplication(String Phone){
        List<Grant_Application__c> GAList = new List<Grant_Application__c>();
        try {
            GAList = [
                        SELECT 
                            ID,
                            First_Name__c,
                            Last_Name__c,
                            Phone_Number__c,
                            Monthly_Income__c,
                            Postal_Code__c,
                            Support_Option__c 
                        FROM Grant_Application__c 
                        WHERE Phone_Number__c = :Phone 
                        WITH USER_MODE
                    ];
            if (!GAList.isEmpty()) {
                return GAList;
            }
            else {
                throw new SubmitCustomException('No such phone number exist');
            }
        }
        catch(SubmitCustomException e) {
            System.debug('Search mobile exception '+e.getMessage());
        }
        return GAList;
    }
        
    public class SubmitCustomException extends Exception{}
}