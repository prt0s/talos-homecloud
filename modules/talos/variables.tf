variable "image" {
  type = object({
    factory_url       = optional(string, "https://factory.talos.dev")
    schematic         = string
    version           = string
    update_schematic  = optional(string)
    update_version    = optional(string)
    arch              = optional(string, "amd64")
    platform          = optional(string, "nocloud")
    proxmox_datastore = optional(string, "local")
  })
}

variable "hw_schematics" {
  type = map(string)
}

variable "cluster" {
  type = object({
    name          = string
    endpoint      = string
    gateway       = string
    talos_version = string
    check_health  = optional(bool, false)
  })
}

variable "nodes" {
  type = map(object({
    role          = string
    hw_profile    = optional(string)
    platform      = string
    started       = optional(bool, true)
    host_node     = optional(string)
    datastore_id  = optional(string, "local-lvm")
    ip            = string
    mac_address   = string
    vm_id         = optional(number)
    cpu           = optional(number, 2)
    cpu_type      = optional(string, "host")
    ram_dedicated = optional(number, 4096)
    bridge        = optional(string, "vmbr0")
    disk_size     = optional(number, 32)
    update        = optional(bool, false)
    hostpci = optional(list(object({
      id              = string
      type            = string
      pcidriverrebind = optional(string)
      xvga            = optional(bool)   # vm only
      pcie            = optional(bool)   # vm only
      rombar          = optional(bool)   # vm only
      mdev            = optional(bool)   # vm only
      mapping         = optional(string) # vm only
      rom_file        = optional(string) # vm only
    })))
    localvolume = optional(list(object({
      serial  = string
      model   = string
      minSize = string
      maxSize = string
    })))
  }))
}

variable "cilium" {
  type = object({
    values  = string
    install = string
  })
}

variable "argocd" {
  type = object({
    version = string
    install = string
  })
}

