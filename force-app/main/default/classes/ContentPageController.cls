public class ContentPageController {
    public ContentVersion contentVersion { get; set; }

    public ContentPageController(ApexPages.StandardController controller) {
        String contentVersionId = ApexPages.currentPage().getParameters().get('id');
        System.debug('ContentVersion ID: ' + contentVersionId);
        if (contentVersionId != null) {
            contentVersion = [SELECT Id, Title, VersionData, FileExtension FROM ContentVersion WHERE Id = :contentVersionId LIMIT 1];
            System.debug('Retrieved ContentVersion: ' + contentVersion);
        }
    }

    public PageReference goBack() {
        PageReference pageRef = new PageReference('/apex/ProjectReviewPage');
        pageRef.setRedirect(true);
        return pageRef;
    }
}