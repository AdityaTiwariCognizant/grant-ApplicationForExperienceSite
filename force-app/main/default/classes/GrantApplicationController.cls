public class GrantApplicationController {

    private static final Integer MAX_ELIGIBLE_INCOME = 2000;

    public static List<Map<String, Object>> optionsList = new List<Map<String, Object>>();

    
    public static void prepareCustomMetadata(){
        List<Grant_Application_Params__mdt> customMetadataRecords = [SELECT label,Amount_each_month__c, Months_of_grant__c from Grant_Application_Params__mdt];

        Map<String, String> optionLabelMap = new Map<String, String>();
        Map<String, Decimal> optionMonthsMap = new Map<String, Decimal>();
        Map<String, Decimal> optionAmountMap = new Map<String, Decimal>();


        for(Integer i=0;i<customMetadataRecords.size();i++){
            String labelString = 'OPTION_' + String.valueOf(i+1);
            String monthString = 'OPTION_' +String.valueOf(i+1) + '_MONTHS';
            String amountString = 'OPTION_'+String.valueOf(i+1)+'_AMOUNT';
            optionLabelMap.put(labelString,customMetadataRecords[i].label);
            optionMonthsMap.put(monthString,customMetadataRecords[i].Months_of_grant__c);
            optionAmountMap.put(amountString,customMetadataRecords[i].Amount_each_month__c);
        }



        for(String key : optionLabelMap.keySet()) {
            // Create a new map to represent a single option
            Map<String, Object> option = new Map<String, Object>();
            option.put('label', optionLabelMap.get(key));
            option.put('month', optionMonthsMap.get(key+'_MONTHS'));
            option.put('amount', optionAmountMap.get(key+'_AMOUNT'));
            optionsList.add(option);
            System.debug('optionsList : '+optionsList);
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

            List<Grant_Application_Params__mdt> supportOptionCustomMetadata = [SELECT label,Amount_each_month__c,   Months_of_grant__c from Grant_Application_Params__mdt where label= :SupportOption];


            List<List<sObject>> searchPhoneinContact = [FIND :Phone IN PHONE FIELDS 
            RETURNING Contact(Phone)];

            List<List<sObject>> searchPhoneinGrantApplication = [FIND :Phone IN PHONE FIELDS 
            RETURNING Grant_Application__c(Phone_Number__c)];

            if(Integer.valueOf(MonthlyIncome)>=MAX_ELIGIBLE_INCOME){
                throw new SubmitCustomException('You are not eligible for grant if your monthly income is SGD2000 and above');
            }

            prepareCustomMetadata();

            System.debug('****** '+searchPhoneinContact[0].isEmpty());
            if(searchPhoneinContact[0].isEmpty()){
                Grant_Application__c grantApp = new Grant_Application__c(
                First_Name__c = FirstName,
                Last_Name__c = LastName,
                Phone_Number__c = Phone,
                Postal_Code__c = PostalCode,
                Monthly_Income__c = MonthlyIncome,
                Support_Option__c = SupportOption);
        
                
                insert grantApp;

                Contact applicantContact = new Contact(
                    FirstName = FirstName,
                    LastName = LastName,
                    Phone = Phone,
                    MailingPostalCode = String.valueOf(PostalCode)
                );

                insert applicantContact;

                grantContactId = applicantContact.Id;
            }

            else if(searchPhoneinContact[0][0].get('Phone')==Phone){
                //update existing Grant Application records
                updateGrantContactId = searchPhoneinContact[0][0].Id;
                updateGrantApplicationId = searchPhoneinGrantApplication[0][0].Id;
                System.debug('This is an update operation ######### ');
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

                List<Grant_Disbursed__c> gdListForContact = [Select Disbursed_Amount__c,Contact_for_Grant_Applicant__r.Full_Name__c,Is_Grant_disbursed__c from Grant_Disbursed__c where Contact_for_Grant_Applicant__c = :updateGrantContactId];
                for(Grant_Disbursed__c gd : gdListForContact){
                    if(gd.Is_Grant_disbursed__c==true){
                        monthDisbursedCount+=1;
                        amountAlreadyDisbursed+=gd.Disbursed_Amount__c;
                    }
                    totalAmountPromised += gd.Disbursed_Amount__c;
      
                }

                for (Map<String, Object> option : optionsList) {
                    if (String.valueOf(option.get('label')) == SupportOption) {
                        // Retrieve the month and amount values for the matching option
                        String month = String.valueOf(option.get('month'));
                        Decimal amount = (Decimal)option.get('amount');
        
                        // Perform calculations 
                        remainingGrantFund = amount * Decimal.valueOf(month) - amountAlreadyDisbursed;
                        remainingMonths = Integer.valueOf(month) - monthDisbursedCount;

                        if(remainingMonths<=0){
                            throw new SubmitCustomException('Grant months(duration) already exceeds chosen option');
                        }

                        if(amountAlreadyDisbursed> amount* Integer.valueOf(month)){
                            throw new SubmitCustomException('Grant amount already exceeds chosen option');
                        }

                        List <Grant_Disbursed__c> deleteOldGDList = [Select Id from Grant_Disbursed__c where Contact_for_Grant_Applicant__c =:updateGrantContactId and Is_Grant_disbursed__c=false];
                        delete deleteOldGDList;
                        updatedMonthlyGrant = Math.ceil(remainingGrantFund/remainingMonths);

                        Date firstDayOfNextMonth = calculateDisbursalDate();

                        Integer i = 1;
                        while(remainingMonths>0){
                            Grant_Disbursed__c gdObject = new Grant_Disbursed__c(
                                Contact_for_Grant_Applicant__c = updateGrantContactId,
                                Disbursed_Amount__c = updatedMonthlyGrant,
                                Disbursed_Date__c = firstDayOfNextMonth.addMonths(i)
                            );
                            insert gdObject;
                            remainingMonths--;
                            i++;
                        }
                        update newGAObject;
                        update newGAContactObj;
                        
                        // Break out of the loop once the matching option is found
                        break;
                    }
                }
            }

            for (Map<String, Object> option : optionsList) {
           

                if (String.valueOf(option.get('label')) == SupportOption) {
                    for(Integer i=0;i< Integer.valueOf(option.get('month'));i++){

                        Date firstDayOfNextMonth = calculateDisbursalDate();
        
                        //create Grant Disbursed records
                        Grant_Disbursed__c gdObject = new Grant_Disbursed__c(
                            Contact_for_Grant_Applicant__c = grantContactId,
                            Disbursed_Amount__c = (Decimal)option.get('amount'),
                            Disbursed_Date__c = firstDayOfNextMonth.addMonths(i)
                        );
        
                        insert gdObject;
        
                    }
                    break;
                }
            
            }
        }

        catch(DmlException e){
            System.debug('Exception message'+e.getMessage());

        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getOptionsFromCMT() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        
        for(Grant_Application_Params__mdt option : [SELECT Months_of_grant__c,Amount_each_month__c FROM Grant_Application_Params__mdt]) {
            Map<String, String> optionMap = new Map<String, String>();
            optionMap.put('label', 'SGD '+String.valueOf(option.Amount_each_month__c)+' per month for '+String.valueOf(option.Months_of_grant__c)+' months');
            optionMap.put('value', 'SGD '+String.valueOf(option.Amount_each_month__c)+' per month for '+String.valueOf(option.Months_of_grant__c)+' months');
            options.add(optionMap);
        }
        return options;
    }

    public class SubmitCustomException extends Exception{}
}

