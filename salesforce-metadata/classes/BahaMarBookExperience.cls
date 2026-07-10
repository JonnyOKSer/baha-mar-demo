public with sharing class BahaMarBookExperience {
    public class Input {
        @InvocableVariable(label='Experience Name' required=true) public String experienceName;
        @InvocableVariable(label='Confirmation Number' required=true description='The guest reservation confirmation number, e.g. BM-4271') public String confirmationNumber;
        @InvocableVariable(label='Date' required=true description='Booking date in YYYY-MM-DD format') public String bookingDate;
        @InvocableVariable(label='Party Size' required=true) public Integer partySize;
    }
    public class Output {
        @InvocableVariable(label='Success') public Boolean success;
        @InvocableVariable(label='Confirmation') public String confirmation;
    }
    @InvocableMethod(label='BahaMar: Book Experience' description='Books a Baha Mar experience for a verified guest reservation. Requires experience name, confirmation number, date (YYYY-MM-DD) and party size.')
    public static List<Output> run(List<Input> inputs) {
        List<Output> outs = new List<Output>();
        for (Input i : inputs) {
            Output o = new Output(); o.success = false;
            String conf = i.confirmationNumber == null ? '' : i.confirmationNumber.trim().toUpperCase();
            List<BahaMar_Reservation__c> rs = [SELECT Id, Name FROM BahaMar_Reservation__c WHERE Name = :conf LIMIT 1];
            String key = i.experienceName == null ? '' : '%' + i.experienceName.trim() + '%';
            List<BahaMar_Experience__c> es = [SELECT Id, Name, Price__c, MinAge__c, Schedule__c FROM BahaMar_Experience__c WHERE Name LIKE :key LIMIT 1];
            if (rs.isEmpty()) { o.confirmation = 'Reservation not found — please verify the guest first.'; outs.add(o); continue; }
            if (es.isEmpty()) { o.confirmation = 'Experience "' + i.experienceName + '" not found.'; outs.add(o); continue; }
            Date d;
            try { d = Date.valueOf(i.bookingDate); } catch (Exception ex) { o.confirmation = 'Could not read the date — please use YYYY-MM-DD.'; outs.add(o); continue; }
            BahaMar_Experience_Booking__c b = new BahaMar_Experience_Booking__c(
                Reservation__c = rs[0].Id, Experience__c = es[0].Id, Date__c = d,
                PartySize__c = i.partySize, Status__c = 'Confirmed');
            insert b;
            b = [SELECT Name FROM BahaMar_Experience_Booking__c WHERE Id = :b.Id];
            o.success = true;
            o.confirmation = es[0].Name + ' confirmed for ' + String.valueOf(d) + ', party of ' + String.valueOf(i.partySize)
                + '. Booking ref ' + b.Name + '. $' + String.valueOf(es[0].Price__c * i.partySize) + ' charged to room (' + rs[0].Name + ').';
            outs.add(o);
        }
        return outs;
    }
}
