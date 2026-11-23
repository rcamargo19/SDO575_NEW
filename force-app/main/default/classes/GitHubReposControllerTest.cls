/**
 * @description Test class for GitHubReposController.
 *              Covers happy-path callouts, HTTP error responses, and empty-repo responses
 *              using HttpCalloutMock implementations — no org data required.
 */
@IsTest
private class GitHubReposControllerTest {

    // ─────────────────────────────────────────────────────────────────────────
    // Mock HTTP callout implementations
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description Returns a 200 OK response with two sample repository records.
     */
    private class MockSuccessCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setHeader('Content-Type', 'application/json');
            res.setBody(SAMPLE_REPOS_JSON);
            return res;
        }
    }

    /**
     * @description Returns a 200 OK response with an empty repository array.
     */
    private class MockEmptyReposCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setHeader('Content-Type', 'application/json');
            res.setBody('[]');
            return res;
        }
    }

    private class MockPaginatedCallout implements HttpCalloutMock {
        private Integer page = 0;

        public HttpResponse respond(HttpRequest req) {
            page++;
            Assert.isTrue(page <= 2, 'Stop after the final page');
            Assert.areEqual('GET', req.getMethod());
            Assert.areEqual(
                'callout:ghAPI/user/repos?sort=updated&per_page=100' +
                '&affiliation=owner,collaborator,organization_member&page=' + page,
                req.getEndpoint()
            );
            Assert.areEqual('application/vnd.github+json', req.getHeader('Accept'));
            Assert.areEqual('2022-11-28', req.getHeader('X-GitHub-Api-Version'));

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            if (page == 1) {
                res.setHeader('Link', '<https://api.github.com/user/repos?page=2>; rel="next"');
                res.setBody('[{"id":1,"name":"first"}]');
            } else {
                res.setHeader('Link', '<https://api.github.com/user/repos?page=1>; rel="prev"');
                res.setBody('[{"id":1,"name":"duplicate"},{"id":2,"name":"second"}]');
            }
            return res;
        }
    }

    @IsTest
    static void shouldFetchAllPagesAndDeduplicateRepositories() {
        Test.setMock(HttpCalloutMock.class, new MockPaginatedCallout());

        Test.startTest();
        List<GitHubRepository> repos = GitHubReposController.getRepositories();
        Test.stopTest();

        Assert.areEqual(2, repos.size());
        Assert.areEqual('first', repos[0].name);
        Assert.areEqual('second', repos[1].name);
        Assert.areEqual(0, repos[1].stargazersCount);
        Assert.areEqual(0, repos[1].forksCount);
    }

    /**
     * @description Returns a 401 Unauthorized response to simulate an invalid token.
     */
    private class MockUnauthorizedCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(401);
            res.setStatus('Unauthorized');
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"message":"Bad credentials"}');
            return res;
        }
    }

    /**
     * @description Returns a 500 Internal Server Error to simulate a GitHub API outage.
     */
    private class MockServerErrorCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setStatus('Internal Server Error');
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"message":"Server Error"}');
            return res;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Sample JSON fixture
    // ─────────────────────────────────────────────────────────────────────────

    private static final String SAMPLE_REPOS_JSON =
        '[' +
        '  {' +
        '    "id": 123456,' +
        '    "name": "SDO575_NEW",' +
        '    "full_name": "rcamargo19/SDO575_NEW",' +
        '    "description": "SDO575 project",' +
        '    "html_url": "https://github.com/rcamargo19/SDO575_NEW",' +
        '    "visibility": "private",' +
        '    "private": true,' +
        '    "language": "Apex",' +
        '    "updated_at": "2026-11-23T16:35:38Z",' +
        '    "stargazers_count": 2,' +
        '    "forks_count": 1' +
        '  },' +
        '  {' +
        '    "id": 789012,' +
        '    "name": "texasD",' +
        '    "full_name": "rcamargo19/texasD",' +
        '    "description": "Texas Dreamin demos",' +
        '    "html_url": "https://github.com/rcamargo19/texasD",' +
        '    "visibility": "public",' +
        '    "private": false,' +
        '    "language": null,' +
        '    "updated_at": "2026-06-05T16:45:25Z",' +
        '    "stargazers_count": 0,' +
        '    "forks_count": 0' +
        '  }' +
        ']';

    // ─────────────────────────────────────────────────────────────────────────
    // Test methods
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void shouldReturnRepoList_WhenCalloutSucceeds() {
        // Given
        Test.setMock(HttpCalloutMock.class, new MockSuccessCallout());

        // When
        Test.startTest();
        List<GitHubRepository> repos =
            GitHubReposController.getRepositories();
        Test.stopTest();

        // Then
        Assert.areEqual(2, repos.size(),
            'Should return exactly 2 repos from the mock response');

        GitHubRepository first = repos[0];
        Assert.areEqual('SDO575_NEW', first.name,
            'First repo name should match mock fixture');
        Assert.areEqual('rcamargo19/SDO575_NEW', first.fullName,
            'Full name should be owner/repo format');
        Assert.areEqual('private', first.visibility,
            'Visibility should be "private"');
        Assert.areEqual(true, first.isPrivate,
            'isPrivate flag should be true');
        Assert.areEqual('Apex', first.language,
            'Language should be "Apex"');
        Assert.areEqual(2, first.stargazersCount,
            'Stars count should be 2');
        Assert.areEqual(1, first.forksCount,
            'Forks count should be 1');
        Assert.isTrue(
            first.htmlUrl.startsWith('https://github.com'),
            'htmlUrl should point to github.com');
    }

    @IsTest
    static void shouldHandleNullLanguage_WhenRepoHasNoLanguage() {
        // Given — second repo in fixture has language: null
        Test.setMock(HttpCalloutMock.class, new MockSuccessCallout());

        // When
        Test.startTest();
        List<GitHubRepository> repos =
            GitHubReposController.getRepositories();
        Test.stopTest();

        // Then
        GitHubRepository noLangRepo = repos[1];
        Assert.areEqual('texasD', noLangRepo.name,
            'Second repo name should be texasD');
        Assert.isNull(noLangRepo.language,
            'Language should be null when GitHub returns null');
        Assert.areEqual(0, noLangRepo.stargazersCount,
            'Stars count should default to 0');
        Assert.areEqual(0, noLangRepo.forksCount,
            'Forks count should default to 0');
        Assert.areEqual(false, noLangRepo.isPrivate,
            'isPrivate should be false for a public repo');
    }

    @IsTest
    static void shouldReturnEmptyList_WhenNoReposExist() {
        // Given
        Test.setMock(HttpCalloutMock.class, new MockEmptyReposCallout());

        // When
        Test.startTest();
        List<GitHubRepository> repos =
            GitHubReposController.getRepositories();
        Test.stopTest();

        // Then
        Assert.isNotNull(repos,
            'Result should not be null even when GitHub returns an empty array');
        Assert.areEqual(0, repos.size(),
            'Result list should be empty when GitHub returns []');
    }

    @IsTest
    static void shouldThrowAuraHandledException_WhenCalloutReturns401() {
        // Given
        Test.setMock(HttpCalloutMock.class, new MockUnauthorizedCallout());

        Test.startTest();
        try {
            GitHubReposController.getRepositories();
            Assert.fail('Expected AuraHandledException to be thrown for a 401 response');
        } catch (AuraHandledException ahe) {
            Assert.areEqual('GitHub rejected the credential. Verify the ghAPI authentication.', ahe.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void shouldThrowAuraHandledException_WhenCalloutReturns500() {
        // Given
        Test.setMock(HttpCalloutMock.class, new MockServerErrorCallout());

        Test.startTest();
        try {
            GitHubReposController.getRepositories();
            Assert.fail('Expected AuraHandledException to be thrown for a 500 response');
        } catch (AuraHandledException ahe) {
            Assert.areEqual('Unable to load GitHub repositories (HTTP 500).', ahe.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void shouldPopulateAllWrapperFields_WhenCalloutSucceeds() {
        // Given
        Test.setMock(HttpCalloutMock.class, new MockSuccessCallout());

        // When
        Test.startTest();
        List<GitHubRepository> repos =
            GitHubReposController.getRepositories();
        Test.stopTest();

        // Then — verify every @AuraEnabled field is populated on first repo
        GitHubRepository repo = repos[0];
        Assert.isNotNull(repo.id,          'id should not be null');
        Assert.isNotNull(repo.name,        'name should not be null');
        Assert.isNotNull(repo.fullName,    'fullName should not be null');
        Assert.isNotNull(repo.description, 'description should not be null');
        Assert.isNotNull(repo.htmlUrl,     'htmlUrl should not be null');
        Assert.isNotNull(repo.visibility,  'visibility should not be null');
        Assert.isNotNull(repo.updatedAt,   'updatedAt should not be null');
        Assert.isNotNull(repo.isPrivate,   'isPrivate should not be null');
    }
}
