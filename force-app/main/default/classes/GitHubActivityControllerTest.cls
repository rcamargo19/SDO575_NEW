@IsTest
private class GitHubActivityControllerTest {
    private class ActivityMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            String endpoint = request.getEndpoint();
            String prefix = 'callout:ghAPI/repos/example/demo';
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            if (endpoint == prefix + '/branches?per_page=100&page=1') {
                response.setHeader('Link', '<https://api.github.com/repos/example/demo/branches?page=2>; rel="next"');
                response.setBody('[{"name":"main"}]');
            } else if (endpoint == prefix + '/branches?per_page=100&page=2') {
                response.setBody('[{"name":"feature/demo&fix"}]');
            } else if (endpoint == prefix + '/commits?per_page=30&sha=feature%2Fdemo%26fix') {
                response.setBody('[{"sha":"abcdef","html_url":"https://github.com/example/demo/commit/abcdef",' +
                    '"commit":{"message":"Merge feature\\nDetails","author":{"name":"Developer","date":"2026-01-01T00:00:00Z"}},' +
                    '"parents":[{},{}]}]');
            } else if (endpoint == prefix + '/pulls?state=all&sort=updated&direction=desc&per_page=30&base=feature%2Fdemo%26fix') {
                response.setBody('[{"number":4,"title":"Feature","state":"closed","merged_at":"2026-01-01T00:00:00Z"},' +
                    '{"number":5,"title":"Abandoned","state":"closed","merged_at":null}]');
            } else {
                Assert.fail('Unexpected GitHub endpoint: ' + endpoint);
            }
            return response;
        }
    }

    @IsTest
    static void loadsBranchPagesAndClassifiesActivity() {
        Test.setMock(HttpCalloutMock.class, new ActivityMock());

        Test.startTest();
        List<String> branches = GitHubActivityController.getBranches('example/demo');
        List<GitHubActivityItem> commits = GitHubActivityController.getCommits('example/demo', branches[0]);
        List<GitHubActivityItem> pulls = GitHubActivityController.getPullRequests('example/demo', branches[0]);
        Test.stopTest();

        Assert.areEqual(new List<String>{'feature/demo&fix', 'main'}, branches);
        Assert.areEqual('Merge feature', commits[0].title);
        Assert.areEqual('Merge commit', commits[0].status);
        Assert.areEqual('Merged', pulls[0].status);
        Assert.areEqual('Closed', pulls[1].status);
    }

    @IsTest
    static void rejectsInvalidRepositoryBeforeSendingARequest() {
        try {
            GitHubActivityController.getBranches('example/..');
            Assert.fail('Expected repository validation to reject a path segment.');
        } catch (AuraHandledException error) {
            Assert.areEqual('Select a valid GitHub repository.', error.getMessage());
        }
        Assert.areEqual(0, Limits.getCallouts());
    }
}
