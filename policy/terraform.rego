package terraform.guardrails

import rego.v1

default allow := false

allowed_types := {
  "azurerm_resource_group", "azurerm_service_plan", "azurerm_linux_web_app",
  "azurerm_policy_definition", "azurerm_resource_group_policy_assignment",
}

changes := object.get(input, "resource_changes", [])
managed := [r | some r in changes; object.get(r, "mode", "") == "managed"]
active := [r | some r in managed; object.get(r.change, "after", null) != null]

deny contains "Expected a Terraform plan object with resource_changes" if {
  not is_array(object.get(input, "resource_changes", null))
}

deny contains "Plan must contain managed resources" if {
  count(managed) == 0
}

deny contains sprintf("Missing required resource type: %s", [kind]) if {
  some kind in allowed_types
  not some_type(kind)
}

some_type(kind) if {
  some r in active
  r.type == kind
}

deny contains sprintf("%s: unsupported resource type", [r.address]) if {
  some r in managed
  not r.type in allowed_types
}

deny contains sprintf("%s: deleting resources requires a separate reviewed workflow", [r.address]) if {
  some r in managed
  "delete" in r.change.actions
}

deny contains sprintf("%s: required ownership tags missing", [r.address]) if {
  some r in active
  r.type in {"azurerm_resource_group", "azurerm_service_plan", "azurerm_linux_web_app"}
  not valid_tags(r.change.after)
}

valid_tags(after) if {
  after.tags.environment == "demo"
  is_string(after.tags.owner)
  trim_space(after.tags.owner) != ""
  after.tags.project == "devsecops-reference"
  after.tags.managed_by == "terraform"
}

deny contains sprintf("%s: insecure or unknown web app controls", [r.address]) if {
  some r in active
  r.type == "azurerm_linux_web_app"
  not secure_app(r.change.after)
}

secure_app(after) if {
  after.https_only == true
  after.ftp_publish_basic_authentication_enabled == false
  after.webdeploy_publish_basic_authentication_enabled == false
  after.identity[0].type == "SystemAssigned"
  config := after.site_config[0]
  config.minimum_tls_version in {"1.2", "1.3"}
  config.scm_minimum_tls_version in {"1.2", "1.3"}
  config.ftps_state == "Disabled"
  config.http2_enabled == true
  config.remote_debugging_enabled == false
  config.health_check_path == "/healthz"
  regex.match(`^[a-zA-Z0-9._/-]+(:[a-zA-Z0-9._-]+)?@sha256:[a-f0-9]{64}$`, config.application_stack[0].docker_image_name)
}

deny contains sprintf("%s: policy must exactly deny non-HTTPS sites", [r.address]) if {
  some r in active
  r.type == "azurerm_policy_definition"
  not secure_definition(r.change.after)
}

secure_definition(after) if {
  after.policy_type == "Custom"
  after.mode == "All"
  json.unmarshal(after.policy_rule) == {
    "if": {"allOf": [
      {"field": "type", "equals": "Microsoft.Web/sites"},
      {"field": "Microsoft.Web/sites/httpsOnly", "notEquals": true},
    ]},
    "then": {"effect": "deny"},
  }
}

deny contains sprintf("%s: policy enforcement must be enabled", [r.address]) if {
  some r in active
  r.type == "azurerm_resource_group_policy_assignment"
  object.get(r.change.after, "enforce", false) != true
}

allow if {
  count(deny) == 0
}
