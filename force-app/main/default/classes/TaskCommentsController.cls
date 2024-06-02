public class TaskCommentsController {
    public Task__c task { get; set; }
    public List<Task_Coments__c> comments { get; set; }
    public List<MainComment> mainComments { get; set; }
    public List<ChildComment> childComments { get; set; }
    public Id commentId { get; set; } // Transient property to hold the comment ID being edited or replied to
    public String replyText { get; set; } // Property to hold the reply text
    public String newCommentText { get; set; } // Property to hold the new main comment text

    public TaskCommentsController(ApexPages.StandardController controller) {
        this.task = (Task__c)controller.getRecord();
        this.comments = getTaskComments(this.task.Id);
        this.childComments = getChildCommentWrappers(this.task.Id); // Initialize childComments before mainComments
        this.mainComments = getMainCommentWrappers(this.task.Id);
    }

    public class MainComment {
        public Id id { get; set; }
        public String createdDate { get; set; }
        public String lastModifiedDate { get; set; }
        public Id lastModifiedBy { get; set; }
        public String comment { get; set; }
        public Boolean editable { get; set; }
        public Boolean editMode { get; set; } // To toggle edit mode
        public Boolean replyMode { get; set; } // To toggle reply mode
        public String user {get; set; }
        public List<ChildComment> childComments { get; set; }

        public MainComment(Task_Coments__c comment) {
            this.id = comment.Id;
            this.createdDate = comment.CreatedDate.format('dd/MM/yyyy HH:mm');
            this.lastModifiedDate = comment.LastModifiedDate.format('dd/MM/yyyy HH:mm');
            this.lastModifiedBy = comment.LastModifiedById;
            this.comment = comment.Comment__c;
            this.editable = false;
            this.editMode = false;
            this.replyMode = false;
            this.user = comment.CreatedBy.Name;
            this.childComments = new List<ChildComment>();
            Id currentUser = UserInfo.getUserId();
            if (currentUser == comment.LastModifiedById) {
                this.editable = true;
            }
        }
    }

    public class ChildComment {
        public Id id { get; set; }
        public Id parentComment { get; set; }
        public String createdDate { get; set; }
        public String lastModifiedDate { get; set; }
        public Id lastModifiedBy { get; set; }
        public String comment { get; set; }
        public Boolean editable { get; set; }
        public Boolean editMode { get; set; } // To toggle edit mode
        public Boolean replyMode { get; set; } // To toggle reply mode
        public String user {get; set; }

        public ChildComment(Task_Coments__c comment) {
            this.id = comment.Id;
            this.parentComment = comment.Parent_Comment__c;
            this.createdDate = comment.CreatedDate.format('dd/MM/yyyy HH:mm');
            this.lastModifiedDate = comment.LastModifiedDate.format('dd/MM/yyyy HH:mm');
            this.lastModifiedBy = comment.LastModifiedById;
            this.comment = comment.Comment__c;
            this.editable = false;
            this.editMode = false;
            this.replyMode = false;
            this.user = comment.CreatedBy.Name;
            Id currentUser = UserInfo.getUserId();
            if (currentUser == comment.LastModifiedById) {
                this.editable = true;
            }
        }
    }

    public List<Task_Coments__c> getTaskComments(String taskId) {
        return [SELECT Id, Comment__c, LastModifiedById, CreatedDate, LastModifiedDate, CreatedBy.Name
                FROM Task_Coments__c  
                WHERE Task__c = :taskId 
                AND Parent_Comment__c = null
                ORDER BY CreatedDate ASC];
    }

    public List<Task_Coments__c> getChildComments(String taskId) {
        return [SELECT Id, Comment__c, LastModifiedById, Parent_Comment__c, CreatedDate, LastModifiedDate, CreatedBy.Name
                FROM Task_Coments__c  
                WHERE Task__c = :taskId
                AND Parent_Comment__c != null
                ORDER BY CreatedDate ASC];
    }

    public List<MainComment> getMainCommentWrappers(String taskId) {
        List<Task_Coments__c> mainComments = getTaskComments(taskId);
        List<MainComment> mainCommentWrappers = new List<MainComment>();
        for (Task_Coments__c comment : mainComments) {
            mainCommentWrappers.add(new MainComment(comment));
        }
        for (MainComment mainComment : mainCommentWrappers) {
            for (ChildComment childComment : childComments) {
                if (childComment.parentComment == mainComment.id) {
                    mainComment.childComments.add(childComment);
                }
            }
        }
        return mainCommentWrappers;
    }

    public List<ChildComment> getChildCommentWrappers(String taskId) {
        List<Task_Coments__c> childComments = getChildComments(taskId);
        List<ChildComment> childCommentsWrapper = new List<ChildComment>();
        for (Task_Coments__c comment : childComments) {
            childCommentsWrapper.add(new ChildComment(comment));
        }
        return childCommentsWrapper;
    }

    public PageReference enableEditMode() {
        for (MainComment comment : mainComments) {
            if (comment.id == commentId) {
                comment.editMode = true;
                comment.replyMode = false;
            }
            for (ChildComment childComment : comment.childComments) {
                if (childComment.id == commentId) {
                    childComment.editMode = true;
                    childComment.replyMode = false;
                }
            }
        }
        return null;
    }

    public PageReference enableReplyMode() {
        for (MainComment comment : mainComments) {
            if (comment.id == commentId) {
                comment.replyMode = true;
                comment.editMode = false;
            }
            for (ChildComment childComment : comment.childComments) {
                if (childComment.id == commentId) {
                    childComment.replyMode = true;
                    childComment.editMode = false;
                }
            }
        }
        return null;
    }

    public PageReference saveComment() {
        for (MainComment comment : mainComments) {
            if (comment.editMode) {
                Task_Coments__c updatedComment = [SELECT Id, Comment__c FROM Task_Coments__c WHERE Id = :comment.id LIMIT 1];
                updatedComment.Comment__c = comment.comment;
                try {
                    update updatedComment;
                    comment.editMode = false;
                    comment.lastModifiedDate = updatedComment.LastModifiedDate.format('dd/MM/yyyy HH:mm');
                } catch (DmlException e) {
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error saving comment: ' + e.getMessage()));
                }
                break;
            }
            for (ChildComment childComment : comment.childComments) {
                if (childComment.editMode) {
                    Task_Coments__c updatedComment = [SELECT Id, Comment__c FROM Task_Coments__c WHERE Id = :childComment.id LIMIT 1];
                    updatedComment.Comment__c = childComment.comment;
                    try {
                        update updatedComment;
                        childComment.editMode = false;
                        childComment.lastModifiedDate = updatedComment.LastModifiedDate.format('dd/MM/yyyy HH:mm');
                    } catch (DmlException e) {
                        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error saving comment: ' + e.getMessage()));
                    }
                    break;
                }
            }
        }
        return null;
    }

    public PageReference cancelEdit() {
        for (MainComment comment : mainComments) {
            if (comment.editMode) {
                comment.editMode = false;
                comment.comment = [SELECT Comment__c FROM Task_Coments__c WHERE Id = :comment.id LIMIT 1].Comment__c;
            }
            for (ChildComment childComment : comment.childComments) {
                if (childComment.editMode) {
                    childComment.editMode = false;
                    childComment.comment = [SELECT Comment__c FROM Task_Coments__c WHERE Id = :childComment.id LIMIT 1].Comment__c;
                }
            }
        }
        return null;
    }

    public PageReference addReply() {
        if (commentId != null && String.isNotBlank(replyText)) {
            Task_Coments__c newReply = new Task_Coments__c();
            newReply.Comment__c = replyText;
            newReply.Task__c = task.Id;
            newReply.Parent_Comment__c = commentId;
            try {
                insert newReply;
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.CONFIRM, 'Reply added successfully.'));
                // Reload comments and replies
                this.comments = getTaskComments(this.task.Id);
                this.mainComments = getMainCommentWrappers(this.task.Id);
                this.childComments = getChildCommentWrappers(this.task.Id);
                replyText = null; // Clear the reply text
            } catch (DmlException e) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error adding reply: ' + e.getMessage()));
            }
        }
        return null;
    }

    public PageReference addNewComment() {
        if (String.isNotBlank(newCommentText)) {
            Task_Coments__c newComment = new Task_Coments__c();
            newComment.Comment__c = newCommentText;
            newComment.Task__c = task.Id;
            try {
                insert newComment;
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.CONFIRM, 'Comment added successfully.'));
                // Reload comments and replies
                this.comments = getTaskComments(this.task.Id);
                this.mainComments = getMainCommentWrappers(this.task.Id);
                this.childComments = getChildCommentWrappers(this.task.Id);
                newCommentText = null; // Clear the new comment text
            } catch (DmlException e) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error adding comment: ' + e.getMessage()));
            }
        }
        return null;
    }
}