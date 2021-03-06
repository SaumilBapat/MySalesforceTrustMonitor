public with sharing class OrgTrustController {
  private enum OrgKeyType {
    DOMAIN,
    INSTANCE,
    POD,
    MID
  }

  public static final String TRUST_API_HOST = 'https://api.status.salesforce.com/v1/';
  public static final String SEARCH_INSTANCE_SERVICE = 'search/';
  public static final String STATUS_SERVICE = '/status';
  public static final String DOMAIN_ENDPOINT = 'instanceAliases/';
  public static final String INSTANCE_ENDPOINT = 'instances/';
  public static final String CHILD_PRODUCTS_SERVICE = '?childProducts=true';

  @AuraEnabled(cacheable=true)
  public static map<String, Object> retrieveOrgTrustStatus(
    String instanceKey,
    String keyType
  ) {
    Map<String, Object> mapResults = new Map<String, Object>();

    System.debug('KeyType => ' + keyType + ' InstanceKey => ' + instanceKey);

    Http http = new HTTP();
    HttpRequest request = new HttpRequest();
    request.setMethod('GET');
    if (OrgKeyType.DOMAIN.name().equals(keyType)) {
      request.setEndpoint(
        TRUST_API_HOST +
        DOMAIN_ENDPOINT +
        instanceKey +
        STATUS_SERVICE
      );
    } else if (OrgKeyType.INSTANCE.name().equals(keyType)) {
      request.setEndpoint(
        TRUST_API_HOST +
        INSTANCE_ENDPOINT +
        instanceKey +
        STATUS_SERVICE +
        CHILD_PRODUCTS_SERVICE
      );
    }

    String results;
    HttpResponse response = http.send(request);
    if (response.getStatusCode() == 200) {
      System.debug('Response Body => ' + response.getBody());
      results = response.getBody();
    }
    if (!String.isBlank(results)) {
      mapResults = (Map<String, Object>) JSON.deserializeUntyped(results);
      System.debug('Deserialized Data => ' + mapResults);
    }
    return mapResults;
  }

  @AuraEnabled(cacheable=true)
  public static List<SFDCInstance> getInstanceList(String inputString) {
    List<SFDCInstance> instances = new List<SFDCInstance>();
    HttpRequest httpRequest = new HttpRequest();
    httpRequest.setEndpoint(
      TRUST_API_HOST +
      SEARCH_INSTANCE_SERVICE +
      inputString
    );
    httpRequest.setMethod('GET');

    Http http = new Http();
    try {
      HTTPResponse httpResponse = http.send(httpRequest);
      instances = (List<SFDCInstance>) JSON.deserialize(
        httpResponse.getBody(),
        List<SFDCInstance>.class
      );
      if (!instances.isEmpty()) {
        Integer idCtr = 0;
        for (SFDCInstance sfdcInstance : instances) {
          sfdcInstance.id = idCtr++;
        }
      }
      return instances;
    } catch (Exception e) {
      return null;
    }
  }

  @AuraEnabled(cacheable=false)
  public static List<SFDCInstance> getFavoritesList() {
    List<SFInstance__c> sfInstances = new List<SFInstance__c>();
    List<SFDCInstance> instances = new List<SFDCInstance>();
    sfInstances = [
      SELECT Id, Name, Instance_Key_Type__c, Alias__c, OwnerId
      FROM SFInstance__c
      WHERE OwnerId = :UserInfo.getUserId()
    ];
    if (!sfInstances.isEmpty()) {
      for (SFInstance__c sfInstance : sfInstances) {
        SFDCInstance instance = new SFDCInstance();
        if (sfInstance.Alias__c != null) {
          instance.instanceKey = sfInstance.Name;
          instance.alias = sfInstance.Alias__c;
          instance.aliasType = 'domain';
        } else {
          instance.key = sfInstance.Name;
        }
        instance.sfId = sfInstance.Id;
        instances.add(instance);
      }
      return instances;
    } else {
      return null;
    }
  }

  @AuraEnabled(cacheable=true)
  public static String getCurrentOrg() {
    String name;
    try {
      name = [SELECT InstanceName FROM Organization].instanceName;
    } catch (Exception e) {
      System.debug(
        'Exception occured while retrieving Organization information'
      );
      return '';
    }
    createCurrentInstance(name);  
    return name;
  }

  @future
  public static void createCurrentInstance(String name)  {
    List<SFInstance__c> sfInstances = new List<SFInstance__c>();
      if (Schema.sObjectType.SFInstance__c.isAccessible()){
        sfInstances = [SELECT Id, Name from SFInstance__c WHERE Name =: name];
        if (sfInstances.isEmpty()){
          SFInstance__c instance = new SFInstance__c();
          instance.Name = name;
          instance.Instance_Key_Type__c = 'INSTANCE';
          if (Schema.sObjectType.SFInstance__c.isCreateable()) {
            insert instance;
          }      
        }
      }
  }

  public class SFDCInstance {
    @AuraEnabled
    public Integer id;
    @AuraEnabled
    public String sfId;

    //instance field
    @AuraEnabled
    public String key;
    @AuraEnabled
    public String instanceloc;
    @AuraEnabled
    public String environment;
    @AuraEnabled
    public Boolean isActive;
    @AuraEnabled
    public String type;

    //domain fields
    @AuraEnabled
    public String alias;
    @AuraEnabled
    public String instanceKey;
    //@AuraEnabled public String type;
    @AuraEnabled
    public String aliasType;
  }
}