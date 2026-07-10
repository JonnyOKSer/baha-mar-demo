public with sharing class BahaMarUpdateReservationDates {
    public class Input {
        @InvocableVariable(label='Confirmation Number' required=true) public String confirmationNumber;
        @InvocableVariable(label='New Check-In' required=true description='YYYY-MM-DD') public String newCheckIn;
        @InvocableVariable(label='New Check-Out' required=true description='YYYY-MM-DD') public String newCheckOut;
    }
    public class Output {
        @InvocableVariable(label='Success') public Boolean success;
        @InvocableVariable(label='Summary') public String summary;
    }
    @InvocableMethod(label='BahaMar: Update Reservation Dates' description='Moves a verified Baha Mar reservation to new check-in/check-out dates. Confirm old vs new dates with the guest before calling.')
    public static List<Output> run(List<Input> inputs) {
        List<Output> outs = new List<Output>();
        for (Input i : inputs) {
            Output o = new Output(); o.success = false;
            String conf = i.confirmationNumber == null ? '' : i.confirmationNumber.trim().toUpperCase();
            List<BahaMar_Reservation__c> rs = [SELECT Id, Name, CheckIn__c, CheckOut__c, GuestCount__c FROM BahaMar_Reservation__c WHERE Name = :conf LIMIT 1];
            if (rs.isEmpty()) { o.summary = 'Reservation not found — please verify the guest first.'; outs.add(o); continue; }
            Date ci, co;
            try { ci = Date.valueOf(i.newCheckIn); co = Date.valueOf(i.newCheckOut); }
            catch (Exception ex) { o.summary = 'Could not read the dates — please use YYYY-MM-DD.'; outs.add(o); continue; }
            if (!co.isSameDay(ci) && co < ci) { o.summary = 'Check-out must be after check-in.'; outs.add(o); continue; }
            BahaMar_Reservation__c r = rs[0];
            String oldRange = String.valueOf(r.CheckIn__c) + ' to ' + String.valueOf(r.CheckOut__c);
            r.CheckIn__c = ci; r.CheckOut__c = co; r.Status__c = 'Modified';
            update r;
            o.success = true;
            o.summary = 'Reservation ' + r.Name + ' moved from ' + oldRange + ' to ' + String.valueOf(ci) + ' to ' + String.valueOf(co)
                + ' for ' + String.valueOf(Integer.valueOf(r.GuestCount__c)) + ' guests. No change fee (more than 14 days before arrival).';
            outs.add(o);
        }
        return outs;
    }
}
