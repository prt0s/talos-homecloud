locals {
  schematic             = var.image.schematic
  update_schematic      = coalesce(var.image.update_schematic, var.image.schematic)
  schematic_hash        = sha256(local.schematic)
  update_schematic_hash = sha256(local.update_schematic)

  schematic_id_resource        = talos_image_factory_schematic.this
  update_schematic_id_resource = one(coalesce(talos_image_factory_schematic.updated, [talos_image_factory_schematic.this]))

  grouped_node_versions = {
    for node_name, node_data in var.nodes :
    "${coalesce(node_data.host_node, node_name)}_${node_data.update == true ? local.update_schematic_hash : local.schematic_hash}" => node_data...
    if node_data.platform == "nocloud"
  }

  single_node_versions = {
    for group_key, nodes in local.grouped_node_versions :
    group_key => nodes[0]
  }

  node_to_download_key = {
    for node_name, node_data in var.nodes :
    node_name => "${coalesce(node_data.host_node, node_name)}_${node_data.update == true ? local.update_schematic_hash : local.schematic_hash}"
    if node_data.platform == "nocloud"
  }
}

resource "talos_image_factory_schematic" "this" {
  schematic = local.schematic
}

resource "talos_image_factory_schematic" "updated" {
  count     = var.image.update_schematic != null ? 1 : 0
  schematic = local.update_schematic
}

resource "talos_image_factory_schematic" "hw" {
  for_each  = var.hw_schematics
  schematic = each.value
}

resource "proxmox_virtual_environment_download_file" "this" {
  for_each = local.single_node_versions

  node_name    = each.value.host_node
  content_type = "iso"
  datastore_id = var.image.proxmox_datastore

  file_name = "talos-${each.value.update == true ? local.update_schematic_id_resource.id : local.schematic_id_resource.id}-${each.value.update == true ? coalesce(var.image.update_version, var.image.version) : var.image.version}-${coalesce(each.value.platform, var.image.platform)}-${var.image.arch}.img"
  url       = "${var.image.factory_url}/image/${each.value.update == true ? local.update_schematic_id_resource.id : local.schematic_id_resource.id}/${each.value.update == true ? coalesce(var.image.update_version, var.image.version) : var.image.version}/${coalesce(each.value.platform, var.image.platform)}-${var.image.arch}.raw.gz"

  decompression_algorithm = "gz"
  overwrite               = false
}
