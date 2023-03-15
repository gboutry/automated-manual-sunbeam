terraform {
  required_providers {
    juju = {
      source  = "terraform.local/juju/juju"
      version = "> 0.5.2"
    }
  }
}

data "juju_model" "control-plane" {
  name = "controller"
}

data "juju_machine" "baremetal" {
  count      = length(var.machine_ids)
  model      = data.juju_model.control-plane.name
  machine_id = var.machine_ids[count.index]
}

resource "juju_application" "microk8s" {
  name        = "microk8s"
  trust       = true
  model       = data.juju_model.control-plane.name
  units       = length(var.machine_ids)
  placement   = join(",", data.juju_machine.baremetal[*].machine_id)

  charm {
    name     = "microk8s"
    channel  = "latest/stable"
    revision = 28      # revision 28 does not support strict confinement
    series   = "jammy" # Base ?
  }

  config = {
    channel = var.microk8s_channel
    addons  = "dns:8.8.8.8,8.8.4.4 hostpath-storage metallb:10.20.21.1-10.20.21.10"
  }
}
