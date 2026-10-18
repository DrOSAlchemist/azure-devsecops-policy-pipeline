package terraform.guardrails_test

import rego.v1
import data.terraform.guardrails

tags := {"environment": "demo", "owner": "platform", "project": "devsecops-reference", "managed_by": "terraform"}
config := {
  "minimum_tls_version": "1.2", "scm_minimum_tls_version": "1.2",
  "ftps_state": "Disabled", "http2_enabled": true, "remote_debugging_enabled": false,
  "health_check_path": "/healthz",
  "application_stack": [{"docker_image_name": "library/node@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}],
}
app := {
  "tags": tags, "https_only": true,
  "ftp_publish_basic_authentication_enabled": false,
  "webdeploy_publish_basic_authentication_enabled": false,
  "identity": [{"type": "SystemAssigned"}], "site_config": [config],
}
rule := {
  "if": {"allOf": [
    {"field": "type", "equals": "Microsoft.Web/sites"},
    {"field": "Microsoft.Web/sites/httpsOnly", "notEquals": true},
  ]},
  "then": {"effect": "deny"},
}
resource(kind, after) := {
  "address": sprintf("%s.demo", [kind]), "mode": "managed", "type": kind,
  "change": {"actions": ["create"], "after": after},
}
plan_with_app(after) := {"resource_changes": [
  resource("azurerm_resource_group", {"tags": tags}),
  resource("azurerm_service_plan", {"tags": tags}),
  resource("azurerm_linux_web_app", after),
  resource("azurerm_policy_definition", {"policy_type": "Custom", "mode": "All", "policy_rule": json.marshal(rule)}),
  resource("azurerm_resource_group_policy_assignment", {"enforce": true}),
]}
good := plan_with_app(app)

test_accepts_secure_reference if { guardrails.allow with input as good }
test_rejects_missing_plan if { not guardrails.allow with input as {} }
test_rejects_empty_plan if { not guardrails.allow with input as {"resource_changes": []} }
test_rejects_malformed_plan if { not guardrails.allow with input as {"resource_changes": "invalid"} }
test_rejects_missing_resource_types if {
  not guardrails.allow with input as {"resource_changes": [resource("azurerm_linux_web_app", app)]}
}
test_rejects_insecure_and_unknown_fields if {
  every mutation in [
    {"https_only": false}, {"https_only": null},
    {"identity": []}, {"identity": [{"type": "UserAssigned"}]},
    {"ftp_publish_basic_authentication_enabled": true},
    {"webdeploy_publish_basic_authentication_enabled": true},
    {"tags": {}}, {"tags": object.union(tags, {"owner": "  "})},
  ] {
    candidate := object.union(object.remove(app, object.keys(mutation)), mutation)
    not guardrails.allow with input as plan_with_app(candidate)
  }
}
test_rejects_bad_tls_debug_ftp_health_and_mutable_images if {
  every mutation in [
    {"minimum_tls_version": "1.0"}, {"scm_minimum_tls_version": "1.0"},
    {"remote_debugging_enabled": true}, {"http2_enabled": false},
    {"ftps_state": "AllAllowed"}, {"health_check_path": ""},
    {"application_stack": [{"docker_image_name": "node:latest"}]},
    {"application_stack": []},
  ] {
    candidate := object.union(app, {"site_config": [object.union(config, mutation)]})
    not guardrails.allow with input as plan_with_app(candidate)
  }
}
test_rejects_unsupported_resource if {
  candidate := {"resource_changes": array.concat(good.resource_changes, [resource("azurerm_storage_account", {})])}
  not guardrails.allow with input as candidate
}
test_rejects_delete if {
  deleted := {"address": "azurerm_linux_web_app.old", "mode": "managed", "type": "azurerm_linux_web_app", "change": {"actions": ["delete"], "after": null}}
  not guardrails.allow with input as {"resource_changes": array.concat(good.resource_changes, [deleted])}
}
test_rejects_non_enforcing_assignment if {
  changes := [r | some r in good.resource_changes; r.type != "azurerm_resource_group_policy_assignment"]
  not guardrails.allow with input as {"resource_changes": array.concat(changes, [resource("azurerm_resource_group_policy_assignment", {"enforce": false})])}
}
test_rejects_audit_policy if {
  changes := [r | some r in good.resource_changes; r.type != "azurerm_policy_definition"]
  weakened := object.union(rule, {"then": {"effect": "audit"}})
  definition := resource("azurerm_policy_definition", {"policy_type": "Custom", "mode": "All", "policy_rule": json.marshal(weakened)})
  not guardrails.allow with input as {"resource_changes": array.concat(changes, [definition])}
}
test_rejects_unknown_required_value if {
  unknown := object.remove(app, {"https_only"})
  not guardrails.allow with input as plan_with_app(unknown)
}
