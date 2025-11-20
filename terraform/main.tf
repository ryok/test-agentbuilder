# main.tf - Main Terraform configuration for Azure Container Apps deployment

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.0"
    }
  }
}

provider "azurerm" {
  skip_provider_registration = true

  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

# Data source for existing resource group
data "azurerm_resource_group" "existing" {
  name = var.resource_group_name
}

# Random suffix for globally unique names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

locals {
  resource_suffix = "${var.project_name}-${var.environment}-${random_string.suffix.result}"
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment
      Deployment  = "Terraform"
    }
  )
}

# Virtual Network (create new if specified)
resource "azurerm_virtual_network" "vnet" {
  count               = var.create_new_vnet ? 1 : 0
  name                = "vnet-${local.resource_suffix}"
  location            = data.azurerm_resource_group.existing.location
  resource_group_name = data.azurerm_resource_group.existing.name
  address_space       = var.vnet_address_space
  tags                = local.common_tags
}

# Data source for existing Virtual Network
data "azurerm_virtual_network" "existing" {
  count               = var.create_new_vnet ? 0 : 1
  name                = var.existing_vnet_name
  resource_group_name = data.azurerm_resource_group.existing.name
}

# Subnet for Container Apps Environment
resource "azurerm_subnet" "container_apps" {
  count                = var.create_new_vnet ? 1 : 0
  name                 = "snet-containeraps-${var.environment}"
  resource_group_name  = data.azurerm_resource_group.existing.name
  virtual_network_name = azurerm_virtual_network.vnet[0].name
  address_prefixes     = [var.container_apps_subnet_prefix]

  delegation {
    name = "containerAppsDelegation"
    service_delegation {
      name = "Microsoft.App/environments"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

# Data source for existing subnet
data "azurerm_subnet" "existing" {
  count                = var.create_new_vnet ? 0 : 1
  name                 = var.existing_subnet_name
  virtual_network_name = data.azurerm_virtual_network.existing[0].name
  resource_group_name  = data.azurerm_resource_group.existing.name
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "workspace" {
  name                = "log-${local.resource_suffix}"
  location            = data.azurerm_resource_group.existing.location
  resource_group_name = data.azurerm_resource_group.existing.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
}

# Application Insights
resource "azurerm_application_insights" "insights" {
  count               = var.enable_application_insights ? 1 : 0
  name                = "appi-${local.resource_suffix}"
  location            = data.azurerm_resource_group.existing.location
  resource_group_name = data.azurerm_resource_group.existing.name
  workspace_id        = azurerm_log_analytics_workspace.workspace.id
  application_type    = "web"
  tags                = local.common_tags
}

# Storage Account
resource "azurerm_storage_account" "storage" {
  count                    = var.enable_storage_account ? 1 : 0
  name                     = "st${replace(local.resource_suffix, "-", "")}"
  resource_group_name      = data.azurerm_resource_group.existing.name
  location                 = data.azurerm_resource_group.existing.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  blob_properties {
    versioning_enabled = true
  }

  tags = local.common_tags
}

# Container Registry
resource "azurerm_container_registry" "acr" {
  name                = "cr${replace(local.resource_suffix, "-", "")}"
  resource_group_name = data.azurerm_resource_group.existing.name
  location            = data.azurerm_resource_group.existing.location
  sku                 = var.acr_sku
  admin_enabled       = true
  tags                = local.common_tags
}

# Get current Azure client config for Key Vault access policy
data "azurerm_client_config" "current" {}

# Key Vault
resource "azurerm_key_vault" "kv" {
  name                       = "kv-${random_string.suffix.result}"
  location                   = data.azurerm_resource_group.existing.location
  resource_group_name        = data.azurerm_resource_group.existing.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  tags = local.common_tags
}

# Key Vault Access Policy for current user/service principal
resource "azurerm_key_vault_access_policy" "deployer" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
    "Purge",
    "Recover"
  ]
}

# Store OpenAI API Key in Key Vault
resource "azurerm_key_vault_secret" "openai_api_key" {
  name         = "openai-api-key"
  value        = var.openai_api_key
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [azurerm_key_vault_access_policy.deployer]
}

# User Assigned Managed Identity for Container App
resource "azurerm_user_assigned_identity" "container_app" {
  name                = "id-${local.resource_suffix}"
  location            = data.azurerm_resource_group.existing.location
  resource_group_name = data.azurerm_resource_group.existing.name
  tags                = local.common_tags
}

# Key Vault Access Policy for Managed Identity
resource "azurerm_key_vault_access_policy" "container_app" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.container_app.principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}

# Role assignment for ACR pull
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.container_app.principal_id
}

# Container Apps Environment
resource "azurerm_container_app_environment" "env" {
  name                       = "cae-${local.resource_suffix}"
  location                   = data.azurerm_resource_group.existing.location
  resource_group_name        = data.azurerm_resource_group.existing.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.workspace.id

  infrastructure_subnet_id = var.create_new_vnet ? azurerm_subnet.container_apps[0].id : data.azurerm_subnet.existing[0].id

  tags = local.common_tags
}

# Container App
resource "azurerm_container_app" "app" {
  name                         = "ca-${local.resource_suffix}"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = data.azurerm_resource_group.existing.name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.container_app.id]
  }

  registry {
    server   = azurerm_container_registry.acr.login_server
    identity = azurerm_user_assigned_identity.container_app.id
  }

  secret {
    name  = "openai-api-key"
    value = var.openai_api_key
  }

  template {
    min_replicas = var.container_app_min_replicas
    max_replicas = var.container_app_max_replicas

    container {
      name   = "email-agent-api"
      image  = var.container_image != null ? var.container_image : "${azurerm_container_registry.acr.login_server}/email-agent:latest"
      cpu    = var.container_cpu
      memory = var.container_memory

      env {
        name  = "OPENAI_API_KEY"
        secret_name = "openai-api-key"
      }

      env {
        name  = "PORT"
        value = "8000"
      }

      env {
        name  = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        value = var.enable_application_insights ? azurerm_application_insights.insights[0].connection_string : ""
      }

      liveness_probe {
        transport        = "HTTP"
        port             = 8000
        path             = "/health"
        initial_delay    = 10
        interval_seconds = 30
        timeout          = 5
      }

      readiness_probe {
        transport        = "HTTP"
        port             = 8000
        path             = "/health"
        interval_seconds = 10
        timeout          = 3
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8000
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  tags = local.common_tags

  depends_on = [
    azurerm_role_assignment.acr_pull,
    azurerm_key_vault_access_policy.container_app
  ]
}
