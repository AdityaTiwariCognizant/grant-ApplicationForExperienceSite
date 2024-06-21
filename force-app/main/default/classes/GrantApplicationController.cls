public without sharing class GrantApplicationController {

    private static final Integer MAX_ELIGIBLE_INCOME = 2000;
    public static Id currentUserId = UserInfo.getUserId();

    public static Map<String,Grant_Application_Params__mdt> mdtMap = new Map<String,Grant_Application_Params__mdt>();

    public static void prepareCustomMetadata() {
        List<Grant_Application_Params__mdt> customMetadataRecords = [SELECT Label,Amount_each_month__c, Months_of_grant__c from Grant_Application_Params__mdt WITH USER_MODE];

        for (Integer i=0;i<customMetadataRecords.size();i++) {

            //new code
            String amount = String.valueOf(customMetadataRecords[i].Amount_each_month__c);
            String months = String.valueOf(customMetadataRecords[i].Months_of_grant__c);
            String label = 'SGD '+amount+' per month for '+months+' months';
            mdtMap.put(label,customMetadataRecords[i]);

        }

    }


    public static string grantContactId;
    public static string updateGrantContactId;
    public static string updateGrantApplicationId;

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

    @AuraEnabled(cacheable=false)
    public static void createGrantApplication(String FirstName,String LastName,String Phone,Decimal PostalCode,Decimal MonthlyIncome,String SupportOption) {

        try{

            List<Grant_Application_Params__mdt> supportOptionCustomMetadata = [SELECT label,Amount_each_month__c,   Months_of_grant__c from Grant_Application_Params__mdt where label= :SupportOption WITH USER_MODE];

            List<List<sObject>> searchPhoneinContact = [FIND :Phone IN PHONE FIELDS 
            RETURNING Contact(Phone)];

            List<List<sObject>> searchPhoneinGrantApplication = [FIND :Phone IN PHONE FIELDS 
            RETURNING Grant_Application__c(Phone_Number__c)];

            if (Integer.valueOf(MonthlyIncome)>=MAX_ELIGIBLE_INCOME) {
                throw new SubmitCustomException('You are not eligible for grant if your monthly income is SGD2000 and above');
            }

            prepareCustomMetadata();

            if (searchPhoneinContact[0].isEmpty()) {
                Grant_Application__c grantApp = new Grant_Application__c(
                First_Name__c = FirstName,
                Last_Name__c = LastName,
                Phone_Number__c = Phone,
                Postal_Code__c = PostalCode,
                Monthly_Income__c = MonthlyIncome,
                Support_Option__c = SupportOption);
        
                
                insert as user grantApp;

                Contact applicantContact = new Contact(
                    FirstName = FirstName,
                    LastName = LastName,
                    Phone = Phone,
                    MailingPostalCode = String.valueOf(PostalCode)
                    
                );

                applicantContact.OwnerId = currentUserId;

                try {

                    insert as user applicantContact;
                }
                catch(Exception e) {
                    System.debug('Contact insert excption :*** '+e.getMessage());
                    System.debug('Contact insert stack *** :: ' + e.getStackTraceString());
                }

                grantContactId = applicantContact.Id;


            }

            else if (searchPhoneinContact[0][0].get('Phone')==Phone) {
                //update existing Grant Application records
                updateGrantContactId = searchPhoneinContact[0][0].Id;
                updateGrantApplicationId = searchPhoneinGrantApplication[0][0].Id;
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

                Decimal amountAlreadyDisbursed=0;
                Decimal totalAmountPromised=0;
                Integer monthDisbursedCount=0;
                Decimal remainingGrantFund = 0;
                Integer remainingMonths = 0;
                Decimal updatedMonthlyGrant=0;

                List<Grant_Disbursed__c> gdListForContact = [Select Disbursed_Amount__c,Contact_for_Grant_Applicant__r.Full_Name__c,Is_Grant_disbursed__c from Grant_Disbursed__c where Contact_for_Grant_Applicant__c = :updateGrantContactId WITH USER_MODE];
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

                List <Grant_Disbursed__c> deleteOldGDList = [Select Id from Grant_Disbursed__c where Contact_for_Grant_Applicant__c =:updateGrantContactId and Is_Grant_disbursed__c=false WITH USER_MODE];
                delete deleteOldGDList;
                updatedMonthlyGrant = Math.ceil(remainingGrantFund/remainingMonths);

                Date firstDayOfNextMonth = calculateDisbursalDate();

                List<Grant_Disbursed__c> toBeUpdatedGrantDisbursedRecordList = 
                new List<Grant_Disbursed__c>();

                Integer i = 1;
                while (remainingMonths>0) {
                    Grant_Disbursed__c gdObject = new Grant_Disbursed__c(
                        Contact_for_Grant_Applicant__c = updateGrantContactId,
                        Disbursed_Amount__c = updatedMonthlyGrant,
                        Disbursed_Date__c = firstDayOfNextMonth.addMonths(i)
                    );

                    toBeUpdatedGrantDisbursedRecordList.add(gdObject);
                    remainingMonths--;
                    i++;
                }
                insert toBeUpdatedGrantDisbursedRecordList;
                update newGAObject;
                update newGAContactObj;
            }

            if (searchPhoneinContact[0].isEmpty()) {
                String metadataJson = JSON.serialize(mdtMap);
                insertGrantDisbursed(metadataJson,SupportOption,grantContactId);
            }
        
        }

        catch(DmlException e) {
            System.debug('Exception message'+e.getMessage());

        }
    }

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

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getOptionsFromCMT() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        
        for (Grant_Application_Params__mdt option : [SELECT Months_of_grant__c,Amount_each_month__c FROM Grant_Application_Params__mdt WITH USER_MODE]) {
            Map<String, String> optionMap = new Map<String, String>();
            optionMap.put('label', 'SGD '+String.valueOf(option.Amount_each_month__c)+' per month for '+String.valueOf(option.Months_of_grant__c)+' months');
            optionMap.put('value', 'SGD '+String.valueOf(option.Amount_each_month__c)+' per month for '+String.valueOf(option.Months_of_grant__c)+' months');
            options.add(optionMap);
        }
        return options;
    }

    @AuraEnabled(cacheable=false)
    public static List<Grant_Application__c> searchPhoneInGrantApplication(String Phone){
        try {
            List<Grant_Application__c> GAList = [SELECT ID,First_Name__c,Last_Name__c,Phone_Number__c,Monthly_Income__c,Postal_Code__c,Support_Option__c FROM Grant_Application__c WHERE Phone_Number__c= :Phone WITH USER_MODE];
            return GAList;
        }
        catch(SubmitCustomException e) {
            System.debug('Search mobile exception '+e.getMessage());
            return [SELECT ID,First_Name__c,Last_Name__c,Phone_Number__c,Monthly_Income__c,Postal_Code__c,Support_Option__c FROM Grant_Application__c WHERE Phone_Number__c= :Phone];
        }
    }

    public class SubmitCustomException extends Exception{}
}

