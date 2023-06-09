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
  default = 2
}

# resource "lxd_volume" "osd" {
#   count        = 3 * var.nb_vm
#   name         = "osd${count.index}"
#   pool         = "default"
#   type         = "custom"
#   content_type = "block"
#   config = {
#     size = "5GiB"
#   }
# }

resource "lxd_network" "baremetal" {
  name = "bmbr"

  config = {
    "ipv4.address" = "10.20.20.1/24"
    "ipv4.nat"     = "true"
    "ipv6.address" = "none"
  }
}

resource "lxd_container" "baremetal" {
  count = var.nb_vm
  name  = "bm${count.index}"
  image = "images:ubuntu/22.04/cloud"
  type  = "virtual-machine"

  limits = {
    cpu    = "4"
    memory = "14GiB"
  }

  config = {
    "user.access_interface" = "eth0"
    "user.user-data"        = templatefile("${path.root}/cloudinit.yaml", { index = count.index })
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network        = "lxdbr0"
      "ipv4.address" = "10.206.54.${40 + count.index}"
    }
  }

  device {
    name = "eth1"
    type = "nic"

    properties = {
      network = lxd_network.baremetal.name
    }
  }

  device {
    name = "root"
    type = "disk"
    properties = {
      path = "/"
      pool = "default"
      size = "30GB"
    }
  }

  # device {
  #   name = lxd_volume.osd[count.index * 3].name
  #   type = "disk"
  #   properties = {
  #     pool   = "default"
  #     source = lxd_volume.osd[count.index * 3].name
  #   }
  # }

  # device {
  #   name = lxd_volume.osd[count.index * 3 + 1].name
  #   type = "disk"
  #   properties = {
  #     pool   = "default"
  #     source = lxd_volume.osd[count.index * 3 + 1].name
  #   }
  # }

  # device {
  #   name = lxd_volume.osd[count.index * 3 + 2].name
  #   type = "disk"
  #   properties = {
  #     pool   = "default"
  #     source = lxd_volume.osd[count.index * 3 + 2].name
  #   }
  # }
}

output "baremetal_ip" {
  value = lxd_container.baremetal[*].ipv4_address
}