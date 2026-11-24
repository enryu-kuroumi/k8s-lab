variable "subscription_id" {
  description = "Azure subscription ID (find it with: az account show --query id -o tsv)"
  type        = string
}

variable "project" {
  description = "Short lowercase project name (letters and digits only, used in resource names)"
  type        = string
  default     = "nekouv"

  validation {
    condition     = can(regex("^[a-z0-9]{3,12}$", var.project))
    error_message = "project must be 3-12 lowercase letters or digits."
  }
}

variable "location" {
  description = "Azure region. Student accounts can restrict regions; change it if you get a policy error."
  type        = string
  default     = "westeurope"
}
