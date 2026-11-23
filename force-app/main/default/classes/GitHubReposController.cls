/**
 * @description AuraEnabled controller that fetches GitHub repository data via
 *              an authenticated HTTP callout using the ghAPI Named Credential.
 *              Intended for use by the githubReposList Lightning Web Component.
 *
 * Prerequisites:
 *   - A Named Credential named "ghAPI" must exist in Setup → Named Credentials
 *     with URL https://api.github.com and GitHub token authentication.
 *   - Grant Apex class and credential principal access to intended users. A
 *     shared principal returns the repositories visible to that GitHub identity.
 */
public with sharing class GitHubReposController {

    private static final String NAMED_CREDENTIAL    = 'ghAPI';
    private static final String REPOS_PATH          = '/user/repos';
    private static final String REPOS_QUERY_PARAMS  =
        '?sort=updated&per_page=100&affiliation=owner,collaborator,organization_member';
    private static final String ACCEPT_HEADER       = 'application/vnd.github+json';
    private static final String GH_API_VERSION      = '2022-11-28';
    private static final Integer HTTP_OK            = 200;

    private static final Pattern NEXT_LINK = Pattern.compile('>;\\s*rel="next"');

    @AuraEnabled
    public static List<GitHubRepository> getRepositories() {
        List<GitHubRepository> repos = new List<GitHubRepository>();
        Set<String> seenIds = new Set<String>();
        Integer page = 1;

        try {
            while (Limits.getCallouts() < Limits.getLimitCallouts()) {
                HttpResponse response = sendRequest(REPOS_PATH + REPOS_QUERY_PARAMS + '&page=' + page);
                if (response.getStatusCode() != HTTP_OK) {
                    throw handledError(httpErrorMessage(response, 'repositories'));
                }

                for (GitHubRepository repo : parseRepos(response.getBody())) {
                    if (seenIds.add(repo.id)) {
                        repos.add(repo);
                    }
                }

                if (!hasNextPage(response)) {
                    return repos;
                }

                // Keep requests on the configured endpoint, regardless of the Link URL.
                page++;
            }

            throw handledError('GitHub returned more repository pages than Salesforce can load in one request.');
        } catch (AuraHandledException e) {
            throw e;
        } catch (CalloutException e) {
            throw handledError('Unable to connect to GitHub. Verify the ghAPI credential and try again.');
        } catch (Exception e) {
            throw handledError('Unable to read the GitHub repository response.');
        }
    }

    public static Boolean hasNextPage(HttpResponse response) {
        String link = response.getHeader('Link');
        return !String.isBlank(link) && NEXT_LINK.matcher(link).find();
    }

    public static HttpResponse sendRequest(String path) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + NAMED_CREDENTIAL + path);
        req.setMethod('GET');
        req.setHeader('Accept', ACCEPT_HEADER);
        req.setHeader('X-GitHub-Api-Version', GH_API_VERSION);

        return new Http().send(req);
    }

    public static String httpErrorMessage(HttpResponse response, String resource) {
        Integer status = response.getStatusCode();
        if (status == 401) {
            return 'GitHub rejected the credential. Verify the ghAPI authentication.';
        }
        if (status == 429 || (status == 403 && (
            response.getHeader('X-RateLimit-Remaining') == '0' ||
            !String.isBlank(response.getHeader('Retry-After'))
        ))) {
            return 'GitHub is rate limiting requests. Try again later.';
        }
        if (status == 403) {
            return 'GitHub denied access. Verify the permissions for the ghAPI credential.';
        }
        return 'Unable to load GitHub ' + resource + ' (HTTP ' + status + ').';
    }

    public static AuraHandledException handledError(String message) {
        AuraHandledException error = new AuraHandledException(message);
        error.setMessage(message);
        return error;
    }

    /**
     * @description Deserialises the GitHub repos JSON array into a typed list.
     * @param  jsonBody Raw JSON string from the GitHub API response
     * @return          List of GitHubRepository
     */
    private static List<GitHubRepository> parseRepos(String jsonBody) {
        List<Object> rawRepos = (List<Object>) JSON.deserializeUntyped(jsonBody);
        List<GitHubRepository> repos = new List<GitHubRepository>();

        for (Object rawItem : rawRepos) {
            Map<String, Object> repoMap = (Map<String, Object>) rawItem;
            GitHubRepository wrapper = new GitHubRepository();

            wrapper.id              = String.valueOf(repoMap.get('id'));
            wrapper.name            = (String) repoMap.get('name');
            wrapper.fullName        = (String) repoMap.get('full_name');
            wrapper.description     = (String) repoMap.get('description');
            wrapper.htmlUrl         = (String) repoMap.get('html_url');
            wrapper.visibility      = (String) repoMap.get('visibility');
            wrapper.language        = (String) repoMap.get('language');
            wrapper.updatedAt       = (String) repoMap.get('updated_at');
            wrapper.stargazersCount = repoMap.get('stargazers_count') != null
                ? Integer.valueOf(repoMap.get('stargazers_count'))
                : 0;
            wrapper.forksCount      = repoMap.get('forks_count') != null
                ? Integer.valueOf(repoMap.get('forks_count'))
                : 0;
            wrapper.isPrivate       = repoMap.get('private') != null
                ? (Boolean) repoMap.get('private')
                : false;

            repos.add(wrapper);
        }

        return repos;
    }

}
