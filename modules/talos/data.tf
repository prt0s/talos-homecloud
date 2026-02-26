data "talos_client_configuration" "this" {
  cluster_name         = var.cluster.name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = [for _, v in var.nodes : v.ip]
  endpoints            = [for _, v in var.nodes : v.ip if v.role == "controlplane"]
}

data "talos_machine_configuration" "this" {
  for_each         = var.nodes
  cluster_name     = var.cluster.name
  cluster_endpoint = "https://${var.cluster.endpoint}:6443"
  talos_version    = var.cluster.talos_version
  machine_type     = each.value.role == "controlplane" ? "controlplane" : "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets

  config_patches = concat(
    [templatefile("${path.module}/machine-config/roles/${each.value.role}.yaml.tftpl", {
      hostname       = each.key
      node_name      = coalesce(each.value.host_node, each.key)
      cilium_values  = each.value.role == "controlplane" ? var.cilium.values : ""
      cilium_install = each.value.role == "controlplane" ? var.cilium.install : ""
      argocd_install = each.value.role == "controlplane" ? var.argocd.install : ""
      argocd_version = each.value.role == "controlplane" ? var.argocd.version : ""
    })],

    each.value.hw_profile != null ? [templatefile("${path.module}/machine-config/hw-profiles/${each.value.hw_profile}.yaml.tftpl", {
      hostname     = each.key
      node_name    = coalesce(each.value.host_node, each.key)
      schematic_id = talos_image_factory_schematic.hw[each.value.hw_profile].id
    })] : [],

    [for pci in coalesce(each.value.hostpci, []) : templatefile("${path.module}/machine-config/hw-features/${pci.type}.yaml.tftpl", {
      device_id = pci.id
      node_name = coalesce(each.value.host_node, each.key)
    })],

    fileexists("${path.module}/machine-config/platform/${each.value.platform}.yaml.tftpl") ?
    [templatefile("${path.module}/machine-config/platform/${each.value.platform}.yaml.tftpl", {})] : [],

    compact([
      for pci in coalesce(each.value.hostpci, []) :
      pci.pcidriverrebind != null && pci.pcidriverrebind != "" ?
      templatefile("${path.module}/machine-config/pci-driver-rebind.yaml.tftpl", {
        device_id     = pci.id
        target_driver = pci.pcidriverrebind
      }) : null
    ]),

    compact([
      for volume in coalesce(each.value.localvolume, []) :
      volume.serial != null && volume.serial != "" ?
      templatefile("${path.module}/machine-config/local-path-provisioner-patch.yaml.tftpl", {
        serial  = volume.serial
        model   = volume.model
        minSize = volume.minSize
        maxSize = volume.maxSize
      }) : null
    ])
  )
}

data "talos_cluster_health" "this" {
  count = var.cluster.check_health ? 1 : 0

  depends_on = [
    talos_machine_configuration_apply.vm,
    talos_machine_configuration_apply.metal,
    talos_machine_bootstrap.this
  ]

  skip_kubernetes_checks = false
  client_configuration   = talos_machine_secrets.this.client_configuration
  control_plane_nodes    = [for k, v in var.nodes : v.ip if v.role == "controlplane"]
  worker_nodes           = [for k, v in var.nodes : v.ip if v.role != "controlplane"]
  endpoints              = [var.cluster.endpoint]
}
