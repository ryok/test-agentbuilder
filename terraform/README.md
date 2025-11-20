# Azure Container Apps Deployment with Terraform

This Terraform configuration deploys the email agent workflow as a REST API on Azure Container Apps with complete infrastructure including networking, security, monitoring, and storage.

## Architecture Overview

The deployment creates the following Azure resources:

- **Azure Container Apps**: Hosts the FastAPI-based REST API
- **Azure Container Registry (ACR)**: Stores Docker images
- **Azure Key Vault**: Securely stores the OpenAI API key
- **Virtual Network**: Network isolation for Container Apps
- **Application Insights**: Application monitoring and distributed tracing
- **Log Analytics Workspace**: Centralized logging
- **Storage Account**: Persistent data storage
- **Managed Identity**: Secure access to Azure resources
- **Logic Apps Standard** (optional): Email integration for automated workflow triggering

## Prerequisites

1. **Azure CLI** installed and authenticated:
   ```bash
   az login
   az account set --subscription "your-subscription-id"
   ```

2. **Terraform** installed (version >= 1.5.0):
   ```bash
   terraform version
   ```

3. **Docker** installed for building container images:
   ```bash
   docker --version
   ```

4. **Existing Azure Resource Group**: You must have an existing resource group

5. **OpenAI API Key**: Required for the workflow to function

## Quick Start

### 1. Configure Variables

Copy the example variables file and customize it:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
resource_group_name = "your-existing-resource-group"
location            = "eastus"
openai_api_key      = "sk-proj-xxxx"  # Your OpenAI API key
project_name        = "email-agent"
environment         = "dev"
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Review the Deployment Plan

```bash
terraform plan
```

Review the resources that will be created.

### 4. Apply the Configuration

```bash
terraform apply
```

Type `yes` when prompted to confirm the deployment.

The deployment typically takes 5-10 minutes.

### 5. Build and Push Docker Image

After Terraform completes, it will output the ACR login server. Build and push your Docker image:

```bash
# Get ACR credentials from Terraform output
ACR_NAME=$(terraform output -raw container_registry_name)
ACR_SERVER=$(terraform output -raw container_registry_login_server)

# Login to ACR
az acr login --name $ACR_NAME

# Build Docker image (from project root directory)
cd ..
docker build -t $ACR_SERVER/email-agent:latest .

# Push to ACR
docker push $ACR_SERVER/email-agent:latest
```

### 6. Update Container App (if needed)

The Container App will automatically use the latest image. If you need to force an update:

```bash
az containerapp update \
  --name $(terraform output -raw container_app_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  --image $ACR_SERVER/email-agent:latest
```

### 7. Test the API

```bash
# Get the API URL
API_URL=$(terraform output -raw container_app_url)

# Health check
curl $API_URL/health

# Test workflow endpoint
curl -X POST $API_URL/workflow \
  -H "Content-Type: application/json" \
  -d '{
    "input_text": "お世話になっております。明日の会議について確認したいことがあります。"
  }'
```

## Configuration Options

### Network Configuration

**Option 1: Create New Virtual Network (default)**
```hcl
create_new_vnet              = true
vnet_address_space           = ["10.0.0.0/16"]
container_apps_subnet_prefix = "10.0.0.0/21"
```

**Option 2: Use Existing Virtual Network**
```hcl
create_new_vnet      = false
existing_vnet_name   = "your-vnet-name"
existing_subnet_name = "your-subnet-name"
```

### Container Scaling

Configure auto-scaling based on your needs:

```hcl
container_app_min_replicas = 1
container_app_max_replicas = 10
```

### Resource Allocation

Adjust CPU and memory for containers:

```hcl
container_cpu    = 0.5    # 0.25 to 2.0 cores
container_memory = "1Gi"  # 0.5Gi to 4Gi
```

### Optional Services

Enable or disable additional services:

```hcl
enable_application_insights = true   # Application monitoring
enable_storage_account      = true   # Persistent storage
```

## Outputs

After successful deployment, Terraform outputs important information:

```bash
# View all outputs
terraform output

# View specific outputs
terraform output container_app_url
terraform output container_registry_login_server
terraform output key_vault_name
```

Key outputs include:
- `container_app_url`: The public URL of your API
- `container_registry_login_server`: ACR login server
- `key_vault_name`: Name of the Key Vault storing secrets
- `api_endpoint_workflow`: Direct URL for workflow execution
- `deployment_instructions`: Step-by-step deployment guide

## Monitoring and Observability

### Application Insights

View application metrics, traces, and logs in Azure Portal:

```bash
# Get Application Insights name
terraform output application_insights_name

# Open in portal
az portal show --resource $(terraform output -raw application_insights_name)
```

### Container App Logs

Stream logs from the Container App:

```bash
az containerapp logs show \
  --name $(terraform output -raw container_app_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  --follow
```

### Log Analytics

Query logs using Azure Log Analytics:

```bash
# Get workspace ID
terraform output log_analytics_workspace_id
```

## Security Best Practices

1. **API Key Management**: The OpenAI API key is stored in Azure Key Vault and accessed via Managed Identity
2. **Network Isolation**: Container Apps run in a dedicated subnet with network isolation
3. **HTTPS Only**: All traffic is encrypted with TLS
4. **Managed Identity**: No credentials stored in code or environment variables (except initial deployment)
5. **Minimal Permissions**: Container App has only the permissions it needs (AcrPull, Key Vault read)

## Updating the Deployment

### Update Application Code

1. Make changes to `sample.py` or `app.py`
2. Rebuild and push the Docker image:
   ```bash
   docker build -t $ACR_SERVER/email-agent:latest .
   docker push $ACR_SERVER/email-agent:latest
   ```
3. The Container App will automatically pull and deploy the new image

### Update Infrastructure

1. Modify the Terraform configuration files
2. Review changes:
   ```bash
   terraform plan
   ```
3. Apply changes:
   ```bash
   terraform apply
   ```

## Troubleshooting

### Container App Not Starting

Check container logs:
```bash
az containerapp logs show \
  --name $(terraform output -raw container_app_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  --tail 100
```

### API Key Not Working

Verify Key Vault access:
```bash
# Check Key Vault secret
az keyvault secret show \
  --name openai-api-key \
  --vault-name $(terraform output -raw key_vault_name)

# Verify Managed Identity has access
az keyvault show \
  --name $(terraform output -raw key_vault_name) \
  --query "properties.accessPolicies[?objectId=='$(terraform output -raw managed_identity_principal_id)']"
```

### Image Pull Errors

Verify ACR permissions:
```bash
# Check role assignment
az role assignment list \
  --assignee $(terraform output -raw managed_identity_principal_id) \
  --scope $(terraform output -raw container_registry_id)
```

## Clean Up

To destroy all resources created by Terraform:

```bash
terraform destroy
```

⚠️ **Warning**: This will delete all resources including data in the Storage Account. Ensure you have backups if needed.

## Cost Estimation

Approximate monthly costs (East US region):

- Container Apps Environment: ~$50/month
- Container App (1 replica, 0.5 CPU, 1GB): ~$30/month
- Container Registry (Basic): ~$5/month
- Key Vault: ~$1/month
- Application Insights: Variable based on data ingestion
- Storage Account: Variable based on usage
- Log Analytics: Variable based on data ingestion
- Logic Apps Standard (WS1, if enabled): ~$200/month
- Outlook.com API Connection: Free tier available

**Estimated Total**:
- Without Logic Apps: ~$100-200/month for development workloads
- With Logic Apps: ~$300-400/month for development workloads

Use [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/) for detailed estimates.

## Logic Apps Email Integration

The infrastructure includes optional Logic Apps Standard integration for automated email workflow triggering. When enabled, incoming emails to Outlook.com automatically trigger the Container Apps API.

### Enabling Logic Apps

In `terraform.tfvars`:

```hcl
enable_logic_apps = true

allowed_email_senders = [
  "user1@example.com",
  "user2@example.com"
]

email_check_frequency = 3  # Check every 3 minutes
```

### Architecture

```
Outlook.com Inbox → Logic Apps Trigger → Container Apps API → Generated Reply → Send Email
```

**Workflow Steps**:
1. Logic Apps checks for new emails every N minutes
2. Filters emails from allowed senders only
3. Calls Container Apps REST API with email content
4. Receives AI-generated reply
5. Automatically sends reply email to original sender
6. Marks original email as read

### Deployment Process

1. Deploy infrastructure with Logic Apps enabled:
   ```bash
   terraform apply
   ```

2. Deploy Logic Apps workflow code:
   ```bash
   # Install Azure Functions Core Tools if not already installed
   npm install -g azure-functions-core-tools@4

   # Navigate to logic-apps directory
   cd ../logic-apps

   # Deploy workflow to Logic App
   func azure functionapp publish $(cd ../terraform && terraform output -raw logic_app_name)
   ```

3. Authenticate Outlook.com connection in Azure Portal:
   ```bash
   # Open Logic App in portal
   az logic workflow show \
     --name $(cd terraform && terraform output -raw logic_app_name) \
     --resource-group $(cd terraform && terraform output -raw resource_group_name) \
     --query "id" -o tsv | xargs az portal show --resource
   ```

   - Navigate to "API Connections" → "outlook"
   - Click "Edit API connection"
   - Click "Authorize" and sign in with your Outlook.com account
   - Save the connection

4. Enable the workflow:
   - In Azure Portal, open the Logic App
   - Go to "Workflows" → "workflow"
   - Click "Enable"

### Testing Email Integration

Send a test email from an allowed sender address:

```
To: your-outlook-account@outlook.com
Subject: Test email workflow
Body: お世話になっております。明日の会議について確認したいことがあります。
```

Within 3 minutes (or your configured check frequency), you should receive an automated reply with the AI-generated response.

### Monitoring Logic Apps

View Logic Apps execution history:

```bash
# View runs
az logicapp show \
  --name $(terraform output -raw logic_app_name) \
  --resource-group $(terraform output -raw resource_group_name)

# Stream logs
az webapp log tail \
  --name $(terraform output -raw logic_app_name) \
  --resource-group $(terraform output -raw resource_group_name)
```

### Troubleshooting Logic Apps

**Workflow Not Triggering**:
- Verify Outlook.com connection is authenticated
- Check allowed_email_senders list
- Verify workflow is enabled in Azure Portal

**API Call Failures**:
- Check Container Apps is running and healthy
- Verify CONTAINER_APP_URL environment variable is correct
- Review Logic Apps run history for error details

**Email Not Sending**:
- Verify Outlook.com connection has send permissions
- Check Logic Apps execution logs
- Ensure API response contains valid output_text

### Security Considerations

- Only emails from `allowed_email_senders` are processed
- Unauthorized senders are logged but not responded to
- All communication uses HTTPS/TLS encryption
- Logic Apps uses System-Assigned Managed Identity
- No credentials stored in code or configuration

### Customizing the Workflow

Edit `logic-apps/workflow.json` to customize:
- Email filtering logic
- Response formatting
- Error handling behavior
- Additional actions (e.g., save to database, notify admins)

After making changes, redeploy using:
```bash
cd logic-apps
func azure functionapp publish $(cd ../terraform && terraform output -raw logic_app_name)
```

## Support

For issues related to:
- **Terraform Configuration**: Check [Terraform Azure Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- **Azure Container Apps**: Check [Azure Container Apps Documentation](https://learn.microsoft.com/azure/container-apps/)
- **Application Code**: See main [README.md](../README.md) and [CLAUDE.md](../CLAUDE.md)

## Next Steps

1. Set up CI/CD pipeline for automated deployments
2. Configure custom domain and SSL certificate
3. Implement rate limiting and authentication
4. Set up monitoring alerts and dashboards
5. Configure backup and disaster recovery
