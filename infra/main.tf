locals {
  tags = {
    environment = "demo"
    owner       = var.owner
    project     = "devsecops-reference"
    managed_by  = "terraform"
  }
}

resource "azurerm_resource_group" "demo" {
  name     = "${var.project_name}-rg"
  location = var.location
  tags     = local.tags
}

resource "azurerm_service_plan" "demo" {
  name                   = "${var.project_name}-plan"
  resource_group_name    = azurerm_resource_group.demo.name
  location               = azurerm_resource_group.demo.location
  os_type                = "Linux"
  sku_name               = "P1v3"
  worker_count           = 2
  zone_balancing_enabled = true
  tags                   = local.tags
}

resource "azurerm_linux_web_app" "demo" {
  #checkov:skip=CKV_AZURE_13:Public static demo has no user accounts; see docs/security-exceptions.md.
  #checkov:skip=CKV_AZURE_17:Public static demo deliberately has no mutual-TLS client enrollment; see docs/security-exceptions.md.
  #checkov:skip=CKV_AZURE_88:Stateless demo uses its image filesystem and needs no Azure Files mount; see docs/security-exceptions.md.
  #checkov:skip=CKV_AZURE_222:Public portfolio reference endpoint has no private-network dependency; see docs/security-exceptions.md.
  name                                           = var.project_name
  resource_group_name                            = azurerm_resource_group.demo.name
  location                                       = azurerm_resource_group.demo.location
  service_plan_id                                = azurerm_service_plan.demo.id
  https_only                                     = true
  public_network_access_enabled                  = true
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false
  client_affinity_enabled                        = false
  tags                                           = local.tags

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    WEBSITES_PORT = "8080"
  }

  site_config {
    always_on                         = true
    minimum_tls_version               = "1.2"
    scm_minimum_tls_version           = "1.2"
    ftps_state                        = "Disabled"
    http2_enabled                     = true
    health_check_path                 = "/healthz"
    health_check_eviction_time_in_min = 5
    remote_debugging_enabled          = false
    application_stack {
      docker_image_name   = var.container_image
      docker_registry_url = "https://index.docker.io"
    }
  }

  logs {
    detailed_error_messages = true
    failed_request_tracing  = true
    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
  }

  depends_on = [azurerm_resource_group_policy_assignment.https]
}

resource "azurerm_policy_definition" "https" {
  name         = "${var.project_name}-https"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Deny web apps without HTTPS-only transport"
  description  = "Code-only reference. Covers top-level sites; slots and other resource types require separate policies."
  metadata = jsonencode({
    category = "App Service"
    version  = "1.0.0"
  })
  policy_rule = file("${path.module}/policies/require-https.json")
}

resource "azurerm_resource_group_policy_assignment" "https" {
  name                 = "require-https"
  resource_group_id    = azurerm_resource_group.demo.id
  policy_definition_id = azurerm_policy_definition.https.id
  enforce              = true
  display_name         = "Deny non-HTTPS web apps in the demonstration resource group"
}
