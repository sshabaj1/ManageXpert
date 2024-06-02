public with sharing class PayPalController {
    public Client__c client { get; set; }
    
    public PayPalController(ApexPages.StandardController controller) {
        this.client = (Client__c)controller.getRecord();
    }

    @RemoteAction
    public static void saveTransactionDetails(Id clientId, String transactionId, Decimal amount) {
        Payment__c payment = new Payment__c();
        payment.Client__c = clientId;
        payment.Transaction_Id__c = transactionId;
        payment.Amount__c = amount;
        // payment.Status__c = 'Authorized'; // Custom field to track the status
        insert payment;
    }
}