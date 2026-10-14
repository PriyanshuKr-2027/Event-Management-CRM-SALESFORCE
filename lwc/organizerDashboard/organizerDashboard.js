import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getMyEvents from '@salesforce/apex/OrganizerDashboardController.getMyEvents';

const STATUS_OPTIONS = [
    { label: 'All Statuses', value: 'All' },
    { label: 'Draft', value: 'Draft' },
    { label: 'Pending Approval', value: 'Pending Approval' },
    { label: 'Approved', value: 'Approved' },
    { label: 'Rejected', value: 'Rejected' },
    { label: 'Cancelled', value: 'Cancelled' }
];

const VIEW = {
    LIST: 'list',
    CREATE_EVENT: 'createEvent'
};

export default class OrganizerDashboard extends NavigationMixin(LightningElement) {
    allEvents = [];
    wiredEventsResult;

    searchTerm = '';
    statusFilter = 'All';
    timeFilter = 'all'; // all | upcoming | completed

    isLoading = false;
    statusOptions = STATUS_OPTIONS;

    view = VIEW.LIST;
    createEventFlowApiName = 'Event_Creation_Screen_Flow';

    // Pagination properties
    currentPage = 1;
    pageSize = 6;

    // ---- Data loading ----------------------------------------------------

    @wire(getMyEvents)
    wiredEvents(result) {
        this.wiredEventsResult = result;
        if (result.data) {
            this.allEvents = result.data.map((ev) => this.decorateEvent(ev));
        } else if (result.error) {
            this.allEvents = [];
            console.error('Error loading dashboard events:', result.error);
        }
    }

    decorateEvent(ev) {
        const now = new Date();
        const start = ev.startDateTime ? new Date(ev.startDateTime) : null;
        const end = ev.endDateTime ? new Date(ev.endDateTime) : null;
        const isEnded = end ? end < now : (start ? start < now : false);

        return {
            ...ev,
            startDateFormatted: start ? start.toLocaleString() : '',
            revenueFormatted: this.formatCurrency(ev.revenue),
            isUpcoming: start ? start >= now : false,
            isCompleted: isEnded || ev.registrationStatus === 'Closed',
            statusBadgeClass: this.getStatusBadgeClass(ev.approvalStatus)
        };
    }

    getStatusBadgeClass(approvalStatus) {
        switch (approvalStatus) {
            case 'Approved':
                return 'slds-badge slds-theme_success';
            case 'Pending Approval':
                return 'slds-badge slds-theme_warning';
            case 'Rejected':
            case 'Cancelled':
                return 'slds-badge slds-badge_inverse';
            default:
                return 'slds-badge';
        }
    }

    // ---- View state --------------------------------------------------------

    get isListView() {
        return this.view === VIEW.LIST;
    }
    get isCreateEventView() {
        return this.view === VIEW.CREATE_EVENT;
    }

    // ---- Derived / filtered data ------------------------------------------

    get filteredEvents() {
        const term = this.searchTerm.toLowerCase();

        return this.allEvents.filter((ev) => {
            const matchesSearch = !term || ev.eventName.toLowerCase().includes(term);
            const matchesStatus = this.statusFilter === 'All' || ev.approvalStatus === this.statusFilter;
            const matchesTime =
                this.timeFilter === 'all' ||
                (this.timeFilter === 'upcoming' && ev.isUpcoming) ||
                (this.timeFilter === 'completed' && ev.isCompleted);

            return matchesSearch && matchesStatus && matchesTime;
        });
    }

    get hasEvents() {
        return this.filteredEvents.length > 0;
    }

    // Pagination Getters
    get totalPages() {
        return Math.ceil(this.filteredEvents.length / this.pageSize) || 1;
    }

    get pagedEvents() {
        const start = (this.currentPage - 1) * this.pageSize;
        return this.filteredEvents.slice(start, start + this.pageSize);
    }

    get isFirstPage() {
        return this.currentPage <= 1;
    }

    get isLastPage() {
        return this.currentPage >= this.totalPages;
    }

    get isPaginationVisible() {
        return this.filteredEvents.length > this.pageSize;
    }

    get paginationStart() {
        if (!this.hasEvents) return 0;
        return (this.currentPage - 1) * this.pageSize + 1;
    }

    get paginationEnd() {
        return Math.min(this.currentPage * this.pageSize, this.filteredEvents.length);
    }

    get totalEvents() {
        return this.allEvents.length;
    }

    get totalRegistrations() {
        return this.allEvents.reduce((sum, ev) => sum + (ev.confirmedRegistrations || 0), 0);
    }

    get totalRevenueFormatted() {
        const sum = this.allEvents.reduce((total, ev) => total + (ev.revenue || 0), 0);
        return this.formatCurrency(sum);
    }

    get isAllTimeFilter() {
        return this.timeFilter === 'all';
    }
    get isUpcomingTimeFilter() {
        return this.timeFilter === 'upcoming';
    }
    get isCompletedTimeFilter() {
        return this.timeFilter === 'completed';
    }

    get allButtonVariant() {
        return this.isAllTimeFilter ? 'brand' : 'neutral';
    }
    get upcomingButtonVariant() {
        return this.isUpcomingTimeFilter ? 'brand' : 'neutral';
    }
    get completedButtonVariant() {
        return this.isCompletedTimeFilter ? 'brand' : 'neutral';
    }

    // ---- Handlers ----------------------------------------------------------

    handlePrevPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
        }
    }

    handleNextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
        }
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        this.currentPage = 1;
    }

    handleStatusFilterChange(event) {
        this.statusFilter = event.detail.value;
        this.currentPage = 1;
    }

    handleTimeFilterClick(event) {
        this.timeFilter = event.currentTarget.dataset.filter;
        this.currentPage = 1;
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredEventsResult).finally(() => {
            this.isLoading = false;
        });
    }

    handleViewEvent(event) {
        const eventId = event.currentTarget.dataset.eventId;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: eventId,
                objectApiName: 'Event__c',
                actionName: 'view'
            }
        });
    }

    handleCreateEvent() {
        this.view = VIEW.CREATE_EVENT;
    }

    handleCreateEventFlowStatusChange(event) {
        if (event.detail.status === 'FINISHED') {
            this.view = VIEW.LIST;
            this.isLoading = true;
            refreshApex(this.wiredEventsResult).finally(() => {
                this.isLoading = false;
            });
        }
    }

    handleCancelCreateEvent() {
        this.view = VIEW.LIST;
    }

    // ---- Helpers ----------------------------------------------------------

    formatCurrency(value) {
        if (value === null || value === undefined) return '₹0';
        return new Intl.NumberFormat('en-IN', {
            style: 'currency',
            currency: 'INR',
            maximumFractionDigits: 0
        }).format(value);
    }
}
