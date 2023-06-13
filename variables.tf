variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "region" {}

variable "vm_shape" {
  type = string
}

variable "node_data_volume_size" {
  type = number
}

variable "root_compartment_id" {
  type = string
}

variable "ssh_key_path" {
  type = string
}

variable "vm_image" {
  type = string
}
