public class GitHubRepository {
    /** Unique numeric ID from GitHub (serialised as String for LWC safety) */
    @AuraEnabled public String id { get; set; }
    /** Short repository name (e.g. "SDO575_NEW") */
    @AuraEnabled public String name { get; set; }
    /** Owner/repo slug (e.g. "rcamargo19/SDO575_NEW") */
    @AuraEnabled public String fullName { get; set; }
    /** Optional repository description */
    @AuraEnabled public String description { get; set; }
    /** Full HTTPS URL to the repository on GitHub */
    @AuraEnabled public String htmlUrl { get; set; }
    /** GitHub repository visibility */
    @AuraEnabled public String visibility { get; set; }
    /** Primary programming language (may be null) */
    @AuraEnabled public String language { get; set; }
    /** ISO 8601 repository update timestamp (e.g. "2026-11-23T16:35:38Z") */
    @AuraEnabled public String updatedAt { get; set; }
    /** Number of stars */
    @AuraEnabled public Integer stargazersCount { get; set; }
    /** Number of forks */
    @AuraEnabled public Integer forksCount { get; set; }
    /** True when the repository is private */
    @AuraEnabled public Boolean isPrivate { get; set; }
}
