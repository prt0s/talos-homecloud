output "machine_config" {
  value     = data.talos_machine_configuration.this
  sensitive = false
}

output "client_configuration" {
  value     = data.talos_client_configuration.this
  sensitive = true
}

output "kube_config" {
  value     = talos_cluster_kubeconfig.this
  sensitive = true
}

output "download_links" {
  value = {
    for key, file in proxmox_virtual_environment_download_file.this :
    key => {
      file_name = file.file_name
      url       = file.url
    }
  }
}

output "talos_nodes" {
  value = {
    for name, node in var.nodes :
    name => {
      ip        = node.ip
      role      = node.role
      host_node = node.host_node
      vm_id     = node.vm_id
    }
  }
}
