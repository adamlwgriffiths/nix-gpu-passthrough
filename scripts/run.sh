#!/usr/bin/env bash

# at the moment this needs to be run from a VT as root
# Ctrl + Alt + F1
# $ sudo su -
# $ ./run.sh

# script is quite messy as it has a lot of debug from various attempts to
# get this working.
# the stats, lsmod.* files contain diagnostic information

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
pushd $DIR

#BASE=/var/lib/libvirt/hooks/qemu.d/windows
#START=$BASE/prepare/begin/start.sh
#END=$BASE/release/end/revert.sh

START="$DIR/start.sh"
STOP="$DIR/stop.sh"

lsmod > lsmod.before
awk '{print $1}' lsmod.before | sort > lsmod.before.modules

###############################################################
echo `date +"%Y-%m-%d %T"` "Shutting down devices..." > status
#$START

#systemctl stop ckb-next.service
systemctl stop display-manager.service
#killall gdm-x-session

echo `date +"%Y-%m-%d %T"` "Unbinding VTs..." >> status
echo 0 > /sys/class/vtconsole/vtcon0/bind
echo 0 > /sys/class/vtconsole/vtcon1/bind

echo `date +"%Y-%m-%d %T"` "Unbinding framebuffer 0..." >> status
echo "efi-framebuffer.0" > /sys/bus/platform/drivers/efi-framebuffer/unbind

sleep 5

echo `date +"%Y-%m-%d %T"` "Unloading Nvidia modules..." >> status
modprobe -r nvidia_uvm
modprobe -r nvidia_drm
modprobe -r nvidia_modeset
modprobe -r drm_kms_helper
modprobe -r drm
modprobe -r nvidia
modprobe -r snd_hda_intel

#modprobe nouveau

echo `date +"%Y-%m-%d %T"` "Detaching PCI devices..." >> status
virsh nodedev-detach pci_0000_01_00_0
virsh nodedev-detach pci_0000_01_00_1

echo `date +"%Y-%m-%d %T"` "Loading VFIO modules..." >> status
modprobe vfio-pci



###############################################################
echo `date +"%Y-%m-%d %T"` "Starting VM..." >> status
virsh start windows


###############################################################
echo `date +"%Y-%m-%d %T"` "Waiting for VM to shutdown..." >> status
sleep 2
while [[ `virsh domstate windows` != "shut off" ]]; do
  #echo `virsh domstate windows`
  sleep 1
done

echo `date +"%Y-%m-%d %T"` "VM Shutdown detected..." >> status
sleep 2
echo `date +"%Y-%m-%d %T"` "Re-initialising devices..." >> status
#$END

# stop.sh
echo `date +"%Y-%m-%d %T"` "Unloading VFIO modules..." >> status
modprobe -r vfio_iommu_type1
modprobe -r vfio_pci
modprobe -r vfio

echo `date +"%Y-%m-%d %T"` "Reattaching PCI devices..." >> status
virsh nodedev-reattach pci_0000_01_00_1
virsh nodedev-reattach pci_0000_01_00_0

echo 1 > /sys/class/vtconsole/vtcon0/bind
echo 1 > /sys/class/vtconsole/vtcon1/bind

echo `date +"%Y-%m-%d %T"` "Unloading VFIO modules..." >> status
nvidia-xconfig --query-gpu-info > /dev/null 2>&1

echo `date +"%Y-%m-%d %T"` "Rebinding framebuffer 0..." >> status
echo "efi-framebuffer.0" > /sys/bus/platform/drivers/efi-framebuffer/bind

echo `date +"%Y-%m-%d %T"` "Loading Nvidia modules..." >> status
modprobe nvidia_uvm
modprobe nvidia_drm
modprobe nvidia_modeset
modprobe drm_kms_helper
modprobe drm
modprobe nvidia
modprobe snd_hda_intel

modprobe nouveau

modprobe macvtap
modprobe vhost
modprobe vhost_net

sleep 1

###############################################################

echo `date +"%Y-%m-%d %T"` "Restarting services..." >> status
systemctl start display-manager.service
#systemctl start ckb-next.service

lsmod > lsmod.after
awk '{print $1}' lsmod.after | sort > lsmod.after.modules
diff lsmod.before.modules lsmod.after.modules > lsmod.diff

popd
