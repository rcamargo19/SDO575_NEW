public with sharing class GitHubActivityController {
    private static final Pattern REPOSITORY_PATTERN = Pattern.compile('[A-Za-z0-9-]{1,39}/[A-Za-z0-9_.-]{1,100}');
    private static final String PAGE_SIZE = '30';

    @AuraEnabled
    public static List<String> getBranches(String repository) {
        String path = repositoryPath(repository) + '/branches?per_page=100&page=';
        Set<String> names = new Set<String>();
        Integer page = 1;

        while (Limits.getCallouts() < Limits.getLimitCallouts()) {
            HttpResponse response = request(path + page);
            for (Object branch : records(response, 'branches')) {
                names.add((String)((Map<String, Object>)branch).get('name'));
            }
            if (!GitHubReposController.hasNextPage(response)) {
                List<String> branches = new List<String>(names);
                branches.sort();
                return branches;
            }
            page++;
        }
        throw GitHubReposController.handledError('This repository has too many branches to load in one request.');
    }

    @AuraEnabled
    public static List<GitHubActivityItem> getCommits(String repository, String branch) {
        String path = repositoryPath(repository) + '/commits?per_page=' + PAGE_SIZE + '&sha=' + branchQuery(branch);
        HttpResponse response = request(path);
        List<GitHubActivityItem> commits = new List<GitHubActivityItem>();
        if (response.getStatusCode() == 409) {
            return commits;
        }

        for (Object row : records(response, 'commits')) {
            Map<String, Object> entry = (Map<String, Object>)row;
            Map<String, Object> commitData = (Map<String, Object>)entry.get('commit');
            Map<String, Object> author = (Map<String, Object>)commitData.get('author');
            List<Object> parents = (List<Object>)entry.get('parents');
            GitHubActivityItem item = new GitHubActivityItem();
            item.id = (String)entry.get('sha');
            item.title = ((String)commitData.get('message')).substringBefore('\n');
            item.url = (String)entry.get('html_url');
            item.author = author == null ? null : (String)author.get('name');
            item.activityDate = author == null ? null : (String)author.get('date');
            item.status = parents != null && parents.size() > 1 ? 'Merge commit' : 'Commit';
            commits.add(item);
        }
        return commits;
    }

    @AuraEnabled
    public static List<GitHubActivityItem> getPullRequests(String repository, String branch) {
        String path = repositoryPath(repository) + '/pulls?state=all&sort=updated&direction=desc&per_page=' +
            PAGE_SIZE + '&base=' + branchQuery(branch);
        List<GitHubActivityItem> pulls = new List<GitHubActivityItem>();

        for (Object row : records(request(path), 'pull requests')) {
            Map<String, Object> entry = (Map<String, Object>)row;
            Map<String, Object> author = (Map<String, Object>)entry.get('user');
            GitHubActivityItem item = new GitHubActivityItem();
            item.id = String.valueOf(entry.get('number'));
            item.title = '#' + item.id + ' ' + (String)entry.get('title');
            item.url = (String)entry.get('html_url');
            item.author = author == null ? null : (String)author.get('login');
            item.activityDate = (String)entry.get('updated_at');
            item.mergedAt = (String)entry.get('merged_at');
            if (item.mergedAt != null) {
                item.status = 'Merged';
            } else if ((String)entry.get('state') == 'closed') {
                item.status = 'Closed';
            } else {
                item.status = (Boolean)entry.get('draft') == true ? 'Draft' : 'Open';
            }
            pulls.add(item);
        }
        return pulls;
    }

    private static String repositoryPath(String repository) {
        if (String.isBlank(repository) || !REPOSITORY_PATTERN.matcher(repository).matches() ||
            repository.endsWith('/.') || repository.endsWith('/..')) {
            throw GitHubReposController.handledError('Select a valid GitHub repository.');
        }
        return '/repos/' + repository;
    }

    private static String branchQuery(String branch) {
        if (String.isBlank(branch) || branch.length() > 1024) {
            throw GitHubReposController.handledError('Select a valid GitHub branch.');
        }
        return EncodingUtil.urlEncode(branch, 'UTF-8');
    }

    private static HttpResponse request(String path) {
        try {
            return GitHubReposController.sendRequest(path);
        } catch (CalloutException e) {
            throw GitHubReposController.handledError('Unable to connect to GitHub. Verify the ghAPI credential and try again.');
        }
    }

    private static List<Object> records(HttpResponse response, String resource) {
        if (response.getStatusCode() != 200) {
            throw GitHubReposController.handledError(GitHubReposController.httpErrorMessage(response, resource));
        }
        try {
            return (List<Object>)JSON.deserializeUntyped(response.getBody());
        } catch (Exception e) {
            throw GitHubReposController.handledError('Unable to read the GitHub ' + resource + ' response.');
        }
    }
}
