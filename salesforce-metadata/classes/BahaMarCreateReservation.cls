public with sharing class BahaMarCreateReservation {
    public class Input {
        @InvocableVariable(label='Guest Email' required=true) public String guestEmail;
        @InvocableVariable(label='Check-In' required=true description='YYYY-MM-DD') public String checkIn;
        @InvocableVariable(label='Check-Out' required=true description='YYYY-MM-DD') public String checkOut;
        @InvocableVariable(label='Guest Count' required=true) public Integer guestCount;
        @InvocableVariable(label='Hotel' required=true description='Grand Hyatt, SLS, or Rosewood') public String hotel;
        @InvocableVariable(label='Room Type' required=true) public String roomType;
    }
    public class Output {
        @InvocableVariable(label='Success') public Boolean success;
        @InvocableVariable(label='Confirmation Number') public String confirmationNumber;
        @InvocableVariable(label='Summary') public String summary;
    }
    @InvocableMethod(label='BahaMar: Create Reservation' description='Creates a new Baha Mar reservation for a known guest (by email) and returns the confirmation number.')
    public static List<Output> run(List<Input> inputs) {
        List<Output> outs = new List<Output>();
        for (Input i : inputs) {
            Output o = new Output(); o.success = false;
            List<Contact> cs = [SELECT Id, Name FROM Contact WHERE Email = :i.guestEmail LIMIT 1];
            if (cs.isEmpty()) { o.summary = 'No guest found with that email.'; outs.add(o); continue; }
            Date ci, co;
            try { ci = Date.valueOf(i.checkIn); co = Date.valueOf(i.checkOut); }
            catch (Exception ex) { o.summary = 'Could not read the dates — please use YYYY-MM-DD.'; outs.add(o); continue; }
            String conf = 'BM-' + String.valueOf(Math.mod(Math.abs(Crypto.getRandomInteger()), 9000) + 1000);
            insert new BahaMar_Reservation__c(Name = conf, Contact__c = cs[0].Id, CheckIn__c = ci, CheckOut__c = co,
                GuestCount__c = i.guestCount, Hotel__c = i.hotel, RoomType__c = i.roomType, Status__c = 'Booked');
            o.success = true; o.confirmationNumber = conf;
            o.summary = 'Reservation ' + conf + ' confirmed at ' + i.hotel + ' (' + i.roomType + '), '
                + i.checkIn + ' to ' + i.checkOut + ', ' + String.valueOf(i.guestCount) + ' guests, for ' + cs[0].Name + '.';
            outs.add(o);
        }
        return outs;
    }
}
