
modprobe -r vfio_iommu_type1
modprobe -r vfio_pci
modprobe -r vfio

virsh nodedev-reattach pci_0000_01_00_1
virsh nodedev-reattach pci_0000_01_00_0

echo 1 > /sys/class/vtconsole/vtcon0/bind
echo 1 > /sys/class/vtconsole/vtcon1/bind

nvidia-xconfig --query-gpu-info > /dev/null 2>&1

echo "efi-framebuffer.0" > /sys/bus/platform/drivers/efi-framebuffer/bind

modprobe nvidia_uvm
modprobe nvidia_drm
modprobe nvidia_modeset
modprobe drm_kms_helper
modprobe drm
modprobe nvidia
modprobe snd_hda_intel

#modprobe nouveau

modprobe macvtap
modprobe vhost
modprobe vhost_net

sleep 1

systemctl start display-manager.service
