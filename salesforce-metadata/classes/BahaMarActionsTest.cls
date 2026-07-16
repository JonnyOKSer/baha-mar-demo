@IsTest
private class BahaMarActionsTest {
    @TestSetup
    static void setup() {
        Contact c = new Contact(FirstName='Jason', LastName='Mitchell', Email='jason.mitchell@bahamar-demo.example');
        insert c;
        insert new BahaMar_Reservation__c(Name='BM-4271', Contact__c=c.Id, CheckIn__c=Date.today().addDays(30),
            CheckOut__c=Date.today().addDays(37), GuestCount__c=4, Hotel__c='Grand Hyatt', RoomType__c='Grand Suite', Status__c='Booked');
        insert new BahaMar_Experience__c(Name='Turtle Tales', Description__c='Hands-on sea turtle encounter',
            MinAge__c=8, Price__c=89, Schedule__c='Thu-Mon 11:00 and 14:30', Capacity__c=10);
    }

    @IsTest static void verifyGuestHappyAndSad() {
        BahaMarVerifyGuest.Input ok = new BahaMarVerifyGuest.Input();
        ok.guestName='Jason Mitchell'; ok.confirmationNumber='bm-4271';
        BahaMarVerifyGuest.Input bad = new BahaMarVerifyGuest.Input();
        bad.guestName='Someone Else'; bad.confirmationNumber='BM-0000';
        List<BahaMarVerifyGuest.Output> outs = BahaMarVerifyGuest.run(new List<BahaMarVerifyGuest.Input>{ok, bad});
        System.assertEquals(true, outs[0].verified);
        System.assert(outs[0].summary.contains('BM-4271'));
        System.assertEquals(false, outs[1].verified);
    }

    @IsTest static void searchExperiences() {
        BahaMarSearchExperiences.Input i = new BahaMarSearchExperiences.Input();
        i.keyword='turtle'; i.youngestAge=8;
        List<BahaMarSearchExperiences.Output> outs = BahaMarSearchExperiences.run(new List<BahaMarSearchExperiences.Input>{i});
        System.assert(outs[0].results.contains('Turtle Tales'));
        BahaMarSearchExperiences.Input tooYoung = new BahaMarSearchExperiences.Input();
        tooYoung.keyword='turtle'; tooYoung.youngestAge=5;
        System.assertEquals('No experiences matched.', BahaMarSearchExperiences.run(new List<BahaMarSearchExperiences.Input>{tooYoung})[0].results);
    }

    @IsTest static void bookExperience() {
        BahaMarBookExperience.Input i = new BahaMarBookExperience.Input();
        i.experienceName='Turtle'; i.confirmationNumber='BM-4271';
        i.bookingDate=String.valueOf(Date.today().addDays(32)); i.partySize=2;
        List<BahaMarBookExperience.Output> outs = BahaMarBookExperience.run(new List<BahaMarBookExperience.Input>{i});
        System.assertEquals(true, outs[0].success, outs[0].confirmation);
        System.assertEquals(1, [SELECT COUNT() FROM BahaMar_Experience_Booking__c]);
        BahaMarBookExperience.Input bad = new BahaMarBookExperience.Input();
        bad.experienceName='Turtle'; bad.confirmationNumber='BM-9999'; bad.bookingDate='2026-08-18'; bad.partySize=2;
        System.assertEquals(false, BahaMarBookExperience.run(new List<BahaMarBookExperience.Input>{bad})[0].success);
    }

    @IsTest static void checkAvailability() {
        BahaMarCheckAvailability.Input i = new BahaMarCheckAvailability.Input();
        i.experienceName='Turtle'; i.bookingDate=String.valueOf(Date.today().addDays(32));
        List<BahaMarCheckAvailability.Output> outs = BahaMarCheckAvailability.run(new List<BahaMarCheckAvailability.Input>{i});
        System.assertEquals(true, outs[0].available, outs[0].slots);
        System.assert(outs[0].slots.contains('spots left'), outs[0].slots);
        System.assert(outs[0].slots.contains('VAT'), outs[0].slots);
        BahaMarCheckAvailability.Input bad = new BahaMarCheckAvailability.Input();
        bad.experienceName='Nonexistent'; bad.bookingDate=String.valueOf(Date.today().addDays(32));
        System.assertEquals(false, BahaMarCheckAvailability.run(new List<BahaMarCheckAvailability.Input>{bad})[0].available);
    }

    @IsTest static void updateDates() {
        BahaMarUpdateReservationDates.Input i = new BahaMarUpdateReservationDates.Input();
        i.confirmationNumber='BM-4271';
        i.newCheckIn=String.valueOf(Date.today().addDays(37)); i.newCheckOut=String.valueOf(Date.today().addDays(44));
        List<BahaMarUpdateReservationDates.Output> outs = BahaMarUpdateReservationDates.run(new List<BahaMarUpdateReservationDates.Input>{i});
        System.assertEquals(true, outs[0].success, outs[0].summary);
        System.assertEquals('Modified', [SELECT Status__c FROM BahaMar_Reservation__c WHERE Name='BM-4271'].Status__c);
    }

    @IsTest static void createReservation() {
        BahaMarCreateReservation.Input i = new BahaMarCreateReservation.Input();
        i.guestEmail='jason.mitchell@bahamar-demo.example';
        i.checkIn=String.valueOf(Date.today().addDays(60)); i.checkOut=String.valueOf(Date.today().addDays(63));
        i.guestCount=12; i.hotel='SLS'; i.roomType='Party Suite';
        List<BahaMarCreateReservation.Output> outs = BahaMarCreateReservation.run(new List<BahaMarCreateReservation.Input>{i});
        System.assertEquals(true, outs[0].success, outs[0].summary);
        System.assert(outs[0].confirmationNumber.startsWith('BM-'));
    }

    @IsTest static void saveRfiIncremental() {
        BahaMarSaveRFI.Input first = new BahaMarSaveRFI.Input();
        first.eventType='Birthday'; first.headcount=12; first.location='SLS';
        BahaMarSaveRFI.Output o1 = BahaMarSaveRFI.run(new List<BahaMarSaveRFI.Input>{first})[0];
        System.assertEquals('In Progress', o1.status);
        BahaMarSaveRFI.Input second = new BahaMarSaveRFI.Input();
        second.rfiId=o1.rfiId; second.contactName='Amy Rodriguez'; second.email='amy@example.com'; second.markSubmitted=true;
        BahaMarSaveRFI.Output o2 = BahaMarSaveRFI.run(new List<BahaMarSaveRFI.Input>{second})[0];
        System.assertEquals(o1.rfiId, o2.rfiId);
        System.assertEquals('Submitted', o2.status);
        System.assertEquals('Birthday', [SELECT EventType__c FROM BahaMar_RFI__c WHERE Id=:o2.rfiId].EventType__c);
    }
}
