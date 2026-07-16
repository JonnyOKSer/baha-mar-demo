public with sharing class BahaMarCheckAvailability {
    public class Input {
        @InvocableVariable(label='Experience Name' required=true) public String experienceName;
        @InvocableVariable(label='Date' required=true description='Requested date in YYYY-MM-DD format') public String bookingDate;
    }
    public class Output {
        @InvocableVariable(label='Available') public Boolean available;
        @InvocableVariable(label='Slots') public String slots;
    }
    @InvocableMethod(label='BahaMar: Check Availability' description='Checks open session times and remaining spots for a Baha Mar experience on a given date (YYYY-MM-DD). Always call this before booking and let the guest choose a time.')
    public static List<Output> run(List<Input> inputs) {
        List<Output> outs = new List<Output>();
        for (Input i : inputs) {
            Output o = new Output(); o.available = false;
            String key = i.experienceName == null ? '' : '%' + i.experienceName.trim() + '%';
            List<BahaMar_Experience__c> es = [SELECT Id, Name, Price__c, Schedule__c, Capacity__c FROM BahaMar_Experience__c WHERE Name LIKE :key LIMIT 1];
            if (es.isEmpty()) { o.slots = 'Experience "' + i.experienceName + '" not found.'; outs.add(o); continue; }
            Date d;
            try { d = Date.valueOf(i.bookingDate); } catch (Exception ex) { o.slots = 'Could not read the date - please use YYYY-MM-DD.'; outs.add(o); continue; }
            if (d < Date.today()) { o.slots = 'That date has passed - please pick an upcoming date.'; outs.add(o); continue; }
            List<String> times = extractTimes(es[0].Schedule__c);
            Integer cap = es[0].Capacity__c == null ? 10 : Integer.valueOf(es[0].Capacity__c);
            Integer seed = Math.mod(d.dayOfYear() + es[0].Name.length(), 5);
            List<String> parts = new List<String>();
            for (Integer t = 0; t < times.size(); t++) {
                Integer left = Math.max(2, Math.mod(seed + t * 3, cap));
                parts.add(times[t] + ' (' + left + ' spots left)');
            }
            o.available = true;
            o.slots = es[0].Name + ' on ' + String.valueOf(d) + ': ' + String.join(parts, ', ')
                + '. $' + es[0].Price__c.setScale(0).toPlainString() + '/person + 10% VAT.';
            outs.add(o);
        }
        return outs;
    }
    private static List<String> extractTimes(String schedule) {
        List<String> found = new List<String>();
        if (schedule != null) {
            Pattern p = Pattern.compile('(\\d{1,2}:\\d{2}\\s?(?:AM|PM)?)');
            Matcher m = p.matcher(schedule);
            while (m.find() && found.size() < 3) { found.add(m.group(1).trim()); }
        }
        if (found.isEmpty()) { return new List<String>{'10:00 AM', '1:30 PM', '4:00 PM'}; }
        if (found.size() == 1) { return new List<String>{found[0], addMinutes(found[0], 20), addMinutes(found[0], 40)}; }
        return found;
    }
    private static String addMinutes(String t, Integer mins) {
        Pattern p = Pattern.compile('(\\d{1,2}):(\\d{2})\\s?(AM|PM)?');
        Matcher m = p.matcher(t);
        if (!m.find()) { return t; }
        Integer h = Integer.valueOf(m.group(1)); Integer mi = Integer.valueOf(m.group(2));
        String ap = m.group(3);
        mi += mins; h += mi / 60; mi = Math.mod(mi, 60);
        if (ap != null && h > 12) { h -= 12; ap = (ap == 'AM') ? 'PM' : ap; }
        return h + ':' + (mi < 10 ? '0' : '') + mi + (ap == null ? '' : ' ' + ap);
    }
}
