systemctl stop display-manager.service

echo 0 > /sys/class/vtconsole/vtcon0/bind
echo 0 > /sys/class/vtconsole/vtcon1/bind

echo "efi-framebuffer.0" > /sys/bus/platform/drivers/efi-framebuffer/unbind

sleep 2

modprobe -r nvidia_uvm
modprobe -r nvidia_drm
modprobe -r nvidia_modeset
modprobe -r drm_kms_helper
modprobe -r drm
modprobe -r nvidia
modprobe -r snd_hda_intel

virsh nodedev-detach pci_0000_01_00_0
virsh nodedev-detach pci_0000_01_00_1

modprobe vfio-pci

sleep 1
