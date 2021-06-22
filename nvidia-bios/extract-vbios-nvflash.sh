
## Check if the script was executed as root
[[ "$EUID" -ne 0 ]] && echo "Please run as root" && exit 1

## Load the config file
source ./config

## Kill the Display Manager
systemctl stop display-manager.service
killall gdm-x-session

## Remove the framebuffer and console
echo 0 > /sys/class/vtconsole/vtcon0/bind
echo 0 > /sys/class/vtconsole/vtcon1/bind
echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/unbind

sleep 2

# Unload the Kernel Modules that use the GPU
modprobe -r nvidia_drm
modprobe -r nvidia_modeset
modprobe -r nvidia_uvm
modprobe -r nvidia
#modprobe -r snd_hda_intel

sleep 2

## Extract the VBIOS
#NVFLASH=./nvflash_linux
#VBIOS_EXTRACT_PATH=nvbios.rom
$NVFLASH --save $VBIOS_EXTRACT_PATH


# Reload the kernel modules
#modprobe snd_hda_intel
modprobe nvidia_drm
modprobe nvidia_modeset
modprobe nvidia_uvm
modprobe nvidia


## Reload the framebuffer and console
echo 1 > /sys/class/vtconsole/vtcon0/bind
echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/bind


# Reload the Display Manager to access X
systemctl start display-manager.service

