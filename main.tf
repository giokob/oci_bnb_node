
resource "oci_identity_compartment" "bnb_compartment" {
  name        = "BNBCompartment"
  description = "BNB compartment created by Terraform"
  # root compartmnet
  compartment_id = "${var.root_compartment_id}"
}

data "oci_identity_compartment" "bnb_compartment" {
  id = oci_identity_compartment.bnb_compartment.id
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = data.oci_identity_compartment.bnb_compartment.id
}

resource "oci_core_virtual_network" "bnb_vcn" {
  cidr_block   = "10.0.0.0/16"
  display_name = "VCN for BNB nodes"
  dns_label    = "bnbvcn"
  compartment_id = data.oci_identity_compartment.bnb_compartment.id
}

resource "oci_core_security_list" "BNBSecurityList" {
  compartment_id = "${data.oci_identity_compartment.bnb_compartment.id}"
  display_name   = "BNBSecurityList"
  vcn_id         = "${oci_core_virtual_network.bnb_vcn.id}"

  # Allow all external traffic
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  # Allow all trafic from internal hosts
  ingress_security_rules {
    protocol = "all"
    source   = "10.0.0.0/16"
  }

  # Allow ingress SSH
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      min = 22
      max = 22
    }
  }

  # Allow ingress BNB TCP Port
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      min = 30311
      max = 30311
    }
  }

  # Allow ingress BNB UDP Port
  ingress_security_rules {
    protocol = "17"
    source   = "0.0.0.0/0"

    udp_options {
      min = 30311
      max = 30311
    }
  }

  # Allow ingress ICMP protocol
  ingress_security_rules {
    protocol = "1"
    source   = "0.0.0.0/0"
  }
}

resource "oci_core_subnet" "bnb_subnet" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  cidr_block     = "10.0.0.0/24"
  display_name   = "BNB Subnet"
  dns_label      = "bnbsubnet"
  vcn_id         = oci_core_virtual_network.bnb_vcn.id
  compartment_id = data.oci_identity_compartment.bnb_compartment.id
  security_list_ids = ["${oci_core_security_list.BNBSecurityList.id}"]
}

resource "oci_core_internet_gateway" "bnb_ig" {
    compartment_id = data.oci_identity_compartment.bnb_compartment.id
    vcn_id         = oci_core_virtual_network.bnb_vcn.id
}

resource "oci_core_default_route_table" "example_default_route_table" {
  compartment_id = data.oci_identity_compartment.bnb_compartment.id
  manage_default_resource_id = oci_core_subnet.bnb_subnet.route_table_id

  route_rules {
    network_entity_id = oci_core_internet_gateway.bnb_ig.id
    destination = "0.0.0.0/0"
  }
}

resource "oci_core_instance" "bnb_node" {
  compartment_id     = data.oci_identity_compartment.bnb_compartment.id
  shape              = "${var.vm_shape}"
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  source_details {
    source_type             = "image"
    source_id           = "${var.vm_image}"
    boot_volume_size_in_gbs = 50 # minumum boot volume size
  }

  display_name       = "BNBNode"
  create_vnic_details {
    assign_public_ip = true
    subnet_id = oci_core_subnet.bnb_subnet.id
  }

  metadata = {
      ssh_authorized_keys = file("${var.ssh_key_path}")
      user_data = "${base64encode(file("install_bnb_node.sh"))}"
  }
}

resource "oci_core_volume" "node_data" {
  compartment_id = data.oci_identity_compartment.bnb_compartment.compartment_id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  size_in_gbs = "${var.node_data_volume_size}"
  block_volume_replicas_deletion = true
}

resource "oci_core_volume_attachment" "noda_data_attachment" {
    attachment_type = "paravirtualized"
    instance_id = oci_core_instance.bnb_node.id
    volume_id = oci_core_volume.node_data.id
}

# Outputs for compute instance public up address
output "public-ip-for-compute-instance" {
  value = oci_core_instance.bnb_node.public_ip
}
