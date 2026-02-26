# Full 5-node bare-metal topology example.
# Replace IPs, MACs, and PCI addresses with your own hardware.
# See modules/talos/machine-config/hw-profiles/ for hardware profile templates.

locals {
  cluster_name     = "talos-001"
  cluster_endpoint = "192.168.1.4"
  cluster_gateway  = "192.168.1.1"

  talos_version        = "v1.10.4"
  talos_update_version = "v1.10.4"

  # Each key becomes the node's hostname.
  # hw_profile selects machine-config/hw-profiles/<name>.yaml.tftpl
  # hostpci[].type selects machine-config/hw-features/<type>.yaml.tftpl
  # pcidriverrebind triggers machine-config/pci-driver-rebind.yaml.tftpl
  nodes = {
    # Controlplane — Lenovo M910Q, G4400/8G, USB kernel modules loaded
    "hw-talos-m910q-001" = {
      role        = "controlplane"
      hw_profile  = "m910q"
      platform    = "metal"
      ip          = "192.168.1.4"
      mac_address = "6C:4B:90:6C:B0:E3"
      hostpci = [
        { id = "0000:00:14.0", type = "pcie-usb" }
      ]
    }

    # Worker — M910Q with USB controller rebound to VFIO + SATA for Ceph OSD
    "hw-talos-m910q-002" = {
      role        = "worker"
      hw_profile  = "m910q"
      platform    = "metal"
      ip          = "192.168.1.5"
      mac_address = "6C:4B:90:2B:96:9C"
      hostpci = [
        { id = "0000:00:14.0", type = "pcie-usb-passthrough", pcidriverrebind = "vfio-pci" },
        { id = "0000:00:17.0", type = "pcie-sata" },
      ]
    }

    # Worker — M910Q, generic compute
    "hw-talos-m910q-003" = {
      role        = "worker"
      hw_profile  = "m910q"
      platform    = "metal"
      ip          = "192.168.1.6"
      mac_address = "6C:4B:90:3A:C1:D7"
      hostpci = [
        { id = "0000:00:14.0", type = "pcie-usb" },
      ]
    }

    # Worker — Lenovo 14ACL05, R5-5500U/8G
    "hw-talos-14acl05" = {
      role        = "worker"
      hw_profile  = "14acl05"
      platform    = "metal"
      ip          = "192.168.1.7"
      mac_address = "1C:BF:CE:BE:48:F8"
      hostpci = [
        { id = "0000:00:14.0", type = "pcie-usb" },
        { id = "0000:02:00.0", type = "pcie-usb-passthrough", pcidriverrebind = "vfio-pci" },
      ]
    }

    # Worker — MSI GF66, i7-12700H/64G, RTX 3070 + USB controller via VFIO
    # hw-profile sets: hugepages, cpuManagerPolicy: static, taint, reservedSystemCPUs
    # schematic sets: mitigations=off, vfio-pci.ids, cpufreq governor
    "hw-talos-msi-gf66" = {
      role        = "worker"
      hw_profile  = "msi-gf66"
      platform    = "metal"
      ip          = "192.168.1.3"
      mac_address = "D8:BB:C1:B3:FC:2E"
      hostpci = [
        { id = "0000:01:00.0", type = "pcie-dgpu-nvidia-passthrough", pcidriverrebind = "vfio-pci" },
        { id = "0000:01:00.1", type = "pcie-dgpu-nvidia-passthrough", pcidriverrebind = "vfio-pci" },
        { id = "0000:00:14.0", type = "pcie-usb-passthrough", pcidriverrebind = "vfio-pci" },
      ]
      localvolume = [
        { model = "Micron_2450_MTFDKBA1T0TFK", serial = "214632CEC0DC", minSize = "700Gi", maxSize = "900Gi" }
      ]
    }
  }

  # Per-hardware-profile schematics — different kernel args and extensions per machine
  hw_schematics = {
    "m910q"    = file("${path.module}/../modules/talos/image/schematic-hw-m910q.yaml")
    "msi-gf66" = file("${path.module}/../modules/talos/image/schematic-hw-msi-gf66.yaml")
    "14acl05"  = file("${path.module}/../modules/talos/image/schematic-hw-14acl05.yaml")
  }

  # Base image config — shared across all nodes that don't have a hw_profile
  image = {
    factory_url    = "https://factory.talos.dev"
    version        = local.talos_version
    update_version = local.talos_update_version
    schematic      = file("${path.module}/../modules/talos/image/schematic.yaml")
  }

  # Cilium and ArgoCD manifests are not included in this repo.
  # Provide your own install manifests or use Helm-based bootstrap instead.
  cilium = {
    install = file("${path.module}/manifests/cilium-install.yaml")
    values  = file("${path.module}/manifests/cilium-values.yaml")
  }

  argocd = {
    install = file("${path.module}/manifests/argocd-install.yaml")
    version = "3.0.6"
  }

  cluster = {
    name          = local.cluster_name
    endpoint      = local.cluster_endpoint
    gateway       = local.cluster_gateway
    talos_version = "v1.10"
  }
}

module "talos" {
  source = "../modules/talos"

  image         = local.image
  hw_schematics = local.hw_schematics
  cilium        = local.cilium
  argocd        = local.argocd
  cluster       = local.cluster
  nodes         = local.nodes
}
