@isTest(SeeAllData=true)
public class grantApplicationControllerTest {
    
    
    @isTest
    public static void prepareMetadataTest_Positive() {
        Map<String, Grant_Application_Params__mdt> tempMetaDataMap = GrantApplicationController.prepareCustomMetadata();
        System.assertEquals(4, tempMetaDataMap.size(), 'Map size should be 4');
        
        System.assertEquals('SGD 150 per month for 8 months', tempMetaDataMap.get('SGD 150 per month for 8 months').Label, 'Metadata record label incorrect');
        System.assertEquals(200, tempMetaDataMap.get('SGD 200 per month for 12 months').Amount_each_month__c, 'Metadata record custom field value incorrect');
        System.assertEquals(3, tempMetaDataMap.get('SGD 500 per month for 3 months').Months_of_grant__c, 'Metadata record custom field value incorrect');
        
    }
    
    @isTest
    public static void calculateDisbursalDate_Test() {
        // Set up test data
        Test.startTest();
        
        GrantApplicationController.calculateDisbursalDate();
        
        Test.stopTest();
        
        // Verify the result
        Date currentDate = Date.today();
        Integer expectedMonth;
        Integer expectedYear;
        
        if (currentDate.month() == 12) {
            expectedMonth = 1;
            expectedYear = currentDate.year() + 1;
        } else {
            expectedMonth = currentDate.month() + 1;
            expectedYear = currentDate.year();
        }
        
        Date expectedDate = Date.newInstance(expectedYear, expectedMonth, 1);
        Date actualDate = GrantApplicationController.calculateDisbursalDate();
        
        System.assertEquals(expectedDate, actualDate, 'Disbursal date calculation incorrect');
        System.assertEquals(expectedMonth, actualDate.month(), 'Month calculation incorrect');
        System.assertEquals(expectedYear, actualDate.year(), 'Year calculation incorrect');
        System.assertEquals(1, actualDate.day(), 'Disbursal date should always be on the 1st of the month');
        
    }
    
    
    @isTest
    public static void createGrantApplicationTest_New() {
        
        // Create test data
        String supportOption = 'SGD 500 per month for 3 months';
        Decimal monthlyIncome = 1700; // Below the maximum eligible income
        
        // Mock metadata for the support option
        
        Grant_Application_Params__mdt mockMetadata = new Grant_Application_Params__mdt (
            label = supportOption,
            Amount_each_month__c = 500,
            Months_of_grant__c = 3
        );
        //insert mockMetadata;
        
        // Mock search results for phone number (simulating no existing records found)
        //Test.setFixedSearchResults(new List<List<SObject>>());
        
        // Mock current user
        //User currentUser = new User(ProfileId = [SELECT Id FROM Profile WHERE Name='Standard User'].Id);
        //insert currentUser;
        
        Test.startTest();
        
        try {
            // Call the method to test
            GrantApplicationController.createGrantApplication (
                'TestFirstName', 'TestLastName', '911234567890', 543210, monthlyIncome, supportOption
                );
            //another for returning user
            String testPhone2 = '919838780154';
            GrantApplicationController.createGrantApplication (
                'TestFirstName2', 'TestLastName2', testPhone2, 543210, monthlyIncome, supportOption
                );
            
            
            
        } catch (Exception e) {
            System.assert(false, 'Exception occurred: ' + e.getMessage());
        }
        Test.stopTest();
        
        // Query and assert results
        List<Grant_Application__c> grantApplications = [
            SELECT Id, First_Name__c, Last_Name__c, Phone_Number__c, Postal_Code__c, Monthly_Income__c, Support_Option__c
            FROM Grant_Application__c
            WHERE First_Name__c = 'TestFirstName'
        ];
        System.assertEquals(1, grantApplications.size(), 'Expected one Grant_Application__c record to be inserted');
        Grant_Application__c createdGrantApp = grantApplications[0];
        System.assertEquals('TestFirstName', createdGrantApp.First_Name__c);
        System.assertEquals('TestLastName', createdGrantApp.Last_Name__c);
        System.assertEquals('911234567890', createdGrantApp.Phone_Number__c);
        System.assertEquals(543210, createdGrantApp.Postal_Code__c);
        System.assertEquals(monthlyIncome, createdGrantApp.Monthly_Income__c);
        System.assertEquals(supportOption, createdGrantApp.Support_Option__c);
        
        List<Contact> contacts = [
            SELECT Id, FirstName, LastName, Phone, MailingPostalCode
            FROM Contact
            WHERE FirstName = 'TestFirstName'
        ];
        System.assertEquals(1, contacts.size(), 'Expected one Contact record to be inserted');
        Contact createdContact = contacts[0];
        System.assertEquals('TestFirstName', createdContact.FirstName);
        System.assertEquals('TestLastName', createdContact.LastName);
        System.assertEquals('911234567890', createdContact.Phone);
        System.assertEquals('543210', createdContact.MailingPostalCode);
        
        
        
    }
    
    @isTest
    public static void createGrantApplicationTest_Existing() {
        
        // Create test data
        String supportOption = 'SGD 500 per month for 3 months';
        Decimal monthlyIncome = 1700; // Below the maximum eligible income
        
        
        
        Grant_Application__c createTestGA = new Grant_Application__c(
            First_Name__c ='TestFirstName2',
            Last_Name__c = 'TestLastName2',
            Phone_Number__c = '919838780154',
            Postal_Code__c = 543210,
            Monthly_Income__c = 1700,
            Support_Option__c = 'SGD 500 per month for 3 months'
        );
        
        insert createTestGA;
        
        Contact testContact = new Contact(
            FirstName = 'TestFirstName2',
            LastName = 'TestLastName2',
            Phone = '919838780154',
            MailingPostalCode = '543210'
            
        );
        insert testContact;
        
        Test.startTest();
        //Test.setCurrentUser([SELECT Id FROM User LIMIT 1].Id);  // Ensure you set a current user for ownership
        
        // Define new input values
        String newFirstName = 'TestFirstName2';
        String newLastName = 'TestLastName2';
        String newPhone = '919838780154';
        Decimal newPostalCode = 543210;
        Decimal newMonthlyIncome = 1700;
        String newSupportOption = 'SGD 500 per month for 3 months';
        
        // Call the method
        GrantApplicationController.createGrantApplication(newFirstName, newLastName, newPhone, newPostalCode, newMonthlyIncome, newSupportOption);
        
        // Check that the existing Grant Application was updated
        Grant_Application__c updatedGrantApp = [SELECT Monthly_Income__c, Support_Option__c FROM Grant_Application__c WHERE Phone_Number__c = :newPhone LIMIT 1];
        System.assertEquals(newMonthlyIncome, updatedGrantApp.Monthly_Income__c, 'Grant Application Monthly Income was not updated.');
        System.assertEquals(newSupportOption, updatedGrantApp.Support_Option__c, 'Grant Application Support Option was not updated.');
        
        Test.stopTest();
        
    }
    
    @isTest
    public static void updateGrandAppAndContactTest() {
        
        
        Grant_Application__c grantApp = new Grant_Application__c(
            First_Name__c = 'TestFirstName',
            Last_Name__c = 'TestLastName',
            Phone_Number__c = '1234567890',
            Postal_Code__c = 12345,
            Monthly_Income__c = 1200,
            Support_Option__c = 'SGD 500 per month for 3 months'
        );
        
        insert grantApp;
        
        Contact applicantContact = new Contact(
            FirstName = 'TestFirstName',
            LastName = 'TestLastName',
            Phone = '1234567890',
            MailingPostalCode = '12345'
        );
        
        insert applicantContact;
        
        
        
        GrantApplicationController.updateGrandAppAndContact('Test First Name', 'Last Name ###', '919876543210',
                                                            543210, 1750, 'SGD 150 per month for 8 months',
                                                            applicantContact.Id, grantApp.Id);
        
        
        
        Grant_Application__c updatedGrantApp = [SELECT Id, First_Name__c, Last_Name__c, Phone_Number__c,
                                                Postal_Code__c, Monthly_Income__c, Support_Option__c
                                                FROM Grant_Application__c WHERE Id = :grantApp.Id];
        
        Contact updatedContact = [SELECT Id, FirstName, LastName, Phone, MailingPostalCode
                                    FROM Contact WHERE Id = :applicantContact.Id];
        
        
        System.assertEquals('Test First Name', updatedGrantApp.First_Name__c);
        System.assertEquals('Last Name ###', updatedGrantApp.Last_Name__c);
        System.assertEquals('919876543210', updatedGrantApp.Phone_Number__c);
        System.assertEquals(543210, updatedGrantApp.Postal_Code__c);
        System.assertEquals(1750, updatedGrantApp.Monthly_Income__c);
        System.assertEquals('SGD 150 per month for 8 months', updatedGrantApp.Support_Option__c);
        
        System.assertEquals('Test First Name', updatedContact.FirstName);
        System.assertEquals('Last Name ###', updatedContact.LastName);
        System.assertEquals('919876543210', updatedContact.Phone);
        System.assertEquals('543210', updatedContact.MailingPostalCode);
        
        delete updatedGrantApp;
        delete updatedContact;
    }
    
    @isTest
    public static void evaluateSupportParameters_Test() {
        
        String supportOptn = 'SGD 150 per month for 8 months';
        
        //String SupportOption,Id updateGrantContactId,Map<String,Grant_Application_Params__mdt> mdtMap
        
        Map<String, Grant_Application_Params__mdt> mdtMap = new Map<String, Grant_Application_Params__mdt>();
        mdtMap.put('SGD 150 per month for 8 months', new Grant_Application_Params__mdt(
                                                        label = 'SGD 150 per month for 8 months',
                                                        Months_of_grant__c = 8,
                                                        Amount_each_month__c = 150
                                                        )
        );
        
        Contact contact = new Contact(
            FirstName = 'TestFirstName',
            LastName = 'TestLastName',
            Phone = '911234567890',
            MailingPostalCode = '012345'
        );
        insert contact;
        List<Grant_Disbursed__c> existingDisbursedList = new List<Grant_Disbursed__c>();
        for (Integer i = 1; i <= 3; i++) { // Simulate 3 months already disbursed
            existingDisbursedList.add(new Grant_Disbursed__c(
                                        Contact_for_Grant_Applicant__c = contact.Id,
                                        Disbursed_Amount__c = 300,
                                        Disbursed_Date__c = Date.today().addMonths(-i),
                                        Is_Grant_disbursed__c = true
                                        )
                                    );
        }
        insert existingDisbursedList;
        
        Test.startTest();
        GrantApplicationController.evaluateSupportParameters(supportOptn, contact.Id, mdtMap);
        Test.stopTest();
        
        List<Grant_Disbursed__c> updatedDisbursedList = [
            SELECT Id, Contact_for_Grant_Applicant__c, Disbursed_Amount__c, Disbursed_Date__c, Is_Grant_disbursed__c
            FROM Grant_Disbursed__c
            WHERE Contact_for_Grant_Applicant__c = :contact.Id
            ORDER BY Disbursed_Date__c ASC
        ];
        
        // Assert that records were updated or inserted correctly
        System.assertEquals(8, updatedDisbursedList.size(), '#'+updatedDisbursedList.size());
        System.assertEquals(300, updatedDisbursedList[0].Disbursed_Amount__c, 'Disbursed amount must match');
        
        
        // Clean up: delete the Grant_Disbursed__c records created
        delete updatedDisbursedList;
    }
    
    
    @isTest
    public static void insertGrantDisbursed_Test(){
        
        //mdtMap - contains - {SGD 150 per month for 8 months=Grant_Application_Params__mdt:{Label=SGD 150 per month for 8 months, Amount_each_month__c=150, Months_of_grant__c=8, Id=m00J4000000k9oOIAQ}}
        
        String metadataJson = '{"SGD 300 per month for 6 months":{"Months_of_grant__c":"6", "Amount_each_month__c":"300"}}';
        
        Contact testContact = new Contact(
            FirstName = 'TestFirstName',
            LastName = 'TestLastName',
            Phone = '911234567890',
            MailingPostalCode = '012345'
        );
        insert testContact;
        
        
        
        Test.startTest();
        
        GrantApplicationController.insertGrantDisbursed(metadataJson, 'SGD 300 per month for 6 months', testContact.Id);
        
        Test.stopTest();
        
        List<Grant_Disbursed__c> grantDisbursedList = [
            SELECT Id, Contact_for_Grant_Applicant__c, Disbursed_Amount__c, Disbursed_Date__c
            FROM Grant_Disbursed__c
            WHERE Contact_for_Grant_Applicant__c = :testContact.Id
        ];
        
        System.assertEquals(6, grantDisbursedList.size(), 'Expected 6 records to be inserted');
        
        for (Integer i = 0; i < grantDisbursedList.size(); i++) {
            Grant_Disbursed__c gd = grantDisbursedList[i];
            System.assertEquals(testContact.Id, gd.Contact_for_Grant_Applicant__c, 'Contact Id should match');
            System.assertEquals(300, gd.Disbursed_Amount__c, 'Disbursed Amount should match');
            // Verify Disbursed Date incrementally
            Date expectedDate = Date.today().addMonths(i + 1).toStartOfMonth();
            System.assertEquals(expectedDate, gd.Disbursed_Date__c, 'Disbursed Date should match');
        }
        
    }
    
    @isTest
    public static void getOptionsFromCMT_Test() {
        
        Map<String, String> testCMTMap = GrantApplicationController.getOptionsFromCMT();
        
        System.assertEquals('SGD 500 per month for 3 months', testCMTMap.get('SGD 500 per month for 3 months'), 'CMT label do not match');
        System.assertEquals('SGD 300 per month for 6 months', testCMTMap.get('SGD 300 per month for 6 months'), 'CMT label do not match');
        System.assertEquals('SGD 200 per month for 12 months', testCMTMap.get('SGD 200 per month for 12 months'), 'CMT label do not match');
        
        
    }
    
    @isTest
    public static void searchPhoneInGrantApplication_Test() {
        
        String testPhone = '918567342649';
        GrantApplicationController.searchPhoneInGrantApplication('1234567890');
        GrantApplicationController.searchPhoneInGrantApplication(testPhone);
        
        String testPhone2 = [Select Phone_Number__c from Grant_Application__c order by Name limit 1][0].Phone_Number__c;
        GrantApplicationController.searchPhoneInGrantApplication(testPhone2);
        
        // Create a Grant Application record
        Grant_Application__c grantApp = new Grant_Application__c(
            First_Name__c = 'John',
            Last_Name__c = 'Doe',
            Phone_Number__c = '911234567890',
            Postal_Code__c = 0123456,
            Monthly_Income__c = 1500,
            Support_Option__c = 'SGD 300 per month for 6 months'
        );
        insert grantApp;
        
        // Define the phone number to search
        String phoneNumberToSearch = '911234567890';
        
        Test.startTest();
        // Call the method
        List<Grant_Application__c> result = GrantApplicationController.searchPhoneInGrantApplication(phoneNumberToSearch);
        Test.stopTest();
        
        // Check that the result is not empty and contains the correct data
        System.assertNotEquals(null, result, 'The result should not be null.');
        System.assertEquals(1, result.size(), 'The result list should contain one record.');
        Grant_Application__c fetchedApp = result[0];
        System.assertEquals('John', fetchedApp.First_Name__c, 'First Name does not match.');
        System.assertEquals('Doe', fetchedApp.Last_Name__c, 'Last Name does not match.');
        System.assertEquals(phoneNumberToSearch, fetchedApp.Phone_Number__c, 'Phone Number does not match.');
        System.assertEquals(0123456, fetchedApp.Postal_Code__c, 'Postal Code does not match.');
        System.assertEquals(1500, fetchedApp.Monthly_Income__c, 'Monthly Income does not match.');
        System.assertEquals('SGD 300 per month for 6 months', fetchedApp.Support_Option__c, 'Support Option does not match.');
    } 
}