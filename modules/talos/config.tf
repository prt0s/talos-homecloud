resource "talos_machine_secrets" "this" {
  talos_version = var.cluster.talos_version
}

resource "talos_machine_configuration_apply" "vm" {
  for_each = {
    for k, v in var.nodes :
    k => v
    if v.platform == "nocloud"
  }

  node                        = each.value.ip
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this[each.key].machine_configuration

  depends_on = [
    proxmox_virtual_environment_vm.this
  ]

  lifecycle {
    replace_triggered_by = [
      proxmox_virtual_environment_vm.this[each.key]
    ]
  }
}

resource "talos_machine_configuration_apply" "metal" {
  for_each = {
    for k, v in var.nodes :
    k => v
    if v.platform == "metal"
  }

  node                        = each.value.ip
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this[each.key].machine_configuration

  endpoint = each.value.ip
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [
    talos_machine_configuration_apply.vm,
    talos_machine_configuration_apply.metal,
  ]
  node                 = [for k, v in var.nodes : v.ip if v.role == "controlplane"][0]
  endpoint             = var.cluster.endpoint
  client_configuration = talos_machine_secrets.this.client_configuration
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on = [
    talos_machine_bootstrap.this,
  ]
  node                 = [for k, v in var.nodes : v.ip if v.role == "controlplane"][0]
  endpoint             = var.cluster.endpoint
  client_configuration = talos_machine_secrets.this.client_configuration
}
