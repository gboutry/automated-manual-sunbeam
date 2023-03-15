terraform {
  required_providers {
    lxd = {
      source  = "terraform-lxd/lxd"
      version = "1.9.1"
    }
  }
}

provider "lxd" {
  generate_client_certificates = true
  accept_remote_certificate    = true
}

resource "lxd_profile" "baremetal" {
  name = "baremetal"

  config = {
    "user.user-data" = file("${path.root}/cloudinit.yaml")
  }
}

resource "lxd_container" "baremetal" {
  count    = 3
  name     = "baremetal-${count.index}"
  image    = "images:ubuntu/22.04/cloud"
  profiles = ["default", lxd_profile.baremetal.name]
  type     = "virtual-machine"
  limits = {
    cpu    = 4
    memory = "12GiB"
  }
}

output "baremetal_ip" {
  value = lxd_container.baremetal[*].ipv4_address
}
