mock_provider "azurerm" {
  mock_resource "azurerm_resource_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-demo"
    }
  }
  mock_resource "azurerm_service_plan" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-demo/providers/Microsoft.Web/serverFarms/mock-plan"
    }
  }
  mock_resource "azurerm_policy_definition" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/policyDefinitions/mock-https"
    }
  }
}

run "secure_reference" {
  command = plan

  assert {
    condition     = azurerm_linux_web_app.demo.https_only
    error_message = "Web application must require HTTPS."
  }
  assert {
    condition     = azurerm_linux_web_app.demo.site_config[0].minimum_tls_version == "1.2"
    error_message = "TLS baseline changed."
  }
  assert {
    condition     = azurerm_linux_web_app.demo.identity[0].type == "SystemAssigned"
    error_message = "Use managed identity, not embedded credentials."
  }
  assert {
    condition     = !azurerm_linux_web_app.demo.ftp_publish_basic_authentication_enabled && !azurerm_linux_web_app.demo.webdeploy_publish_basic_authentication_enabled
    error_message = "Basic publishing authentication must remain disabled."
  }
  assert {
    condition     = azurerm_resource_group_policy_assignment.https.enforce
    error_message = "Policy assignment must not be audit-only."
  }
  assert {
    condition     = jsondecode(azurerm_policy_definition.https.policy_rule).then.effect == "deny"
    error_message = "Azure Policy must deny insecure sites."
  }
}
