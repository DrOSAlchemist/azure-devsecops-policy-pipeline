variable "project_name" {
  description = "Globally unique name required for any future real web app. No deployment occurs in CI."
  type        = string
  default     = "devsecops-reference-demo"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{5,38}[a-z0-9]$", var.project_name))
    error_message = "Use 7-40 lowercase letters, numbers and hyphens; start with a letter and end alphanumeric."
  }
}

variable "location" {
  description = "Illustrative region; availability and cost are not checked against a subscription."
  type        = string
  default     = "eastus2"
}

variable "owner" {
  description = "Non-sensitive ownership tag."
  type        = string
  default     = "platform-engineering"
  validation {
    condition     = length(trimspace(var.owner)) > 0
    error_message = "Owner must not be blank."
  }
}

variable "container_image" {
  description = "Reference image only; replace with the separately built and scanned application image before any real deployment."
  type        = string
  default     = "library/node:24-alpine@sha256:44fce696f38ba8c987c4db89954051000bbd05ffd8d8659ba15ed4a8602e937f"
  validation {
    condition     = can(regex("^[a-zA-Z0-9._/-]+(:[a-zA-Z0-9._-]+)?@sha256:[a-f0-9]{64}$", var.container_image))
    error_message = "Image must use an explicit sha256 digest, not a mutable tag alone."
  }
}
