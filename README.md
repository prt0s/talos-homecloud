# talos-homecloud

Terraform module for mixed bare-metal + VM Talos Linux clusters
with per-node hardware profiles, IOMMU/VFIO passthrough, and inline bootstrap manifests.

One `terraform apply`. From DHCP lease to `Stage: Running Ready: true`.

## Architecture

```
[MikroTik 192.168.1.1]
    |
    +-- hw-talos-m910q-001    controlplane   metal   G4400/8G     USB
    +-- hw-talos-m910q-002    worker         metal   G4400/8G     USB passthrough + SATA (Ceph OSD)
    +-- hw-talos-m910q-003    worker         metal   G4400/8G     USB
    +-- hw-talos-14acl05      worker         metal   R5-5500U/8G  USB + USB passthrough
    +-- hw-talos-msi-gf66     worker         metal   i7-12700H/64G
                                                       RTX 3070 + USB (VFIO)
                                                       hugepages: 2048x2M + 32x1G
                                                       cpuManagerPolicy: static
                                                       mitigations=off
```

## Machine config layering

Each node's Talos config is composed from independent template layers,
merged at plan time via `concat()`:

```
config_patches = concat(
  role/controlplane.yaml.tftpl             # cluster basics, kubelet, CNI bootstrap, ArgoCD
  hw-profiles/msi-gf66.yaml.tftpl         # install disk, sysctls, hugepages, CPU pinning
  hw-features/pcie-dgpu-nvidia-*.tftpl    # VFIO kernel modules + node labels (per PCI device)
  platform/metal.yaml.tftpl                # bare-metal vs VM specifics
  pci-driver-rebind.yaml.tftpl             # Talos PCIDriverRebindConfig (per PCI device)
  local-path-provisioner-patch.yaml.tftpl  # disk-by-serial volume provisioning
)
```

You give node a hardware profile and a list of PCI devices.

```hcl
"hw-talos-msi-gf66" = {
  role        = "worker"
  hw_profile  = "msi-gf66"
  platform    = "metal"
  ip          = "192.168.1.3"
  mac_address = "D8:BB:C1:B3:FC:2E"
  hostpci = [
    { id = "0000:01:00.0", type = "pcie-dgpu-nvidia-passthrough", pcidriverrebind = "vfio-pci" },
    { id = "0000:01:00.1", type = "pcie-dgpu-nvidia-passthrough", pcidriverrebind = "vfio-pci" },
    { id = "0000:00:14.0", type = "pcie-usb-passthrough",         pcidriverrebind = "vfio-pci" },
  ]
  localvolume = [
    { model = "Micron_2450_MTFDKBA1T0TFK", serial = "214632CEC0DC", minSize = "700Gi", maxSize = "900Gi" }
  ]
}
```

CPU pinned, hugepages allocated, mitigations off.

See [`examples/locals_example.tf`](examples/locals_example.tf) for a full 5-node topology.

## What it does

- Generates per-node Talos schematics via [Image Factory](https://factory.talos.dev) (different kernel args per hardware profile)
- Downloads Talos images to Proxmox datastore (VM nodes only, `platform = "nocloud"`)
- Creates Proxmox VMs with PCI passthrough (VM nodes only)
- Applies machine configs directly to bare-metal nodes (`platform = "metal"`)
- Composes machine configuration from layered template patches
- Bootstraps the cluster with inline manifests
- Outputs kubeconfig and talosconfig

## Hardware feature templates

| Template | What it enables |
|----------|----------------|
| `pcie-dgpu-nvidia-passthrough` | vfio/vfio_pci/vfio_iommu_type1 kernel modules, nvidia GPU node label |
| `pcie-igpu-intel` | i915 kernel module, intel GPU node label |
| `pcie-sata` | ahci/ata_piix/nvme/sd_mod modules, storage node label |
| `pcie-usb` | usbserial/ch341/usb_storage + vfio modules, USB node label |
| `pcie-usb-passthrough` | vfio modules only, USB passthrough node label |

Add `machine-config/hw-features/<name>.yaml.tftpl` and reference it as `type` in a node's `hostpci` list.

## Providers

| Provider | Purpose |
|----------|---------|
| [siderolabs/talos](https://registry.terraform.io/providers/siderolabs/talos) | Machine config, secrets, bootstrap, kubeconfig |
| [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox) | VM creation + image downloads (VM nodes only) |

## Inputs

| Variable | Type | Description |
|----------|------|-------------|
| `image` | object | Image Factory URL, Talos version, schematic, architecture |
| `hw_schematics` | map(string) | Per-hardware-profile schematic YAML content |
| `cluster` | object | Cluster name, endpoint IP, gateway, Talos version |
| `nodes` | map(object) | Node definitions — role, platform, IP, hw_profile, PCI devices, local volumes |

## Outputs

| Output | Description |
|--------|-------------|
| `machine_config` | Generated Talos machine configurations per node |
| `client_configuration` | Talos client config (sensitive) |
| `kube_config` | Cluster kubeconfig (sensitive) |
| `download_links` | Proxmox image download URLs (VM nodes only) |
| `talos_nodes` | Node IP/role/host map |

## What this doesn't do

- Manage your workloads. Use Argo/Flux/Helm.
- Include bootstrap kubernetes manifests. Bring your own.
- Work on your hardware without changes. Read the hw-profiles, write your own.

## License

MIT. Do it wrong.
