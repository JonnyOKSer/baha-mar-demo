public with sharing class BahaMarSaveRFI {
    public class Input {
        @InvocableVariable(label='RFI Id' description='Pass back the id returned by a previous save to update the same inquiry') public String rfiId;
        @InvocableVariable(label='Event Type' description='Wedding, Honeymoon, Bachelor/Bachelorette Party, Gender Reveal, Babymoon, Birthday, Bar/Bat Mitzvah, or Anniversary') public String eventType;
        @InvocableVariable(label='Preferred Date' description='YYYY-MM-DD, approximate is fine') public String eventDate;
        @InvocableVariable(label='Headcount') public Integer headcount;
        @InvocableVariable(label='Contact Name') public String contactName;
        @InvocableVariable(label='Email') public String email;
        @InvocableVariable(label='Phone') public String phone;
        @InvocableVariable(label='Location' description='Baha Mar, Grand Hyatt, SLS, or Rosewood') public String location;
        @InvocableVariable(label='Mark Submitted' description='true when all details are collected') public Boolean markSubmitted;
    }
    public class Output {
        @InvocableVariable(label='RFI Id') public String rfiId;
        @InvocableVariable(label='Status') public String status;
        @InvocableVariable(label='Summary') public String summary;
    }
    @InvocableMethod(label='BahaMar: Save Event RFI' description='Saves an event inquiry incrementally — call after EACH new detail the guest shares so nothing is lost if they disconnect. Pass the returned RFI Id on subsequent calls.')
    public static List<Output> run(List<Input> inputs) {
        List<Output> outs = new List<Output>();
        for (Input i : inputs) {
            BahaMar_RFI__c r;
            if (String.isNotBlank(i.rfiId)) {
                List<BahaMar_RFI__c> ex = [SELECT Id, Status__c, EventType__c, EventDate__c, Headcount__c, ContactName__c, Email__c, Phone__c, Location__c FROM BahaMar_RFI__c WHERE Id = :i.rfiId LIMIT 1];
                r = ex.isEmpty() ? new BahaMar_RFI__c(Status__c = 'In Progress', Source__c = 'Concierge') : ex[0];
            } else {
                r = new BahaMar_RFI__c(Status__c = 'In Progress', Source__c = 'Concierge');
            }
            if (String.isNotBlank(i.eventType)) r.EventType__c = i.eventType;
            if (String.isNotBlank(i.eventDate)) { try { r.EventDate__c = Date.valueOf(i.eventDate); } catch (Exception ex) {} }
            if (i.headcount != null) r.Headcount__c = i.headcount;
            if (String.isNotBlank(i.contactName)) r.ContactName__c = i.contactName;
            if (String.isNotBlank(i.email)) r.Email__c = i.email;
            if (String.isNotBlank(i.phone)) r.Phone__c = i.phone;
            if (String.isNotBlank(i.location)) r.Location__c = i.location;
            if (i.markSubmitted == true) r.Status__c = 'Submitted';
            upsert r;
            Output o = new Output();
            o.rfiId = r.Id; o.status = r.Status__c;
            o.summary = 'Saved. Event: ' + String.valueOf(r.EventType__c) + ', date: ' + String.valueOf(r.EventDate__c)
                + ', headcount: ' + String.valueOf(r.Headcount__c) + ', contact: ' + String.valueOf(r.ContactName__c)
                + ' (' + String.valueOf(r.Email__c) + '), status: ' + r.Status__c;
            outs.add(o);
        }
        return outs;
    }
}
