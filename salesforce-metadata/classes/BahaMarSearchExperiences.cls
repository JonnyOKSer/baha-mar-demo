public with sharing class BahaMarSearchExperiences {
    public class Input {
        @InvocableVariable(label='Keyword' description='Optional keyword, e.g. turtle, golf, kids, spa, cabana') public String keyword;
        @InvocableVariable(label='Minimum guest age' description='Optional: youngest participant age, to filter age-restricted experiences') public Integer youngestAge;
    }
    public class Output {
        @InvocableVariable(label='Results') public String results;
    }
    @InvocableMethod(label='BahaMar: Search Experiences' description='Searches bookable Baha Mar experiences by keyword and age suitability. Returns names, prices, schedules and age minimums.')
    public static List<Output> run(List<Input> inputs) {
        List<Output> outs = new List<Output>();
        for (Input i : inputs) {
            String kw = i.keyword == null ? '' : i.keyword.trim();
            List<BahaMar_Experience__c> all = [SELECT Name, Description__c, MinAge__c, Price__c, Schedule__c FROM BahaMar_Experience__c ORDER BY Price__c LIMIT 50];
            List<BahaMar_Experience__c> exps = new List<BahaMar_Experience__c>();
            if (kw != '') {
                String needle = i.keyword.trim().toLowerCase();
                for (BahaMar_Experience__c e : all) {
                    String hay = (e.Name + ' ' + (e.Description__c == null ? '' : e.Description__c)).toLowerCase();
                    if (hay.contains(needle)) exps.add(e);
                }
            }
            if (exps.isEmpty()) exps = all;
            List<String> lines = new List<String>();
            for (BahaMar_Experience__c e : exps) {
                if (i.youngestAge != null && e.MinAge__c != null && i.youngestAge < e.MinAge__c) continue;
                lines.add(e.Name + ' — $' + String.valueOf(e.Price__c) + ' — ' + e.Schedule__c
                    + (e.MinAge__c != null && e.MinAge__c > 0 ? ' — min age ' + String.valueOf(Integer.valueOf(e.MinAge__c)) : '')
                    + ' :: ' + (e.Description__c == null ? '' : e.Description__c.abbreviate(180)));
            }
            Output o = new Output();
            o.results = lines.isEmpty() ? 'No experiences matched.' : String.join(lines, '\n');
            outs.add(o);
        }
        return outs;
    }
}
