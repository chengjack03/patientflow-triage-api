// PatientFlow Triage API — Azure Container Apps deployment (infrastructure as code).
// Provisions Log Analytics, a Container Apps environment, PostgreSQL Flexible Server,
// and the Container App itself. The container image is expected to already exist in the
// referenced Azure Container Registry (deploy.sh builds/pushes it via `az acr build`).

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Name prefix for resources.')
param namePrefix string = 'patientflow'

@description('Name of an existing Azure Container Registry that holds the image.')
param acrName string

@description('Image tag to deploy.')
param imageTag string = 'latest'

@description('Anthropic API key (stored as a Container App secret).')
@secure()
param anthropicApiKey string

@description('PostgreSQL administrator password.')
@secure()
param pgAdminPassword string

@description('PostgreSQL administrator login.')
param pgAdminUser string = 'pfadmin'

var logName = '${namePrefix}-logs'
var envName = '${namePrefix}-env'
var pgServerName = '${namePrefix}-pg-${uniqueString(resourceGroup().id)}'
var pgDbName = 'patientflow'
var appName = '${namePrefix}-api'

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
}

resource logs 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logName
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

resource env 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: envName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logs.properties.customerId
        sharedKey: logs.listKeys().primarySharedKey
      }
    }
  }
}

resource pg 'Microsoft.DBforPostgreSQL/flexibleServers@2023-06-01-preview' = {
  name: pgServerName
  location: location
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  properties: {
    version: '16'
    administratorLogin: pgAdminUser
    administratorLoginPassword: pgAdminPassword
    storage: { storageSizeGB: 32 }
    backup: { backupRetentionDays: 7 }
    network: { publicNetworkAccess: 'Enabled' }
    highAvailability: { mode: 'Disabled' }
  }
}

resource pgDb 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-06-01-preview' = {
  parent: pg
  name: pgDbName
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

// Allow other Azure services (incl. Container Apps) to reach the DB.
resource pgFirewall 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-06-01-preview' = {
  parent: pg
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

var databaseUrl = 'postgresql+psycopg2://${pgAdminUser}:${pgAdminPassword}@${pg.properties.fullyQualifiedDomainName}:5432/${pgDbName}?sslmode=require'

resource app 'Microsoft.App/containerApps@2024-03-01' = {
  name: appName
  location: location
  dependsOn: [ pgDb, pgFirewall ]
  properties: {
    managedEnvironmentId: env.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8000
        transport: 'auto'
      }
      registries: [
        {
          server: acr.properties.loginServer
          username: acr.listCredentials().username
          passwordSecretRef: 'acr-password'
        }
      ]
      secrets: [
        { name: 'acr-password', value: acr.listCredentials().passwords[0].value }
        { name: 'anthropic-api-key', value: anthropicApiKey }
        { name: 'database-url', value: databaseUrl }
      ]
    }
    template: {
      containers: [
        {
          name: 'api'
          image: '${acr.properties.loginServer}/patientflow-triage-api:${imageTag}'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            { name: 'ENVIRONMENT', value: 'production' }
            { name: 'LLM_STUB_MODE', value: 'false' }
            { name: 'ANTHROPIC_API_KEY', secretRef: 'anthropic-api-key' }
            { name: 'DATABASE_URL', secretRef: 'database-url' }
          ]
          probes: [
            {
              type: 'Liveness'
              httpGet: { path: '/health', port: 8000 }
              initialDelaySeconds: 10
              periodSeconds: 30
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
        rules: [
          {
            name: 'http-scale'
            http: { metadata: { concurrentRequests: '50' } }
          }
        ]
      }
    }
  }
}

@description('Public HTTPS URL of the deployed API.')
output apiUrl string = 'https://${app.properties.configuration.ingress.fqdn}'

@description('PostgreSQL fully-qualified domain name.')
output postgresFqdn string = pg.properties.fullyQualifiedDomainName
