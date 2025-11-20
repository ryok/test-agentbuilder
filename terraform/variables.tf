# variables.tf - Variable definitions for Azure deployment

variable "resource_group_name" {
  description = "Name of the existing Azure Resource Group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "email-agent"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "openai_api_key" {
  description = "OpenAI API key (will be stored in Key Vault)"
  type        = string
  sensitive   = true
}

variable "container_app_min_replicas" {
  description = "Minimum number of container replicas"
  type        = number
  default     = 1
}

variable "container_app_max_replicas" {
  description = "Maximum number of container replicas"
  type        = number
  default     = 10
}

variable "container_cpu" {
  description = "CPU cores for container (0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0)"
  type        = number
  default     = 0.5
}

variable "container_memory" {
  description = "Memory in GB for container (0.5, 1.0, 1.5, 2.0, 3.0, 3.5, 4.0)"
  type        = string
  default     = "1Gi"
}

variable "existing_vnet_name" {
  description = "Name of existing Virtual Network (optional)"
  type        = string
  default     = null
}

variable "existing_subnet_name" {
  description = "Name of existing subnet for Container Apps (optional)"
  type        = string
  default     = null
}

variable "create_new_vnet" {
  description = "Whether to create a new Virtual Network"
  type        = bool
  default     = true
}

variable "vnet_address_space" {
  description = "Address space for the Virtual Network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "container_apps_subnet_prefix" {
  description = "Address prefix for Container Apps subnet"
  type        = string
  default     = "10.0.0.0/21"
}

variable "enable_application_insights" {
  description = "Enable Application Insights for monitoring"
  type        = bool
  default     = true
}

variable "enable_storage_account" {
  description = "Enable Storage Account for persistent data"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "email-agent-workflow"
    ManagedBy   = "Terraform"
    Environment = "dev"
  }
}

variable "container_image" {
  description = "Container image to deploy (format: registry/repository:tag)"
  type        = string
  default     = null
}

variable "acr_sku" {
  description = "SKU for Azure Container Registry"
  type        = string
  default     = "Basic"
}

# Logic Apps variables
variable "enable_logic_apps" {
  description = "Enable Logic Apps Standard for email integration"
  type        = bool
  default     = false
}

variable "logic_app_sku" {
  description = "SKU for Logic Apps Standard App Service Plan"
  type        = string
  default     = "WS1"
}

variable "allowed_email_senders" {
  description = "List of allowed email sender addresses for Logic Apps workflow"
  type        = list(string)
  default     = []
}

variable "email_check_frequency" {
  description = "Frequency (in minutes) to check for new emails"
  type        = number
  default     = 3
}

variable "logic_app_enable_cors" {
  description = "Enable CORS for Logic Apps (allows Azure Portal access)"
  type        = bool
  default     = true
}
