terraform {
  required_providers {
    lxd = {
      source  = "terraform-lxd/lxd"
      version = ">=1.10.0"
    }
  }
}

provider "lxd" {
  generate_client_certificates = true
  accept_remote_certificate    = true
}

variable "nb_vm" {
  default = 1
}

resource "lxd_volume" "osd" {
  count        = 4 * var.nb_vm
  name         = "osd${count.index}"
  pool         = "default"
  type         = "custom"
  content_type = "block"
  config = {
    size = "50GiB"
  }
}

resource "lxd_network" "baremetal" {
  name = "bmbr"

  config = {
    "ipv4.address" = "10.20.30.1/24"
    "ipv4.nat"     = "true"
    "ipv4.dhcp"    = "false"
    "ipv6.address" = "none"
  }
}

resource "lxd_instance" "baremetal" {
  count      = var.nb_vm
  name       = "bm${count.index}"
  image      = "ubuntu:jammy"
  type       = "virtual-machine"

  limits = {
    cpu    = "8"
    memory = count.index == 0 ? "30GiB" : "13GiB"
  }

  config = {
    "user.access_interface" = "eth0"
    "user.user-data"        = templatefile("${path.root}/cloudinit.yaml", { index = count.index })
    "user.network-config"   = file("${path.root}/network.yaml")
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      name           = "eth0"
      network        = "lxdbr0"
      "ipv4.address" = "10.206.54.${40 + count.index}"
    }
  }

  device {
    name = "eth1"
    type = "nic"

    properties = {
      name    = "eth1"
      network = lxd_network.baremetal.name
    }
  }


  device {
    name = "root"
    type = "disk"
    properties = {
      path = "/"
      pool = "default"
      size = "100GiB"
    }
  }

  device {
    name = lxd_volume.osd[count.index * 3].name
    type = "disk"
    properties = {
      pool   = "default"
      source = lxd_volume.osd[count.index * 3].name
    }
  }

  device {
    name = lxd_volume.osd[count.index * 3 + 1].name
    type = "disk"
    properties = {
      pool   = "default"
      source = lxd_volume.osd[count.index * 3 + 1].name
    }
  }

  device {
    name = lxd_volume.osd[count.index * 3 + 2].name
    type = "disk"
    properties = {
      pool   = "default"
      source = lxd_volume.osd[count.index * 3 + 2].name
    }
  }

  device {
    name = lxd_volume.osd[count.index * 3 + 3].name
    type = "disk"
    properties = {
      pool   = "default"
      source = lxd_volume.osd[count.index * 3 + 3].name
    }
  }
}

output "baremetal_ip" {
  value = lxd_instance.baremetal[*].ipv4_address
}
