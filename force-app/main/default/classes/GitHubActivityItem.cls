public class GitHubActivityItem {
    @AuraEnabled public String id { get; set; }
    @AuraEnabled public String title { get; set; }
    @AuraEnabled public String url { get; set; }
    @AuraEnabled public String author { get; set; }
    @AuraEnabled public String activityDate { get; set; }
    @AuraEnabled public String status { get; set; }
    @AuraEnabled public String mergedAt { get; set; }
}
