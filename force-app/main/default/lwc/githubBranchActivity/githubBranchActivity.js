import { LightningElement } from 'lwc';
import getRepositories from '@salesforce/apex/GitHubReposController.getRepositories';
import getBranches from '@salesforce/apex/GitHubActivityController.getBranches';
import getCommits from '@salesforce/apex/GitHubActivityController.getCommits';
import getPullRequests from '@salesforce/apex/GitHubActivityController.getPullRequests';

const COLUMNS = [
    {
        label: 'Activity',
        fieldName: 'url',
        type: 'url',
        typeAttributes: { label: { fieldName: 'title' }, target: '_blank' },
        wrapText: true
    },
    { label: 'Author', fieldName: 'author' },
    { label: 'Status', fieldName: 'status' },
    {
        label: 'Date',
        fieldName: 'activityDate',
        type: 'date',
        typeAttributes: { year: 'numeric', month: 'short', day: 'numeric' }
    }
];

function errorMessage(error) {
    return error?.body?.message || error?.message || 'GitHub activity could not be loaded.';
}

export default class GithubBranchActivity extends LightningElement {
    columns = COLUMNS;
    repositoryOptions = [];
    branchOptions = [];
    repository = '';
    branch = '';
    loadingRepositories = false;
    loadingBranches = false;
    loadingActivity = false;
    selectorError = '';
    commits = [];
    pullRequests = [];
    commitError = '';
    pullRequestError = '';
    branchRequest = 0;
    activityRequest = 0;

    connectedCallback() {
        if (!this.repositoryOptions.length && !this.loadingRepositories) {
            this.loadRepositories();
        }
    }

    get repositoryDisabled() {
        return this.loadingRepositories || !this.repositoryOptions.length;
    }

    get branchDisabled() {
        return this.loadingBranches || !this.branchOptions.length;
    }

    get isLoading() {
        return this.loadingRepositories || this.loadingBranches || this.loadingActivity;
    }

    get showActivity() {
        return this.branch && !this.loadingActivity;
    }

    get tabs() {
        const merges = [
            ...this.commits.filter(item => item.status === 'Merge commit'),
            ...this.pullRequests.filter(item => item.mergedAt).map(item => ({
                ...item,
                activityDate: item.mergedAt
            }))
        ].sort((first, second) => Date.parse(second.activityDate) - Date.parse(first.activityDate));

        return [
            {
                value: 'commits',
                label: 'Commits',
                rows: this.commits,
                hasRows: this.commits.length > 0,
                showEmpty: !this.commits.length && !this.commitError,
                error: this.commitError,
                empty: 'No commits found on this branch.'
            },
            {
                value: 'pulls',
                label: 'Pull requests',
                rows: this.pullRequests,
                hasRows: this.pullRequests.length > 0,
                showEmpty: !this.pullRequests.length && !this.pullRequestError,
                error: this.pullRequestError,
                empty: 'No pull requests target this branch.'
            },
            {
                value: 'merges',
                label: 'Merges',
                rows: merges,
                hasRows: merges.length > 0,
                showEmpty: !merges.length && !this.commitError && !this.pullRequestError,
                error: [this.commitError, this.pullRequestError].filter(Boolean).join(' '),
                empty: 'No merges found in the recent activity.'
            }
        ];
    }

    async loadRepositories() {
        this.loadingRepositories = true;
        this.selectorError = '';
        try {
            const repositories = await getRepositories();
            this.repositoryOptions = repositories
                .map(repo => ({ label: repo.fullName, value: repo.fullName }))
                .sort((first, second) => first.label.localeCompare(second.label));
            if (!this.repositoryOptions.length) {
                this.selectorError = 'No repositories are available to the GitHub credential.';
            }
        } catch (error) {
            this.selectorError = errorMessage(error);
        } finally {
            this.loadingRepositories = false;
        }
    }

    handleRepositoryChange(event) {
        this.repository = event.detail.value;
        this.loadBranches();
    }

    async loadBranches() {
        const request = ++this.branchRequest;
        this.activityRequest++;
        this.branch = '';
        this.branchOptions = [];
        this.loadingActivity = false;
        this.loadingBranches = true;
        this.selectorError = '';
        try {
            const branches = await getBranches({ repository: this.repository });
            if (request !== this.branchRequest) {
                return;
            }
            this.branchOptions = branches.map(branch => ({ label: branch, value: branch }));
            if (!branches.length) {
                this.selectorError = 'This repository has no branches.';
            }
        } catch (error) {
            if (request === this.branchRequest) {
                this.selectorError = errorMessage(error);
            }
        } finally {
            if (request === this.branchRequest) {
                this.loadingBranches = false;
            }
        }
    }

    handleBranchChange(event) {
        this.branch = event.detail.value;
        this.loadActivity();
    }

    handleRefresh() {
        if (this.isLoading) {
            return;
        }
        if (this.branch) {
            this.loadActivity();
        } else if (this.repository) {
            this.loadBranches();
        } else {
            this.loadRepositories();
        }
    }

    async loadActivity() {
        const request = ++this.activityRequest;
        const selection = { repository: this.repository, branch: this.branch };
        this.loadingActivity = true;
        const [commits, pulls] = await Promise.allSettled([
            getCommits(selection),
            getPullRequests(selection)
        ]);
        if (request !== this.activityRequest) {
            return;
        }
        this.commits = commits.status === 'fulfilled' ? commits.value : [];
        this.commitError = commits.status === 'rejected' ? errorMessage(commits.reason) : '';
        this.pullRequests = pulls.status === 'fulfilled' ? pulls.value : [];
        this.pullRequestError = pulls.status === 'rejected' ? errorMessage(pulls.reason) : '';
        this.loadingActivity = false;
    }
}
