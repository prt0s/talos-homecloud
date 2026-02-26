resource "proxmox_virtual_environment_vm" "this" {
  for_each = {
    for name, node in var.nodes : name => node
    if node.platform == "nocloud"
  }

  node_name = each.value.host_node
  started   = each.value.started

  name        = each.key
  description = each.value.role == "controlplane" ? "Talos Control Plane" : "Talos Worker"
  tags        = concat(["terraform", "talos", "k8s"], each.value.role == "controlplane" ? ["control-plane"] : ["worker"])
  on_boot     = true
  vm_id       = each.value.vm_id

  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"
  bios          = "seabios"

  agent {
    enabled = true
  }

  cpu {
    cores = each.value.cpu
    type  = each.value.cpu_type
  }

  memory {
    dedicated = each.value.ram_dedicated
  }

  network_device {
    bridge      = each.value.bridge
    mac_address = each.value.mac_address
  }

  disk {
    datastore_id = each.value.datastore_id
    interface    = "scsi0"
    iothread     = true
    cache        = "writethrough"
    discard      = "on"
    ssd          = true
    file_format  = "raw"
    size         = each.value.disk_size
    file_id      = proxmox_virtual_environment_download_file.this[local.node_to_download_key[each.key]].id
  }

  boot_order = ["scsi0"]

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = each.value.datastore_id
  }

  dynamic "hostpci" {
    for_each = coalesce(each.value.hostpci, [])
    content {
      device   = "hostpci${hostpci.key}"
      id       = hostpci.value.id
      xvga     = coalesce(hostpci.value.xvga, false)
      pcie     = coalesce(hostpci.value.pcie, false)
      rombar   = coalesce(hostpci.value.rombar, false)
      mdev     = hostpci.value.mdev
      mapping  = hostpci.value.mapping
      rom_file = hostpci.value.rom_file
    }
  }
}
