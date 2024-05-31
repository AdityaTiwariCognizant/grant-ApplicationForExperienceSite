global with sharing class contactMeController {
    @AuraEnabled(cacheable=true)
    public static void createLead(String firstname,String lastname,String company,String email,String description){

        Lead porfoliolead = new Lead();
        porfoliolead.FirstName = firstname;
        porfoliolead.LastName = lastname;
        porfoliolead.Company = company;
        porfoliolead.Email = email;
        porfoliolead.Description = description;
        
        insert porfoliolead;
    }
}