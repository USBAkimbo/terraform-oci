# Account info vars
variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "public_key_path" {}
variable "compartment_ocid" {}
variable "region" {}
variable "availability_domain" {}
variable "availability_domain_number" {}

# Compute vars
variable "vm_name" {}
variable "vm_shape" {}
variable "vm_ocpus" {}
variable "vm_ram" {}
variable "vm_os_image" {}
variable "ssh_key" {}

# Networking vars
variable "net_vcn_name" {}
variable "net_subnet_name" {}
variable "net_cidr_block" {}
variable "net_subnet" {}

# Cloudflare vars
variable "cf_api_token" {}
variable "cf_zone_id" {}
variable "cf_dns_filebrowser" {}
variable "cf_dns_jellyfin" {}

# Configure provider version
terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "4.95.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "3.24.0"
    }
  }
}

# OCI provider
provider "oci" {
  region           = var.region
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
}

# Cloudflare provider
provider "cloudflare" {
  api_token = var.cf_api_token
}

# Availability domain config
data "oci_identity_availability_domain" "ad" {
  compartment_id = var.tenancy_ocid
  ad_number      = var.availability_domain_number
}

# Create VCN
resource "oci_core_virtual_network" "vcn" {
  cidr_block     = var.net_cidr_block
  compartment_id = var.compartment_ocid
  display_name   = var.net_vcn_name
  dns_label      = var.net_vcn_name
}

# Create subnet in VCN
resource "oci_core_subnet" "vcn-subnet" {
  cidr_block        = var.net_cidr_block
  display_name      = var.net_subnet_name
  dns_label         = var.net_subnet_name
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_virtual_network.vcn.id
  route_table_id    = oci_core_route_table.routetable.id
  security_list_ids = [oci_core_security_list.firewallrules.id]
}

# Firewall rules
resource "oci_core_security_list" "firewallrules" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.vcn.id
  display_name   = "Firewall Rules"

  egress_security_rules {
    description = "Allow out"
    protocol    = "6"
    destination = "0.0.0.0/0"
  }

  ingress_security_rules {
    description = "Allow SSH in"
    protocol    = "6"
    source      = "0.0.0.0/0"

    tcp_options {
      max = "22"
      min = "22"
    }
  }

  ingress_security_rules {
    description = "Allow HTTP in"
    protocol    = "6"
    source      = "0.0.0.0/0"

    tcp_options {
      max = "80"
      min = "80"
    }
  }

  ingress_security_rules {
    description = "Allow HTTPS in"
    protocol    = "6"
    source      = "0.0.0.0/0"

    tcp_options {
      max = "443"
      min = "443"
    }
  }
}

# Create internet gateway so VM has internet access
resource "oci_core_internet_gateway" "internetgateway" {
  compartment_id = var.compartment_ocid
  display_name   = "VCNInternetGateway"
  vcn_id         = oci_core_virtual_network.vcn.id
}

resource "oci_core_route_table" "routetable" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.vcn.id
  display_name   = "RouteTable"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.internetgateway.id
  }
}

# Create VM
resource "oci_core_instance" "vm" {
  availability_domain                 = var.availability_domain
  compartment_id                      = var.compartment_ocid
  display_name                        = var.vm_name
  shape                               = var.vm_shape
  is_pv_encryption_in_transit_enabled = "true"

  shape_config {
    ocpus         = var.vm_ocpus
    memory_in_gbs = var.vm_ram
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.vcn-subnet.id
    display_name     = "primaryvnic"
    assign_public_ip = true
    hostname_label   = var.vm_name
  }

  source_details {
    source_type = "image"
    source_id   = var.vm_os_image
  }

  metadata = {
    "ssh_authorized_keys" = "${var.ssh_key}"
  }
}

# Null resource to always run Ansible
resource "null_resource" "ansible" {

  triggers = {
    always_run = "${timestamp()}"
  }

  # Call Ansible to configure the VM
  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ubuntu -i '${oci_core_instance.vm.public_ip},' -b ansible-config.yml --vault-password-file ./ansible-vault-key"
  }
}

# Create DNS A record in Cloudflare for Filebrowser
resource "cloudflare_record" "filebrowser-cloud" {
  zone_id = var.cf_zone_id
  name    = var.cf_dns_filebrowser
  value   = oci_core_instance.vm.public_ip
  type    = "A"
  ttl     = 300
}

# Create DNS A record in Cloudflare for Filebrowser
resource "cloudflare_record" "jellyfin-cloud" {
  zone_id = var.cf_zone_id
  name    = var.cf_dns_jellyfin
  value   = oci_core_instance.vm.public_ip
  type    = "A"
  ttl     = 300
}