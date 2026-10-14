import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchSpeakers from '@salesforce/apex/SpeakerSelectorController.searchSpeakers';
import getAssignedSpeakers from '@salesforce/apex/SpeakerSelectorController.getAssignedSpeakers';
import assignSpeaker from '@salesforce/apex/SpeakerSelectorController.assignSpeaker';
import removeSpeaker from '@salesforce/apex/SpeakerSelectorController.removeSpeaker';
import updateSpeakerAssignment from '@salesforce/apex/SpeakerSelectorController.updateSpeakerAssignment';

const ROLE_OPTIONS = [
    { label: 'Keynote', value: 'Keynote' },
    { label: 'Panelist', value: 'Panelist' },
    { label: 'Workshop Lead', value: 'Workshop Lead' },
    { label: 'Guest Speaker', value: 'Guest Speaker' }
];

export default class SpeakerSelector extends LightningElement {
    @api recordId;

    searchTerm = '';
    searchResults = [];
    assignedSpeakers = [];
    isSearching = false;
    isLoading = true;
    editingSpeakerId = null;

    _searchTimeout;
    _hasSearched = false;

    roleOptions = ROLE_OPTIONS;

    // ── Computed properties ────────────────────────────────────────────

    get hasNoAssignedSpeakers() {
        return this.assignedSpeakers.length === 0;
    }

    get assignedCount() {
        return this.assignedSpeakers.length;
    }

    get showNoResults() {
        return this._hasSearched && this.searchResults.length === 0;
    }

    // ── Lifecycle ──────────────────────────────────────────────────────

    connectedCallback() {
        this.loadAssignedSpeakers();
    }

    // ── Data loading ───────────────────────────────────────────────────

    async loadAssignedSpeakers() {
        try {
            const data = await getAssignedSpeakers({ eventId: this.recordId });
            this.assignedSpeakers = data.map(s => ({
                ...s,
                isEditing: false,
                editRole: s.role,
                editSessionTitle: s.sessionTitle,
                roleBadgeClass: this.getRoleBadgeClass(s.role)
            }));
        } catch (error) {
            this.showToast('Error', this.reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async performSearch() {
        if (!this.searchTerm || this.searchTerm.trim().length === 0) {
            this.searchResults = [];
            this._hasSearched = false;
            return;
        }

        this.isSearching = true;
        try {
            const data = await searchSpeakers({
                searchTerm: this.searchTerm,
                eventId: this.recordId
            });
            this.searchResults = data.map(r => ({
                ...r,
                selectedRole: 'Guest Speaker',
                sessionTitle: '',
                isAvailable: !r.isAlreadyAssigned && !r.isUnavailable,
                cardClass: this.getResultCardClass(r)
            }));
            this._hasSearched = true;
        } catch (error) {
            this.showToast('Error', this.reduceErrors(error), 'error');
        } finally {
            this.isSearching = false;
        }
    }

    // ── Search handlers ────────────────────────────────────────────────

    handleSearchInput(event) {
        this.searchTerm = event.target.value;
        clearTimeout(this._searchTimeout);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._searchTimeout = setTimeout(() => {
            this.performSearch();
        }, 300);
    }

    // ── Search result role/session changes ─────────────────────────────

    handleResultRoleChange(event) {
        const speakerId = event.currentTarget.dataset.id;
        this.searchResults = this.searchResults.map(r =>
            r.speakerId === speakerId ? { ...r, selectedRole: event.detail.value } : r
        );
    }

    handleResultSessionTitleChange(event) {
        const speakerId = event.currentTarget.dataset.id;
        this.searchResults = this.searchResults.map(r =>
            r.speakerId === speakerId ? { ...r, sessionTitle: event.detail.value } : r
        );
    }

    // ── Add speaker ────────────────────────────────────────────────────

    async handleAddSpeaker(event) {
        const speakerId = event.currentTarget.dataset.id;
        const result = this.searchResults.find(r => r.speakerId === speakerId);
        if (!result) return;

        this.isLoading = true;
        try {
            await assignSpeaker({
                eventId: this.recordId,
                speakerId: speakerId,
                role: result.selectedRole,
                sessionTitle: result.sessionTitle
            });
            this.showToast('Success', `${result.name} added as ${result.selectedRole}`, 'success');
            await this.loadAssignedSpeakers();
            await this.performSearch();
        } catch (error) {
            this.showToast('Error', this.reduceErrors(error), 'error');
            this.isLoading = false;
        }
    }

    // ── Remove speaker ─────────────────────────────────────────────────

    async handleRemoveSpeaker(event) {
        const eventSpeakerId = event.currentTarget.dataset.id;
        const speaker = this.assignedSpeakers.find(s => s.eventSpeakerId === eventSpeakerId);

        // eslint-disable-next-line no-alert
        if (!confirm(`Remove ${speaker?.speakerName || 'this speaker'} from the event?`)) {
            return;
        }

        this.isLoading = true;
        try {
            await removeSpeaker({ eventSpeakerId });
            this.showToast('Success', 'Speaker removed successfully', 'success');
            await this.loadAssignedSpeakers();
            if (this._hasSearched) {
                await this.performSearch();
            }
        } catch (error) {
            this.showToast('Error', this.reduceErrors(error), 'error');
            this.isLoading = false;
        }
    }

    // ── Inline edit handlers ───────────────────────────────────────────

    handleEditSpeaker(event) {
        const eventSpeakerId = event.currentTarget.dataset.id;
        this.assignedSpeakers = this.assignedSpeakers.map(s => ({
            ...s,
            isEditing: s.eventSpeakerId === eventSpeakerId,
            editRole: s.eventSpeakerId === eventSpeakerId ? s.role : s.editRole,
            editSessionTitle: s.eventSpeakerId === eventSpeakerId ? s.sessionTitle : s.editSessionTitle
        }));
        this.editingSpeakerId = eventSpeakerId;
    }

    handleEditRoleChange(event) {
        const eventSpeakerId = event.currentTarget.dataset.id;
        this.assignedSpeakers = this.assignedSpeakers.map(s =>
            s.eventSpeakerId === eventSpeakerId ? { ...s, editRole: event.detail.value } : s
        );
    }

    handleEditSessionTitleChange(event) {
        const eventSpeakerId = event.currentTarget.dataset.id;
        this.assignedSpeakers = this.assignedSpeakers.map(s =>
            s.eventSpeakerId === eventSpeakerId ? { ...s, editSessionTitle: event.detail.value } : s
        );
    }

    async handleSaveEdit(event) {
        const eventSpeakerId = event.currentTarget.dataset.id;
        const speaker = this.assignedSpeakers.find(s => s.eventSpeakerId === eventSpeakerId);
        if (!speaker) return;

        this.isLoading = true;
        try {
            await updateSpeakerAssignment({
                eventSpeakerId,
                role: speaker.editRole,
                sessionTitle: speaker.editSessionTitle,
                displayOrder: speaker.displayOrder
            });
            this.showToast('Success', 'Speaker assignment updated', 'success');
            this.editingSpeakerId = null;
            await this.loadAssignedSpeakers();
        } catch (error) {
            this.showToast('Error', this.reduceErrors(error), 'error');
            this.isLoading = false;
        }
    }

    handleCancelEdit() {
        this.editingSpeakerId = null;
        this.assignedSpeakers = this.assignedSpeakers.map(s => ({
            ...s,
            isEditing: false,
            editRole: s.role,
            editSessionTitle: s.sessionTitle
        }));
    }

    // ── Helpers ────────────────────────────────────────────────────────

    getRoleBadgeClass(role) {
        const baseClass = 'slds-badge slds-m-top_xx-small';
        switch (role) {
            case 'Keynote':
                return baseClass + ' badge-keynote';
            case 'Panelist':
                return baseClass + ' badge-panelist';
            case 'Workshop Lead':
                return baseClass + ' badge-workshop';
            default:
                return baseClass + ' badge-guest';
        }
    }

    getResultCardClass(result) {
        let cls = 'slds-box slds-m-bottom_x-small';
        if (result.isAlreadyAssigned || result.isUnavailable) {
            cls += ' card-disabled';
        } else {
            cls += ' card-actionable';
        }
        return cls;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceErrors(error) {
        if (typeof error === 'string') return error;
        if (error?.body?.message) return error.body.message;
        if (error?.message) return error.message;
        if (Array.isArray(error?.body)) {
            return error.body.map(e => e.message).join(', ');
        }
        return 'An unexpected error occurred';
    }
}
