public with sharing class BahaMarVerifyGuest {
    public class Input {
        @InvocableVariable(label='Guest Full Name' required=true) public String guestName;
        @InvocableVariable(label='Confirmation Number' required=true) public String confirmationNumber;
    }
    public class Output {
        @InvocableVariable(label='Verified') public Boolean verified;
        @InvocableVariable(label='Reservation Id') public String reservationId;
        @InvocableVariable(label='Summary') public String summary;
    }
    @InvocableMethod(label='BahaMar: Verify Guest' description='Verifies a guest by full name and confirmation number and returns their Baha Mar reservation summary.')
    public static List<Output> run(List<Input> inputs) {
        List<Output> outs = new List<Output>();
        for (Input i : inputs) {
            Output o = new Output(); o.verified = false;
            String conf = i.confirmationNumber == null ? '' : i.confirmationNumber.trim().toUpperCase();
            List<BahaMar_Reservation__c> rs = [
                SELECT Id, Name, CheckIn__c, CheckOut__c, GuestCount__c, RoomType__c, Hotel__c, Status__c,
                       Contact__r.Name, Contact__r.FirstName
                FROM BahaMar_Reservation__c WHERE Name = :conf LIMIT 1];
            if (!rs.isEmpty() && i.guestName != null) {
                BahaMar_Reservation__c r = rs[0];
                String given = i.guestName.trim().toLowerCase();
                String onFile = r.Contact__r != null && r.Contact__r.Name != null ? r.Contact__r.Name.toLowerCase() : '';
                Boolean nameOk = onFile != '' && (onFile == given || onFile.contains(given) || given.contains(onFile)
                    || (given.split(' ').size() > 1 && onFile.contains(given.split(' ')[given.split(' ').size()-1])));
                if (nameOk) {
                    o.verified = true;
                    o.reservationId = r.Id;
                    o.summary = r.Name + ' | ' + r.Hotel__c + ' | ' + r.RoomType__c
                        + ' | ' + String.valueOf(r.CheckIn__c) + ' to ' + String.valueOf(r.CheckOut__c)
                        + ' | ' + String.valueOf(Integer.valueOf(r.GuestCount__c)) + ' guests | Status: ' + r.Status__c;
                }
            }
            if (!o.verified) o.summary = 'No matching reservation found for that name and confirmation number.';
            outs.add(o);
        }
        return outs;
    }
}
