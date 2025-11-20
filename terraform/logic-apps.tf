# logic-apps.tf - Logic Apps Standard resources for email integration

# App Service Plan for Logic Apps Standard
resource "azurerm_service_plan" "logic_app" {
  count               = var.enable_logic_apps ? 1 : 0
  name                = "asp-logicapp-${local.resource_suffix}"
  location            = data.azurerm_resource_group.existing.location
  resource_group_name = data.azurerm_resource_group.existing.name
  os_type             = "Windows"
  sku_name            = var.logic_app_sku

  tags = local.common_tags
}

# Storage Account for Logic Apps (using existing or create new)
resource "azurerm_storage_account" "logic_app" {
  count                    = var.enable_logic_apps && !var.enable_storage_account ? 1 : 0
  name                     = "stlogic${replace(random_string.suffix.result, "-", "")}"
  resource_group_name      = data.azurerm_resource_group.existing.name
  location                 = data.azurerm_resource_group.existing.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  tags = local.common_tags
}

locals {
  logic_app_storage_account_name = var.enable_logic_apps ? (
    var.enable_storage_account ? azurerm_storage_account.storage[0].name : azurerm_storage_account.logic_app[0].name
  ) : ""
  logic_app_storage_connection_string = var.enable_logic_apps ? (
    var.enable_storage_account ? azurerm_storage_account.storage[0].primary_connection_string : azurerm_storage_account.logic_app[0].primary_connection_string
  ) : ""
}

# API Connection for Outlook.com
resource "azurerm_api_connection" "outlook" {
  count               = var.enable_logic_apps ? 1 : 0
  name                = "outlook-connection-${local.resource_suffix}"
  resource_group_name = data.azurerm_resource_group.existing.name
  display_name        = "Outlook.com Connection"

  managed_api_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Web/locations/${data.azurerm_resource_group.existing.location}/managedApis/outlook"

  tags = local.common_tags

  lifecycle {
    ignore_changes = [
      parameter_values
    ]
  }
}

# Logic App Standard (App Service)
resource "azurerm_logic_app_standard" "main" {
  count                      = var.enable_logic_apps ? 1 : 0
  name                       = "logic-${local.resource_suffix}"
  location                   = data.azurerm_resource_group.existing.location
  resource_group_name        = data.azurerm_resource_group.existing.name
  app_service_plan_id        = azurerm_service_plan.logic_app[0].id
  storage_account_name       = local.logic_app_storage_account_name
  storage_account_access_key = local.logic_app_storage_connection_string
  version                    = "~4"

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"     = "node"
    "WEBSITE_NODE_DEFAULT_VERSION" = "~18"
    "WEBSITE_CONTENTOVERVNET"      = "1"

    # Workflow settings
    "WORKFLOWS_SUBSCRIPTION_ID"       = data.azurerm_client_config.current.subscription_id
    "WORKFLOWS_LOCATION_NAME"         = data.azurerm_resource_group.existing.location
    "WORKFLOWS_RESOURCE_GROUP_NAME"   = data.azurerm_resource_group.existing.name

    # Application Insights
    "APPINSIGHTS_INSTRUMENTATIONKEY" = var.enable_application_insights ? azurerm_application_insights.insights[0].instrumentation_key : ""
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = var.enable_application_insights ? azurerm_application_insights.insights[0].connection_string : ""

    # Outlook.com connection
    "OUTLOOK_CONNECTION_RUNTIME_URL" = azurerm_api_connection.outlook[0].id

    # Workflow parameters
    "ALLOWED_SENDERS"       = jsonencode(var.allowed_email_senders)
    "CONTAINER_APP_URL"     = "https://${azurerm_container_app.app.ingress[0].fqdn}"
    "EMAIL_CHECK_FREQUENCY" = var.email_check_frequency
  }

  site_config {
    always_on                        = true
    vnet_route_all_enabled           = var.create_new_vnet ? true : false
    runtime_scale_monitoring_enabled = true

    dynamic "cors" {
      for_each = var.logic_app_enable_cors ? [1] : []
      content {
        allowed_origins = ["https://portal.azure.com"]
      }
    }
  }

  tags = local.common_tags

  depends_on = [
    azurerm_api_connection.outlook,
    azurerm_container_app.app
  ]
}

# Role assignment for Logic App to access Container App (if using Managed Identity)
resource "azurerm_role_assignment" "logic_app_to_container_app" {
  count                = var.enable_logic_apps ? 1 : 0
  scope                = azurerm_container_app.app.id
  role_definition_name = "Reader"
  principal_id         = azurerm_logic_app_standard.main[0].identity[0].principal_id
}

# Access policy for Logic App to read from Key Vault (optional)
resource "azurerm_key_vault_access_policy" "logic_app" {
  count        = var.enable_logic_apps ? 1 : 0
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_logic_app_standard.main[0].identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}
