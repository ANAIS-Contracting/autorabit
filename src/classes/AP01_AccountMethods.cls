/** 
 * Apex class containing static methods triggered by account events. 
 *
 * @author  Nicolas Palitzyne <nicolas.palitzyne@accenture.com>
 * @version 1.0
 * @date    23/11/2012 
 * 
 * @see     Account triggers
 */
Public class AP01_AccountMethods {
    public static boolean recursionFlag = true;
    public static Map<String, String> classificationMap;
    public static Set<Id> businessAccountIdSet = new Set<Id>();
    
    public static RecordType hotelRt {
        get {
            if(hotelRt == null) {
                hotelRt = [SELECT Id, SobjectType, Name FROM RecordType 
                           WHERE Name ='Hotel' AND SobjectType = 'Account' LIMIT 1];           
            }
            
            return hotelRt ;
        }
    }

    /**
     * Copies the main address into the billing address of an account.
     * Triggered by account creation and update when the "copy main address
     * to billing address" checkbox is checked.
     *
     * @param  anAccountList The list of accounts to update
     * @return void
     */    
    public static void copyAddress(List<Account> anAccountList) 
    {
        for(Account accountItem:anAccountList) {
            if(accountItem.CopyMaintoBill__c) {
            
                // Copy the main address to the Billing Address only if the Main Address is valid
                if((accountItem.MainAddress1__c != null || accountItem.MainPOBox__c != null)) {

                    accountItem.BillingAddress1__c  = accountItem.MainAddress1__c;
                    accountItem.BillingAddress2__c  = accountItem.MainAddress2__c;
                    accountItem.BillingAddress3__c  = accountItem.MainAddress3__c;
                    accountItem.BillingZipCode__c   = accountItem.MainZipCode__c;
                    accountItem.BillingState__c     = accountItem.MainState__c;
                    accountItem.BillingCountry__c   = accountItem.MainCountry__c;
                    accountItem.BillingCity__c      = accountItem.MainCity__c;
                    accountItem.BillingPOBox__c     = accountItem.MainPOBox__c;
                    accountItem.CopyMaintoBill__c   = false;
                }
            }
        }
    }
    
    /**
     * Static method called from the AccountBeforeDelete trigger.
     * Add an error if the number of active contracts related to the
     * account is greater than 0
     *
     * @param  anAccountList The list of accounts to delete
     * @return void
     */        
    public static void preventDeletion(List<Account> anAccountList) {
    
        Map<ID,Integer> activeBeneficiariesNbr      = new Map<ID,Integer>();
        Map<ID,Integer> activeDistributionAgencyNbr = new Map<ID,Integer>();
        
        Set<ID> accountIDSet = new Set<ID>();
        for(Account acc:anAccountList) {
            accountIDSet.add(acc.ID);
        }
        
        for(Account  acc:[SELECT ID, NbrActiveContracts__c, 
                                (SELECT ID, ContractHeader__r.Active__c FROM ContractBeneficiaries__r WHERE ContractHeader__r.Active__c = true),
                                (SELECT ID, ContractHeader__r.Active__c FROM DistributionAgencies__r WHERE ContractHeader__r.Active__c = true)
                                 FROM Account WHERE ID IN :accountIDSet ]) {
            activeBeneficiariesNbr.put(acc.ID, acc.ContractBeneficiaries__r.size());  
            activeDistributionAgencyNbr.put(acc.ID, acc.DistributionAgencies__r.size());                             
        }
    
        for(Account accountItem:anAccountList) {
            if( accountItem.NbrActiveContracts__c > 0 
               || activeBeneficiariesNbr.get(accountItem.ID) > 0
               || activeDistributionAgencyNbr.get(accountItem.ID) > 0) {
               
                accountItem.addError(Label.ACC0044);
            }
        }
    }

    public static String getClassificationLabel(String classificationCode) {

        String classificationLabel;

        if(classificationCode != null) {
            if(classificationMap == null) {
                
                classificationMap = new Map<String, String>();
                
                Schema.DescribeFieldResult fieldResult = AccountScoring__c.AccountClassification__c.getDescribe();
                List<Schema.PicklistEntry> picklistEntries = fieldResult.getPicklistValues(); 
        
                for(Schema.PicklistEntry picklistEntry:picklistEntries) {
                    classificationMap.put(picklistEntry.getValue(), picklistEntry.getLabel());
                }                
            }
            
            classificationLabel = classificationMap.get(classificationCode);
                        
        }   
        
        return classificationLabel;
    }
    
    public static void bypassValidationRules(Set<Id> anAccountIdSet) {
        
        List<Account> bypassedAccountList = new List<Account>();
        
        for(Account account:[SELECT Id, TECH_BypassVR__c, TECH_LastByPassVR__c FROM Account WHERE Id IN :anAccountIdSet]) {
            account.TECH_BypassVR__c = true;
            account.TECH_LastByPassVR__c = false; 
            bypassedAccountList.add(account);           
        }
        List<Database.SaveResult> accSaveResult = Database.update(bypassedAccountList);
    }
    
    public static void checkPhoneNumbers(List<Account> anAccountList) {
    
        if(anAccountList != null && !anAccountList.isEmpty()) {

            for(Account anAccount:anAccountList) {
                if(anAccount != null) {
                    
                    String phoneError = PhoneNumber.getPhoneError(anAccount.Phone);
                    if(phoneError != null ) {
                        anAccount.Phone.addError(phoneError);
                    }
    
                    String faxError = PhoneNumber.getFaxError(anAccount.Fax);
                    if(faxError != null ) {
                        anAccount.Fax.addError(faxError);
                    }
                }        
            }           
        }
    }
    
    /**
     * Method returning a list containing only Business Accounts (excluding Hotel Partners)
     * @param  anAccountList  A list of Account
     * @return List<Account>  A list of account excluding Hotel Account
     */
    public static List<Account> getBusinessAccount(List<Account> anAccountList) {

        List<Account> businessAccountList = new List<Account>(); 
        
        if(anAccountList != null && !anAccountList.isEmpty()) {
                
            for(Account account:anAccountList) {
                if((account.RecordTypeId != hotelRt.Id && !account.TECH_LastByPassVR__c)
                    || (account.Id != null && businessAccountIdSet.contains(account.Id))) {
                    businessAccountList.add(account);
                }
            }        
        }

        return businessAccountList;
    } 
    
    /**
     * Method returning a list containing only Hotel Account
     * @param  anAccountList  A list of Account
     * @return List<Account>  A list of Hotel Accounts
     */
    public static List<Account> getHotelAccount(List<Account> anAccountList) {

        List<Account> hotelAccountList = new List<Account>(); 
        
        if(anAccountList != null && !anAccountList.isEmpty()) {

            for(Account account:anAccountList) {
                if(account.RecordTypeId == hotelRt.Id && !account.TECH_LastByPassVR__c) {
                    hotelAccountList.add(account);
                }
            }        
        }

        return hotelAccountList;
    }
     
    /**
     * Method added for QC 9903    
     * Method preventing the loop in Commercial Parent Heirarchy.
     * @param  AccountList  A list of Account and a List of String(Containing parent Acoount Ids.)
     * @return null
     */
     public static List<Account> preventCommercialLoop(List<Account> AccountList, List<String> newParentList) {
     System.debug('AccountList-->'+AccountList);
     System.debug('newParentList-->'+newParentList);     
     Map<String,Account> Parentmap = new map<String,Account>();
     // Get the account Id and Tech_AllParents__c field in a Map for all parent Account records.     
     for(account paracc : [Select Tech_AllParents__c from account where id in :newParentList]){
         Parentmap.put(paracc.id,paracc);
         }
     System.debug('Parentmap-->'+Parentmap);             
     List<String> accIds = new List<String>();
     Set<String> uniqueAccs = new Set<String>();
     //Iterate on all account records.
     System.Debug('%%%'+AccountList);          
     for(Account acc : AccountList){
     System.Debug('%%%'+acc);
         Account account =  new Account();     
         if(acc.PendingAccountLink__c != null){     
             account = Parentmap.get(acc.PendingAccountLink__c);}
         else if(acc.PendingAccountLink__c == null && acc.comparent__c != null){
             account = Parentmap.get(acc.comparent__c);}         
         //Get all parents in a string.
         String parAccounts = String.valueOf(account.Tech_AllParents__c);
         //Split the String based on ',' and get ids in a list.           
         accIds = parAccounts.split(',');         
         uniqueAccs.addall(accIds);
         System.Debug(acc.Id);       
         String accountId =  acc.id;
         //if the account record is the parent of the record that is being chosen as new parent,display error.                
         if(uniqueAccs.Size() > 0){
             if(uniqueAccs.contains(accountId.substring(0,15))){
             acc.addError(Label.ErrorMessageAccountHeirarchy); 
             }
         }           
         }       
     return null; 
     }     

    /**
     * Method to update the Office address of all related contacts. QC 9897
     * @param  accountList  A list of Account
     */
     Public Static void UpdateRelatedContactAddress(Map<String, Account> oldValMap,Map<String, Account> newValMap){

        List<Contact> updatedContactList = new List<Contact>();
        
        for(Contact con :[SELECT FirstName, LastName, AccountId, OfficeAddress2__c, OfficePOBox__c, OfficeZipCode__c, OfficeState__c, 
                      OfficeCountry__c,OfficeCity__c,OfficeAddress3__c,OfficeAddress1__c 
                      FROM Contact where AccountId IN :newValMap.keyset()]) {
        
            Account oldRecord = oldValMap.get(con.AccountId);
            Account newRecord = newValMap.get(con.AccountId);

            if(con.OfficeAddress1__c == oldRecord.MainAddress1__c 
                && con.OfficeAddress2__c == oldRecord.MainAddress2__c 
                && con.OfficeAddress3__c == oldRecord.MainAddress3__c 
                && con.OfficeCity__c == oldRecord.MainCity__c 
                && con.OfficeCountry__c == oldRecord.MainCountry__c 
                && con.OfficeState__c == oldRecord.MainState__c 
                && con.OfficeZipCode__c == oldRecord.MainZipCode__c 
                && con.OfficePOBox__c == oldRecord.MainPOBox__c){            
                
                con.OfficeAddress1__c = newRecord.MainAddress1__c;
                con.OfficeAddress2__c = newRecord.MainAddress2__c;
                con.OfficeAddress3__c = newRecord.MainAddress3__c;
                con.OfficeCity__c     = newRecord.MainCity__c;
                con.OfficeCountry__c  = newRecord.MainCountry__c;
                con.OfficeState__c    = newRecord.MainState__c;
                con.OfficeZipCode__c  = newRecord.MainZipCode__c;
                con.OfficePOBox__c    = newRecord.MainPOBox__c;
                
                updatedContactList.add(con);
            }   
        }
        
        if(!updatedContactList.isEmpty()) {
        
            // If batch is required, then queue the request, else synchronize as usual
            Boolean isWebServiceModuleActive = WebServiceModule.isActive;
            
            if(updatedContactList.size() > 1) {
                
                List<WebServiceModule.Request> requestList = WebServiceModule.getRequests(updatedContactList, 'WS11_MdmUpsertContact');

                WebServiceDML.insertNewRequests(requestList);
                WebServiceModule.isActive = false; 
            }
            
            List<Database.SaveResult> contactSaveResult = Database.update(updatedContactList, false);
            WebServiceModule.isActive = isWebServiceModuleActive; // Activate the Integration Module     
        }         
    }  
    
    /**
     * Method to update the Office address of all related contacts. QC 9897
     * @param  accountList  A list of Account
     */
     Public Static void PropogateUpdatedAccountName(List<Account> accLst){
    
        if(accLst != null && !accLst.isEmpty()) {
        
            Map<id,Account> accIdMap = new Map<Id,Account>();
            accIdMap.putall(accLst);
            
            List<opportunity> opptyLst=[Select name,accountId from Opportunity where accountId in :accIdMap.keyset()];
            
            if(opptyLst.size()>0){
                for(Opportunity opp : opptyLst){
                    opp.Tech_AccountName__c = accIdMap.get(opp.AccountId).name;
                }
                
                try{
                    update opptyLst;
                }
                catch(Exception e){
                
                }
            }
            
            // Update related Account - Hotel Internal Information 
            List<AccountHotelView__c> accHotelInfoList = new List<AccountHotelView__c>();
            
            for(AccountHotelView__c accHotelInfo:[SELECT Id, Account__c FROM AccountHotelView__c 
                                                  WHERE Account__c IN :accIdMap.keySet() LIMIT 2000]) {
            
                accHotelInfo.Name = accIdMap.get(accHotelInfo.Account__c).Name + ' '+Label.Internal;
                accHotelInfoList.add(accHotelInfo);
            }
            
            if(!accHotelInfoList.isEmpty()) {
                List<Database.SaveResult> accInfoResults = Database.update(accHotelInfoList, false);
            }             
        }
    } 
    
    /**
     * Future Method to propogate Account Scoring from Global Parent Account
     * to all child Account records - QC 9764
     * Added on 8/8/2014 by Veenesh.vikram
     * @param  globalAccIds - A list of Global AccountIds
     */
     @future
     Public Static Void PropogateScoringToChilds(List<string> globalAccIds){
     List<Account> childAccountList = new List<Account>();                                   //List of all Child Accounts.
         if(globalAccIds != null && !globalAccIds.isEmpty()) {
        
            Set<Id> accountIdSet = new Set<Id>();                                           //Set of AccountIds per Iteration
        
                for(String anAccount:globalAccIds) {
                    accountIdSet.add(anAccount);                                                                 //populate accountIdSet for first Iteration.
                }
        
        Boolean hasChildren = true;            //Boolean True for first iteration.    
        Integer levelNumber = 0;               //Level number set to Zero. 
        
        //While Childs are present and Level of child is less than 10.
        while(hasChildren && levelNumber < 10) {

            hasChildren = false;
            Set<Id> childAccountIdSet = new Set<Id>();


            List<Account> MasterList = [SELECT Id,ComParent__c, TECH_GlobalMasterID__c,RecordTypeId,name,TECH_LastByPassVR__c, (SELECT Id,name, TECH_GlobalMasterID__c, ComParent__c,RecordTypeId,TECH_LastByPassVR__c FROM Accounts2__r) 
                                      FROM Account WHERE Id IN :accountIdSet];
            
            for(Account childAccount:MasterList) {
                    childAccountList.addAll(childAccount.Accounts2__r);

                if(!childAccount.Accounts2__r.isEmpty()) { 
                    hasChildren = true;
                    
                    for(Account childAccount1:childAccount.Accounts2__r) {
                            childAccountIdSet.add(childAccount1.Id);
                    }
                }
            }
            accountIdSet = childAccountIdSet;
            if(haschildren == True){
            levelNumber++;
            }
        }
    }

    //Create Requests for All child Accounts.
    if(!childAccountList.isEmpty()){     
    List<Account> childBusinessAccountList = AP01_AccountMethods.getBusinessAccount(childAccountList); 
        if(childBusinessAccountList.size() > 0){  
        try{      
            List<WebServiceModule.Request> requestList = WebServiceModule.getRequests(childBusinessAccountList, 'WS12_MdmUpsertAccount');   
            WebServiceDML.insertNewRequests(requestList);
        }
        Catch(Exception e){
        
        }
        }
    }
    }
    
    
    /**
     * Future Method to propogate Account Scoring from Global Parent Account
     * to all child Account records - QC 9764
     * Added on 8/8/2014 by Veenesh.vikram
     * @param  globalAccIds - A list of Global AccountIds
     */
     Public Static Void PropogateScoringToChildsSync(List<string> globalAccIds){
     System.debug('CalledSync');
     List<Account> childAccountList = new List<Account>();
         if(globalAccIds != null && !globalAccIds.isEmpty()) {
        
            Set<Id> accountIdSet = new Set<Id>();                                           //Set of AccountIds per Iteration
        
                for(String anAccount:globalAccIds) {
                    accountIdSet.add(anAccount);                                                                 //populate accountIdSet for first Iteration.
                }
        
        Boolean hasChildren = true;            //Boolean True for first iteration.    
        Integer levelNumber = 0;               //Level number set to Zero. 
        
        //While Childs are present and Level of child is less than 10.
        while(hasChildren && levelNumber < 10) {

            hasChildren = false;
            Set<Id> childAccountIdSet = new Set<Id>();

            List<Account> MasterList = [SELECT Id,ComParent__c, TECH_GlobalMasterID__c,RecordTypeId,name,TECH_LastByPassVR__c, (SELECT Id,name, TECH_GlobalMasterID__c, ComParent__c,RecordTypeId,TECH_LastByPassVR__c FROM Accounts2__r) 
                                      FROM Account WHERE Id IN :accountIdSet];
            
            for(Account childAccount:MasterList) {

                    childAccountList.addAll(childAccount.Accounts2__r);

                if(!childAccount.Accounts2__r.isEmpty()) { 
                    hasChildren = true;
                    
                    for(Account childAccount1:childAccount.Accounts2__r) {
                            childAccountIdSet.add(childAccount1.Id);
                    }
                }
            }
            accountIdSet = childAccountIdSet;
            if(haschildren == True){
            levelNumber++;
            }
        }
    }
    //Create Requests for All child Accounts.
    if(!childAccountList.isEmpty()){     
    List<Account> childBusinessAccountList = AP01_AccountMethods.getBusinessAccount(childAccountList); 
        if(childBusinessAccountList.size() > 0){        
            try{
            List<WebServiceModule.Request> requestList = WebServiceModule.getRequests(childBusinessAccountList, 'WS12_MdmUpsertAccount');   
            WebServiceDML.insertNewRequests(requestList);
            }
            catch(Exception e){
              
            } 
        }
    }
    }
    
    //TMA Team created the method to change Account access from 'Read Only' to 'Read Write'
    //to Hotel users, when Account Owner is changed from Central User to Hotels Database and
    //to change Account access from 'Read Write' to 'Read Only', when Account Owner is changed
    //from Hotels Database to Central User, as per QC# 11719
    public static void shareAccountWithHotelUsers(List<Account> accList, String accessLevel){

        Map<Id, List<AccountShare>> accShareMap = new Map<Id, List<AccountShare>>();
        Set<Id> accIdSet = new Set<Id>();
        Set<Id> groupIdSet = new Set<Id>();
        List<AccountShare> accShareUpdateList = new List<AccountShare>();
        
        for(Account a : accList){
            accIdSet.add(a.Id);
        }
    
        List<AccountShare> accShareList = [SELECT Id,AccountAccessLevel,AccountId,RowCause,UserOrGroupId FROM AccountShare WHERE RowCause = 'Manual' AND AccountId IN : accIdSet];
    
        if(!accShareList.isEmpty() && accShareList.size() > 0){
        
            for(AccountShare a : accShareList){
                groupIdSet.add(a.UserOrGroupId);
            }
        
            List<Group> groupList = [SELECT DeveloperName,Id,Name,Type FROM Group WHERE Id IN : groupIdSet];
    
            for(AccountShare accShare : accShareList){
    
                if(!accShareMap.containskey(accShare.AccountId)) {
                    accShareMap.put(accShare.AccountId, new List<AccountShare>());
                }
                accShareMap.get(accShare.AccountId).add(accShare);
            }
            
            for(Account a : accList){
                List<AccountShare> accShareList1 = accShareMap.get(a.Id);
                    for(AccountShare share : accShareList1){
                        for(Group grp : groupList){
                            if(share.UserOrGroupId == grp.Id && grp.DeveloperName.contains('PartnerExecutive')){
                                share.AccountAccessLevel = accessLevel;
                                accShareUpdateList.add(share);
                            }
                        }
                    }
                }
            
            if(accShareUpdateList.size() > 0){
                database.update(accShareUpdateList);
            }
        }
    }
}