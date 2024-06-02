public class ProjectReviewController {
    public Client__c client { get; set; }
    public transient List<ProjectWrapper> projectWrappers { get; set; }
    public transient Id selectedContentVersionId { get; set; }
    public String commentText { get; set; }
    public Integer offset { get; set; }
    public Integer recordsPerPage { get; set; }
    public Integer totalRecords { get; set; }

    public ProjectReviewController(ApexPages.StandardController controller) {
        String clientId = ApexPages.currentPage().getParameters().get('clientId');
        if (clientId != null) {
            this.client = [SELECT Id, Name FROM Client__c WHERE Id = :clientId LIMIT 1];
        } else {
            this.client = (Client__c)controller.getRecord();
        }
        offset = 0;
        recordsPerPage = 10; // Adjust as needed
        loadData();
    }

    public void loadData() {
        totalRecords = [SELECT COUNT() FROM Project__c WHERE Client__c = :client.Id];
        List<Project__c> projects = getProjects(this.client.Id, offset, recordsPerPage);
        List<Id> projectIds = new List<Id>();
        for (Project__c project : projects) {
            projectIds.add(project.Id);
        }
        List<Id> contentDocumentIds = getContentDocumentIds(projectIds);
        List<ContentVersion> contentVersions = getContentVersions(contentDocumentIds);
        System.debug('contentVersions: '+contentVersions);

        // Create project wrappers
        projectWrappers = new List<ProjectWrapper>();
        for (Project__c project : projects) {
            List<ContentVersion> projectContentVersions = new List<ContentVersion>();
            for (ContentVersion contentVersion : contentVersions) {
                if (contentDocumentIds.contains(contentVersion.ContentDocumentId)) {
                    projectContentVersions.add(contentVersion);
                }
            }
            projectWrappers.add(new ProjectWrapper(project, projectContentVersions));
        }
        System.debug('projectWrappers: '+projectWrappers);
    }

    public List<Project__c> getProjects(String clientId, Integer offset, Integer recordsPerPage) {
        String query = 'SELECT Id, Name FROM Project__c WHERE Client__c = \'' + clientId + '\' LIMIT ' + recordsPerPage + ' OFFSET ' + offset;
        return Database.query(query);
    }

    public List<Id> getContentDocumentIds(List<Id> projectIds) {
        List<ContentDocumentLink> contentDocumentLinks = [
            SELECT ContentDocumentId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId IN :projectIds
        ];
        List<Id> contentDocumentIds = new List<Id>();
        for (ContentDocumentLink cdl : contentDocumentLinks) {
            contentDocumentIds.add(cdl.ContentDocumentId);
        }
        System.debug('contentDocumentIds: '+contentDocumentIds);
        return contentDocumentIds;
    }

    public List<ContentVersion> getContentVersions(List<Id> contentDocumentIds) {
        return [
            SELECT Id, ContentDocumentId, Title, VersionData, FileExtension,ContentBodyId
            FROM ContentVersion 
            WHERE ContentDocumentId IN :contentDocumentIds
        ];
    }

    public void nextPage() {
        if (offset + recordsPerPage < totalRecords) {
            offset += recordsPerPage;
            loadData();
        }
    }

    public void previousPage() {
        if (offset - recordsPerPage >= 0) {
            offset -= recordsPerPage;
            loadData();
        }
    }

    public void showCommentBox() {
        System.debug('Add New Comment clicked for ContentVersion ID: ' + selectedContentVersionId);
    }

    public void saveComment() {
        System.debug('Saving comment for ContentVersion ID: ' + selectedContentVersionId);
        System.debug('Comment Text: ' + commentText);

        // Create a new Attachment_Feedback__c record
        Attachment_Feedback__c newFeedback = new Attachment_Feedback__c();
        newFeedback.Client__c = client.Id;
        newFeedback.Comment__c = commentText;
        insert newFeedback;

        // Reset the comment text and selectedContentVersionId
        commentText = '';
        selectedContentVersionId = null;
        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, 'Comment saved successfully.'));
    }

    public class ProjectWrapper {
        public Project__c project { get; set; }
        public transient List<ContentVersion> contentVersions { get; set; }

        public ProjectWrapper(Project__c project, List<ContentVersion> contentVersions) {
            this.project = project;
            this.contentVersions = contentVersions;
        }
    }
}