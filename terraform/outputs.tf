# outputs.tf - Output values from the deployment

output "resource_group_name" {
  description = "The name of the resource group"
  value       = data.azurerm_resource_group.existing.name
}

output "resource_group_location" {
  description = "The location of the resource group"
  value       = data.azurerm_resource_group.existing.location
}

output "container_app_url" {
  description = "The URL of the deployed Container App"
  value       = "https://${azurerm_container_app.app.ingress[0].fqdn}"
}

output "container_app_fqdn" {
  description = "The FQDN of the Container App"
  value       = azurerm_container_app.app.ingress[0].fqdn
}

output "container_registry_login_server" {
  description = "The login server URL for the Container Registry"
  value       = azurerm_container_registry.acr.login_server
}

output "container_registry_name" {
  description = "The name of the Container Registry"
  value       = azurerm_container_registry.acr.name
}

output "container_registry_admin_username" {
  description = "The admin username for the Container Registry"
  value       = azurerm_container_registry.acr.admin_username
  sensitive   = true
}

output "container_registry_admin_password" {
  description = "The admin password for the Container Registry"
  value       = azurerm_container_registry.acr.admin_password
  sensitive   = true
}

output "key_vault_name" {
  description = "The name of the Key Vault"
  value       = azurerm_key_vault.kv.name
}

output "key_vault_uri" {
  description = "The URI of the Key Vault"
  value       = azurerm_key_vault.kv.vault_uri
}

output "application_insights_instrumentation_key" {
  description = "The instrumentation key for Application Insights"
  value       = var.enable_application_insights ? azurerm_application_insights.insights[0].instrumentation_key : null
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "The connection string for Application Insights"
  value       = var.enable_application_insights ? azurerm_application_insights.insights[0].connection_string : null
  sensitive   = true
}

output "storage_account_name" {
  description = "The name of the Storage Account"
  value       = var.enable_storage_account ? azurerm_storage_account.storage[0].name : null
}

output "storage_account_primary_connection_string" {
  description = "The primary connection string for the Storage Account"
  value       = var.enable_storage_account ? azurerm_storage_account.storage[0].primary_connection_string : null
  sensitive   = true
}

output "managed_identity_client_id" {
  description = "The client ID of the User Assigned Managed Identity"
  value       = azurerm_user_assigned_identity.container_app.client_id
}

output "managed_identity_principal_id" {
  description = "The principal ID of the User Assigned Managed Identity"
  value       = azurerm_user_assigned_identity.container_app.principal_id
}

output "container_app_environment_id" {
  description = "The ID of the Container Apps Environment"
  value       = azurerm_container_app_environment.env.id
}

output "log_analytics_workspace_id" {
  description = "The ID of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.workspace.id
}

output "api_endpoint_workflow" {
  description = "The complete API endpoint for workflow execution"
  value       = "https://${azurerm_container_app.app.ingress[0].fqdn}/workflow"
}

output "api_endpoint_health" {
  description = "The complete API endpoint for health check"
  value       = "https://${azurerm_container_app.app.ingress[0].fqdn}/health"
}

output "deployment_instructions" {
  description = "Instructions for deploying the container image"
  value = <<-EOT

    Container Image Deployment Instructions:
    =========================================

    1. Build and push the Docker image to ACR:

       az acr login --name ${azurerm_container_registry.acr.name}
       docker build -t ${azurerm_container_registry.acr.login_server}/email-agent:latest .
       docker push ${azurerm_container_registry.acr.login_server}/email-agent:latest

    2. Update the Container App with the new image (optional if using latest tag):

       az containerapp update \
         --name ${azurerm_container_app.app.name} \
         --resource-group ${data.azurerm_resource_group.existing.name} \
         --image ${azurerm_container_registry.acr.login_server}/email-agent:latest

    3. Test the API:

       curl https://${azurerm_container_app.app.ingress[0].fqdn}/health

       curl -X POST https://${azurerm_container_app.app.ingress[0].fqdn}/workflow \
         -H "Content-Type: application/json" \
         -d '{"input_text": "お世話になっております。明日の会議について確認したいことがあります。"}'

  EOT
}

# Logic Apps outputs
output "logic_app_name" {
  description = "The name of the Logic App Standard"
  value       = var.enable_logic_apps ? azurerm_logic_app_standard.main[0].name : null
}

output "logic_app_id" {
  description = "The ID of the Logic App Standard"
  value       = var.enable_logic_apps ? azurerm_logic_app_standard.main[0].id : null
}

output "logic_app_default_hostname" {
  description = "The default hostname of the Logic App"
  value       = var.enable_logic_apps ? azurerm_logic_app_standard.main[0].default_hostname : null
}

output "logic_app_identity_principal_id" {
  description = "The principal ID of the Logic App's system-assigned identity"
  value       = var.enable_logic_apps ? azurerm_logic_app_standard.main[0].identity[0].principal_id : null
}

output "outlook_connection_id" {
  description = "The ID of the Outlook.com API connection"
  value       = var.enable_logic_apps ? azurerm_api_connection.outlook[0].id : null
}

output "logic_app_deployment_instructions" {
  description = "Instructions for deploying and configuring Logic Apps"
  value       = var.enable_logic_apps ? join("\n", [
    "",
    "Logic Apps Deployment Instructions:",
    "====================================",
    "",
    "1. Deploy the Logic Apps workflow code:",
    "",
    "   cd logic-apps",
    "   func azure functionapp publish ${var.enable_logic_apps ? azurerm_logic_app_standard.main[0].name : ""}",
    "",
    "2. Authenticate the Outlook.com connection in Azure Portal:",
    "",
    "   az portal show --resource ${var.enable_logic_apps ? azurerm_api_connection.outlook[0].id : ""}",
    "",
    "   - Navigate to \"API Connections\" → \"outlook\"",
    "   - Click \"Edit API connection\"",
    "   - Click \"Authorize\" and sign in with your Outlook.com account",
    "   - Save the connection",
    "",
    "3. Enable the workflow in Azure Portal:",
    "",
    "   - Open Logic App: ${var.enable_logic_apps ? azurerm_logic_app_standard.main[0].name : ""}",
    "   - Go to \"Workflows\" → \"workflow\"",
    "   - Click \"Enable\"",
    "",
    "4. Test by sending an email from an allowed sender:",
    "",
    "   Allowed senders: ${join(", ", var.allowed_email_senders)}",
    "   Send to: your-outlook-account@outlook.com",
    "   The workflow will check every ${var.email_check_frequency} minutes",
    "",
    "5. Monitor execution:",
    "",
    "   az webapp log tail \\",
    "     --name ${var.enable_logic_apps ? azurerm_logic_app_standard.main[0].name : ""} \\",
    "     --resource-group ${data.azurerm_resource_group.existing.name}",
    ""
  ]) : "Logic Apps is not enabled. Set enable_logic_apps = true to enable email integration."
}
