import { LightningElement } from 'lwc';
import getRepositories from '@salesforce/apex/GitHubReposController.getRepositories';

/** Datatable column definitions — defined once outside the class to avoid re-creation on rerenders. */
const COLUMNS = [
    {
        label: 'Name',
        fieldName: 'htmlUrl',
        type: 'url',
        typeAttributes: {
            label: { fieldName: 'name' },
            target: '_blank',
            tooltip: { fieldName: 'fullName' }
        },
        sortable: true,
        initialWidth: 180
    },
    {
        label: 'Description',
        fieldName: 'description',
        type: 'text',
        wrapText: true,
        initialWidth: 280
    },
    {
        label: 'Visibility',
        fieldName: 'visibility',
        type: 'text',
        sortable: true,
        initialWidth: 100
    },
    {
        label: 'Language',
        fieldName: 'language',
        type: 'text',
        sortable: true,
        initialWidth: 110
    },
    {
        label: '⭐ Stars',
        fieldName: 'stargazersCount',
        type: 'number',
        cellAttributes: { alignment: 'left' },
        sortable: true,
        initialWidth: 90
    },
    {
        label: 'Forks',
        fieldName: 'forksCount',
        type: 'number',
        cellAttributes: { alignment: 'left' },
        sortable: true,
        initialWidth: 80
    },
    {
        label: 'Last Updated',
        fieldName: 'updatedAt',
        type: 'date',
        typeAttributes: {
            year: 'numeric',
            month: 'short',
            day: '2-digit'
        },
        sortable: true,
        initialWidth: 130
    }
];

export default class GithubReposList extends LightningElement {
    /** All repos returned from the Apex callout (source of truth for sorting). */
    _allRepos = [];

    /** Currently displayed (possibly sorted) repo list. */
    repos = [];

    /** True while a repository request is in flight. */
    isLoading = false;

    /** Callout error, if any. */
    error;

    /** Column the datatable is currently sorted by. */
    sortedBy;

    /** Current sort direction ('asc' | 'desc'). */
    sortedDirection = 'asc';

    // ─── Lifecycle ───────────────────────────────────────────────────────────

    connectedCallback() {
        this.loadRepositories();
    }

    // ─── Getters ─────────────────────────────────────────────────────────────

    get columns() {
        return COLUMNS;
    }

    get hasError() {
        return !!this.error;
    }

    get showLoadingSpinner() {
        return this.isLoading && this.repos.length === 0;
    }

    get showTable() {
        return this.repos.length > 0;
    }

    get showEmptyState() {
        return !this.isLoading && !this.error && this.repos.length === 0;
    }

    get errorMessage() {
        if (!this.error) {
            return '';
        }
        // AuraHandledException surfaces message on body.message
        const message = this.error?.body?.message ?? this.error?.message ?? 'An unexpected error occurred while loading repositories.';
        return this.showTable ? `${message} Showing previously loaded repositories.` : message;
    }

    get repoCountLabel() {
        const count = this.repos.length;
        return count === 1 ? '1 repository' : `${count} repositories`;
    }

    // ─── Event handlers ──────────────────────────────────────────────────────

    handleRefresh() {
        this.loadRepositories();
    }

    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.sortedBy = fieldName;
        this.sortedDirection = sortDirection;
        this.repos = this.sortData(fieldName, sortDirection);
    }

    // ─── Private helpers ─────────────────────────────────────────────────────

    async loadRepositories() {
        if (this.isLoading) {
            return;
        }

        this.isLoading = true;
        this.error = undefined;

        try {
            const result = await getRepositories();
            this._allRepos = result ?? [];
            // Re-apply current sort if one is active
            this.repos = this.sortedBy
                ? this.sortData(this.sortedBy, this.sortedDirection)
                : [...this._allRepos];
        } catch (err) {
            this.error = err;
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * Returns a sorted copy of _allRepos without mutating the source array.
     * @param {string} fieldName  - The column fieldName to sort by
     * @param {string} direction  - 'asc' or 'desc'
     * @returns {Array} Sorted repo array
     */
    sortData(fieldName, direction) {
        const sortField = fieldName === 'htmlUrl' ? 'name' : fieldName;
        const directionMultiplier = direction === 'desc' ? -1 : 1;
        return [...this._allRepos].sort((a, b) => {
            const valA = a[sortField] ?? '';
            const valB = b[sortField] ?? '';

            if (typeof valA === 'number' && typeof valB === 'number') {
                return (valA - valB) * directionMultiplier;
            }

            const strA = String(valA).toLowerCase();
            const strB = String(valB).toLowerCase();

            if (strA < strB) return -directionMultiplier;
            if (strA > strB) return directionMultiplier;
            return 0;
        });
    }
}
