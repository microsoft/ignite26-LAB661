// Foundry resource and project for the LAB661 live labs (More 0 and 1): two model
// deployments, Log Analytics, Application Insights, the project's tracing connection,
// and the roles to use them without an API key. Deploys into an existing resource group.
// Self-paced: infra/setup.sh passes the signed-in user's object ID as userPrincipalId.
// Skillable: leave userPrincipalId empty; the lab profile's Assign Roles action grants learner roles.

@description('Region for every resource. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('Foundry resource name and custom subdomain. Must be globally unique.')
@minLength(2)
@maxLength(64)
param foundryName string = 'lab661-foundry-${uniqueString(resourceGroup().id)}'

param projectName string = 'lab661-project'

param miniModelVersion string = '2026-03-17'
param modelVersion string = '2026-03-05'

@description('gpt-5.4-mini capacity in thousands of tokens per minute. ASSERT runs 8 parallel calls, so it needs headroom.')
param miniCapacity int = 500

@description('gpt-5.4 capacity in thousands of tokens per minute.')
param modelCapacity int = 100

@description('Object ID of the learner to grant model and trace access. Empty skips learner roles.')
param userPrincipalId string = ''

var foundryUserRoleId = '53ca6127-db72-4b80-b1b0-d745d6d5456d'
var openAiUserRoleId = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
var logAnalyticsReaderRoleId = '73c42c96-874c-492b-b04d-ab87d138a893'
var logsName = take('log-${foundryName}', 63)
var appInsightsName = 'appi-${foundryName}'

resource foundry 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: foundryName
  location: location
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    customSubDomainName: foundryName
    allowProjectManagement: true
    disableLocalAuth: true
    publicNetworkAccess: 'Enabled'
  }
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' = {
  parent: foundry
  name: projectName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {}
}

// Deployments on one account must be created one at a time.
resource miniDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
  parent: foundry
  name: 'gpt-5.4-mini'
  sku: {
    name: 'GlobalStandard'
    capacity: miniCapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-5.4-mini'
      version: miniModelVersion
    }
  }
  dependsOn: [
    project
  ]
}

resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
  parent: foundry
  name: 'gpt-5.4'
  sku: {
    name: 'GlobalStandard'
    capacity: modelCapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-5.4'
      version: modelVersion
    }
  }
  dependsOn: [
    miniDeployment
  ]
}

resource logs 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logs.id
  }
}

resource tracingConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01' = {
  parent: project
  name: 'appinsights'
  properties: {
    category: 'AppInsights'
    target: appInsights.id
    authType: 'ApiKey'
    isSharedToAll: true
    credentials: {
      key: appInsights.properties.ConnectionString
    }
    metadata: {
      ApiType: 'Azure'
      ResourceId: appInsights.id
    }
  }
}

resource projectLogsReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(appInsights.id, project.id, logAnalyticsReaderRoleId)
  scope: appInsights
  properties: {
    principalId: project.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', logAnalyticsReaderRoleId)
  }
}

resource userFoundryUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(userPrincipalId)) {
  name: guid(foundry.id, userPrincipalId, foundryUserRoleId)
  scope: foundry
  properties: {
    principalId: userPrincipalId
    principalType: 'User'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', foundryUserRoleId)
  }
}

resource userOpenAiUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(userPrincipalId)) {
  name: guid(foundry.id, userPrincipalId, openAiUserRoleId)
  scope: foundry
  properties: {
    principalId: userPrincipalId
    principalType: 'User'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', openAiUserRoleId)
  }
}

resource userLogsReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(userPrincipalId)) {
  name: guid(appInsights.id, userPrincipalId, logAnalyticsReaderRoleId)
  scope: appInsights
  properties: {
    principalId: userPrincipalId
    principalType: 'User'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', logAnalyticsReaderRoleId)
  }
}

output foundryName string = foundry.name
output projectName string = project.name
output openAiEndpoint string = foundry.properties.endpoints['OpenAI Language Model Instance API']
output projectEndpoint string = 'https://${foundryName}.services.ai.azure.com/api/projects/${projectName}'
output appInsightsName string = appInsights.name
