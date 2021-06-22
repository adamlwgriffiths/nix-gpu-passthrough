# Windows GPU Passthrough with Nix and QEmu/Libvirt

Describes how to setup GPU passthrough with a Linux/Nix host and Windows guest.

Caveat: This is currently missing a lot of information as it is written retroactively.

## System Layout

* Linux Host
* Windows 10 guest (running from VM disk image)
* Nvidia GPU passthrough
* USB/PCI passthrough

## What Works

* Nvidia GPU/Audio passthrough and restoration on VM shutdown
* HDD passthrough with VFIO (drive dedicated to VM)
* USB passthrough (entire USB controller on motherboard)
* Bluetooth in guest
* NixOS 20.09

## What Doesn't

* QEmu/Libvirt start/stop hooks (insufficient permissions?)
* Often the VM seems to require Install CD to be in or it doesn't bootstrap
* NixOS 21.05 (GPU won't pass off)

## Future Work

* Wrap most of this in a [Nix derivative](https://gist.github.com/techhazard/1be07805081a4d7a51c527e452b87b26).
* Make a Packer windows image with VFIO drivers.

## Installation

We need to do a basic install before swapping the VFIO versions of HDDs and systems
as the Windows 10 installer doesn't work with these devices.

### Nix preparation

#### Get the Device ID of your GPU

    $ lspci
    # find IOMMU group of gpu and audio device

Eg.

    $ lspci
    ...
    01:00.0 VGA compatible controller: NVIDIA Corporation GP104 [GeForce GTX 1080] (rev a1)
    01:00.1 Audio device: NVIDIA Corporation GP104 High Definition Audio Controller (rev a1)

For each device, get the device ID

    $ lspci -nns <id>

Eg.

    $ lspci -nns 01:00.0
    01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GP104 [GeForce GTX 1080] [10de:1b80] (rev a1)
    $ lspci -nns 01:00.1
    01:00.1 Audio device [0403]: NVIDIA Corporation GP104 High Definition Audio Controller [10de:10f0] (rev a1)

The ID for the GPU and audio devices are `10de:1b80` and `10de:10f0`


#### Nix config

TODO


### Bootstrapping

1. Install VM:
  * Set Chipset to Q35
  * Firmware: UEFI to OVMF_CODE.fd
  * Replace IDE devices with SATA equivalents (CDROM, HDD)
  * Set CPU topology as appropriate
    * [/] Copy host CPU Configuration
    * [/] Manually set CPU topology
    * Set with values from `lscpu`
2. Edit the CPU XML to pin the processes to specific CPUs:
Eg.
```
    <cputune>
        <vcpupin vcpu='0' cpuset='0'/>
        <vcpupin vcpu='1' cpuset='1'/>
        <vcpupin vcpu='2' cpuset='2'/>
        <vcpupin vcpu='3' cpuset='3'/>
    </cputune>
```
3. Copy over Redhat VFIO drivers.
4. Install [VFIO drivers](https://docs.fedoraproject.org/en-US/quick-docs/creating-windows-virtual-machines-using-virtio-drivers/) for HDD.

### Convert Disks to VirtIO

1. Note the path to the existing image file.
2. Remove the existing Storage
3. Add Hardware > Storage
* Select or create custom storage: Path above
* Device type: Disk device.
* Bus type: VirtIO.

Convert disk image to VirtIO Disk

### Convert network to VirtIO

1. Remove existing network device
2. Add Hardware > Network
* Network source: Macvtap device
* Device name: NIC name (look up with `ifconfig`)
* Device model: virtio

### Mounting physical drives

1. Find the device by ID: `ls /dev/disk/by-id/` (Eg. /dev/disk/by-id/ata-ST2000DX002-2DV164_Z4ZB3Z96)
2. Add Hardware > Storage
* Select or create custom storage: Device ID from above.
* Device type: Disk Device.
* Bus type: VirtIO.
* Cache mode: None.

#### Determine IOMMU group

TODO all the other stuff

### Add PCI devices

1. Run `lspci`
2. Note the device IDs for the devices you want passed through
* Eg. 0000:01:00.0
3. Add Hardware > PCI Host Device > Device ID from above

### Obscure VM from Nvidia/AMD

#### Hide the VM

1. Overview > `XML` tab
2. Find the `<features>` node
3. Add the following:

    <features>
        <hyperv>
            <vendor_id state='on' value='randomid'/>
            ...
        </hyperv>
        <kvm>
          <hidden state="on"/>
        </kvm>
    </features>

#### Patch Nvidia ROM

```
$ sudo ./extract-vbios-nvflash.sh
$ python nvidia_vbios_vfio_patcher.py -i VBIOS.rom -o VBIOS-patched.rom
$ sudo cp VBIOS-patched.rom /var/lib/libvirt/hooks/nvbios-patched.rom
```

1. PCI <Nvidia GPU device id> > 'XML' tab
2. Within the `<hostdev ...>` node add the following child
*   `<rom file="/path/to/patched/rom/patched.rom"/>`

Eg.

    <hostdev mode="subsystem" type="pci" managed="yes">
      <source>
        <address domain="0x0000" bus="0x01" slot="0x00" function="0x0"/>
      </source>
      <rom file="/var/lib/libvirt/hooks/nvbios-patched.rom"/>
      <address type="pci" domain="0x0000" bus="0x08" slot="0x00" function="0x0"/>
    </hostdev>


### Post Install

#### Fix crackling in Windows Guest VM with Nvidia

1. Boot Windows VM
2. Use [`MSI_util_v3.zip`](https://www.mediafire.com/file/ewpy1p0rr132thk/MSI_util_v3.zip/file)
3. Set MSI enabled for all audio devices
4. Apply
5. Restart Windows VM


# References

https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF
https://nixos.wiki/wiki/Nvidia

Nix + VFIO / Passthrough
* https://alexbakker.me/post/nixos-pci-passthrough-qemu-vfio.html
* https://gist.github.com/CRTified/43b7ce84cd238673f7f24652c85980b3
* https://gist.github.com/techhazard/1be07805081a4d7a51c527e452b87b26

Non-Nix
* https://gitlab.com/risingprismtv/single-gpu-passthrough/-/tree/master
* https://gitlab.com/YuriAlek/vfio/-/blob/master/Hardware%20configurations/FX6300%20-%20GTX%20970%20-%20@SSStormy.md
* https://github.com/joeknock90/Single-GPU-Passthrough
