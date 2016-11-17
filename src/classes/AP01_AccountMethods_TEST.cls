/** 
 * Test class for the AP01_AccountMethods
 *
 * @author  Nicolas Palitzyne ~ nicolas.palitzyne@accenture.com
 * @version 1.0
 * @date    16/01/2013 
 */
@isTest
private class AP01_AccountMethods_TEST {
    public static testmethod void testCopyMainToBilling() {
        
        WebServiceModule.isActive = false;
    
        Country__c testCountry = TestMethods.createCountry();
        insert testCountry;
        
        Account testAccount = TestMethods.createAccount(testCountry.ID);
        testAccount.CopyMainToBill__c = true;
        testAccount.TECH_ScoredClassification__c= '12345';
        insert testAccount;
        ID accID = testAccount.ID;

        testAccount = [SELECT ID, Name, BillingAddress1__c, BillingAddress2__c, 
                        BillingAddress3__c, BillingZipCode__c, BillingState__c,
                        BillingCountry__c, BillingCity__c, BillingPOBox__c,
                        CopyMainToBill__c,  MainAddress1__c,  
                        MainAddress2__c, MainAddress3__c,
                        MainZipCode__c, MainState__c, MainCountry__c,
                        MainCity__c, MainPOBox__c FROM Account WHERE ID = :accID];
        
        System.assert(testAccount.BillingAddress1__c   == testAccount.MainAddress1__c);
        System.assert(testAccount.BillingAddress2__c   == testAccount.MainAddress2__c);
        System.assert( testAccount.BillingAddress3__c  == testAccount.MainAddress3__c);
        System.assert(testAccount.BillingZipCode__c    == testAccount.MainZipCode__c);
        System.assert( testAccount.BillingState__c     == testAccount.MainState__c);
        System.assert(testAccount.BillingCountry__c    == testAccount.MainCountry__c);
        System.assert(testAccount.BillingCity__c       == testAccount.MainCity__c);
        System.assert(testAccount.BillingPOBox__c      == testAccount.MainPOBox__c);
        System.assert(!testAccount.CopyMainToBill__c);
                       
        testAccount.MainAddress1__c = 'New Test Address';
        testAccount.CopyMainToBill__c = true;
               
        update testAccount;

        testAccount = [SELECT ID, Name, BillingAddress1__c, BillingAddress2__c, 
                        BillingAddress3__c, BillingZipCode__c, BillingState__c,
                        BillingCountry__c, BillingCity__c, BillingPOBox__c,
                        CopyMainToBill__c,  MainAddress1__c,  
                        MainAddress2__c, MainAddress3__c,
                        MainZipCode__c, MainState__c, MainCountry__c,
                        MainCity__c, MainPOBox__c FROM Account WHERE ID = :accID];
                        
        System.assertEquals(testAccount.BillingAddress1__c, testAccount.MainAddress1__c);

    }
    
    /** Test that an account with active contracts cannot be deleted */
    public static testmethod void testDelWithActiveContracts() {
        
        WebServiceModule.isActive = false;
        
        Country__c testCountry = TestMethods.createCountry();
        insert testCountry;
        
        Account testAccount = TestMethods.createAccount(testCountry.ID); 
        insert testAccount;     
        
        
        // Add an active contract to the Account
        ContractHeader__c testContract = TestMethods.createContractHeader(testAccount.ID);
        insert  testContract;
        
        testAccount = [SELECT ID, NbrActiveContracts__c FROM Account WHERE ID = :testAccount.ID];
        
        System.assertEquals(testAccount.NbrActiveContracts__c, 1);
        String errorMessage;
        
        try {
            delete testAccount;
        }
        catch(DMLException e) {
            errorMessage = e.getDMLMessage(0);
        }
        
        System.assertEquals(errorMessage, Label.ACC0044);
    }
    
    /** Test that an account with active contracts as a beneficiary cannot be deleted */
    public static testmethod void testDelWithActiveBeneficiaries() {
        
        WebServiceModule.isActive = false;
        
        Country__c testCountry = TestMethods.createCountry();
        insert testCountry;
        
        List<Account> accountList = new List<Account>();
        
        for(Integer i=0; i<5; i++) {
            accountList.add(TestMethods.createAccount(testCountry.ID));
        }
        
        insert accountList;     

        ContractHeader__c testContract = TestMethods.createContractHeader(accountList[2].ID);
        insert  testContract;
        
        // Add a Contract Beneficiary
        ContractBeneficiary__c beneficary = new ContractBeneficiary__c(Beneficiary__c = accountList[0].ID, ContractHeader__c = testContract.ID );
        insert beneficary;
        
        Account testAccount = [SELECT ID, NbrActiveContracts__c FROM Account WHERE ID = :accountList[0].ID];
        String errorMessage;
        
        try {
            delete testAccount;
        }
        catch(DMLException e) {
            errorMessage = e.getDMLMessage(0);
        }
        
        System.assertEquals(errorMessage, Label.ACC0044);
    }

    /** Test that an account with active contracts as a distributing agency cannot be deleted */
    public static testmethod void testDelWithActiveDistribAgency() {
        
        WebServiceModule.isActive = false;
        
        Country__c testCountry = TestMethods.createCountry();
        insert testCountry;
        
        List<Account> accountList = new List<Account>();
        
        for(Integer i=0; i<5; i++) {
            accountList.add(TestMethods.createAccount(testCountry.ID));
        }
        
        insert accountList;     
        
        
        ContractHeader__c testContract = TestMethods.createContractHeader(accountList[2].ID);
        insert  testContract;
        
        // Add a distributing agency to the account
        DistributionAgency__c distribAgency = new DistributionAgency__c(DistribAgency__c = accountList[0].ID, ContractHeader__c = testContract.ID );
        insert distribAgency;
        
        Account testAccount = [SELECT ID, NbrActiveContracts__c FROM Account WHERE ID = :accountList[0].ID];
        
        String errorMessage;
        
        try {
            delete testAccount;
        }
        catch(DMLException e) {
            errorMessage = e.getDMLMessage(0);
        }
        
        System.assertEquals(errorMessage, Label.ACC0044);
    }    
    public static testmethod void accountDeleteTest() {
    
        System__c testSystem = WebServiceUtilities_TEST.createSystem();
        insert testSystem;

        WS_WebService__c testWebService = WebServiceUtilities_TEST.createWebService(testSystem.ID);
        testWebService.ApexClassName__c = 'WS12_MdmUpsertAccount';
        insert testWebService;
              
        WebServiceModule.isActive = false;
        
        Country__c testCountry = TestMethods.createCountry();
        insert testCountry;        
        insert TestMethods.createAccount(testCountry.ID);   
        
        TriggerBypass.reset();
        WebServiceModule.isActive = true;
        
        delete [SELECT Id FROM Account LIMIT 1];
        
        List<Account> deletedAccount  = [SELECT Id FROM Account LIMIT 1 ALL ROWS];

        TriggerBypass.reset();
        WebServiceModule.isActive = true;
               
        undelete deletedAccount;    
    }
    
    //TestMethod to test the CommercialHeirarchyRule and Address updation on related contacts.
    public static testmethod void commercialHeirarchytest() {
    WebServiceModule.isActive = false;
        
    Country__c testCountry = TestMethods.createCountry();
    insert testCountry;
    StateProvince__c state = new StateProvince__c(Name = 'Test State', Country__c=testCountry.ID);        
    insert state;    
    List<Account> accountList = new List<Account>();
        
    for(Integer i=0; i<5; i++) {
        accountList.add(TestMethods.createAccount(testCountry.ID));
    }  
    accountList[0].MainState__c    = state.ID;     
    insert accountList;
    Contact testContact = TestMethods.createContact(accountlist[0].ID);
    testContact.OfficeAddress1__c = 'Test Address 1';
    testContact.OfficeAddress2__c = 'Test Address 2';
    testContact.OfficeAddress3__c = 'Test Address 3';
    testContact.OfficePOBox__c    = 'BOX';        
    testContact.OfficeCity__c     = 'Test City';        
    testContact.OfficeZipCode__c  = '00000';        
    testContact.OfficeState__c    = state.ID;        
    testContact.OfficeCountry__c  = testCountry.ID;             
    insert testContact;         
    accountlist[0].PendingAccountLink__c = accountlist[1].id;
    accountlist[0].MainAddress1__c = 'Updated Address';
    update accountlist[0];
    accountlist[1].PendingAccountLink__c = accountlist[0].id;
    update accountlist[1];    
      
    }
    
    public static testmethod void testPropogateScoring() {
        WebServiceModule.isActive = false;
        System__c testSystem = WebServiceUtilities_TEST.createSystem();
        insert testSystem;

        WS_WebService__c testWebService = WebServiceUtilities_TEST.createWebService(testSystem.ID);
        testWebService.ApexClassName__c = 'WS12_MdmUpsertAccount';
        insert testWebService;
              
        Country__c testCountry = TestMethods.createCountry();
        insert testCountry; 
        Account TestAcc = TestMethods.createAccount(testCountry.ID);
        insert TestAcc;
        Opportunity oppty = TestMethods.createOpportunity(TestAcc.Id);
        insert oppty;
        Hotel__c testHotel = TestMethods.CreateHotel();
        insert testHotel;
        
        AccountHotelView__c AccHotelView = New AccountHotelView__c(Name = 'Test AccHotelView', Account__c = TestAcc.id,Hotel__c = testHotel.Id);
        insert AccHotelView;
        //Test After Name Change.
        TestAcc.Name = 'TestAcc1234';
        Update TestAcc; 
        
        QuestionWeight__c qwght = new QuestionWeight__c(Name = 'CORPORATE',
                                                        MaturityBookingProcess__c = 15,
                                                        MaturityClientOrg__c = 20,
                                                        MaturityContractingProcess__c = 15,
                                                        PotentialAddBusiness__c = 20,
                                                        QualityBusinessClient__c = 15,
                                                        QualityComRelation__c = 15);
        insert qwght;
        
        ScoringTreshold__c scThld = new ScoringTreshold__c(Name= 'CORPORATE',
                                                           Key__c = 500000, 
                                                           Local__c = 20000, 
                                                           National__c = 100000, 
                                                           Strategic__c = 1500000);
        insert scThld ;
        //For Scoring Propogation.
        List<Account> lstAccount = new List<Account>();
            for(integer i = 0; i<8 ; i++){
                       Account acc = TestMethods.CreateAccount(testCountry.id);
                       acc.name = 'testacc'+i;
                       lstAccount.add(acc);
                }
            insert lstAccount;
            
            for(integer i = 1; i<8 ; i++){
                    lstAccount[i].comparent__c = lstAccount[i-1].id;
            }
            update lstAccount;   
            AccountScoring__c accountScoring1 = TestMethods.createAccountScoring(lstAccount[0].id);  
              accountScoring1.Year__c = '2014';
              accountScoring1.MaturityBookingProcess__c = '0'; 
              accountScoring1.MaturityClientOrg__c  = '0';
              accountScoring1.PotentialAddBusiness__c = '0';
              accountScoring1.MaturityContractingProcess__c = '0';
              accountScoring1.QualityComRelation__c = '0';
              accountScoring1.QualityBusinessClient__c  = '0'; 
              accountScoring1.status__c='Validated';  
              insert accountScoring1;
              
              List <Id> globalAccIds = new List<Id>();
              globalAccIds.add(lstAccount[0].id);
              AP01_AccountMethods.PropogateScoringToChildsSync(globalAccIds); 
         }

        //TMA Team created the below method to test functionality of QC# 11719
        public static testmethod void testShareAccountWithHotelUsers() {

        List<Account> accList = new List<Account>();
        List<Account> accUpdateList = new List<Account>();
        
        Country__c testCountry = TestMethods.createCountry();
        insert testCountry;
        
        Account acc1 = TestMethods.createAccount(testCountry.Id);
        acc1.Name = 'Hotel User Account 1';
        acc1.OwnerId = Label.AnaisHotelDatabaseId;
        accList.add(acc1); 
        Test.startTest();
        insert accList;

        User u = TestMethods.createHotelUser();
        AP22_SharingMethods.shareRecords(new Map<Id, Set<Id>>{acc1.Id => new Set<Id>{u.Id}}, 
                                         new AP22_SharingMethods.shareAccount(), 'Read');

        AP01_AccountMethods.shareAccountWithHotelUsers(accList,'Read');
        
        List<String> accIds = new List<String>();
        accIds.add(String.valueOf(acc1.Id));
        
        AP01_AccountMethods.PropogateScoringToChilds(accIds);
        AP01_AccountMethods.checkPhoneNumbers(accList);
        
        Account acc2 = TestMethods.createAccount(testCountry.Id);
        acc2.Name = 'Central User Account 1';
        acc2.OwnerId = UserInfo.getUserId();
        insert acc2;        
        acc2.OwnerId = Label.AnaisHotelDatabaseId;
        acc1.OwnerId = UserInfo.getUserId();
        accUpdateList.add(acc1);
        accUpdateList.add(acc2);        
        update accUpdateList;
        
        Test.stopTest();        
        }

}