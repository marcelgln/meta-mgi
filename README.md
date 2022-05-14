# meta-mgi

This is Yocto meta layer intended for some Raspberry Pi projects. It is used on top of [meta-raspberrypi](https://github.com/agherzan/meta-raspberrypi)

## Current functionality (wifi-image-base)
*   WIFI client mode with fallback to an acces point during boot in case of failure
*   u-boot bootloader
*   Partition layout prepared for redundant kernel/rootfs which allows for complete filesystem update
    * Dual partition for kernel/device tree
    * Dual rootfs partition
    * Partition for optional recovery system
    * Partition for persistent data
    * Dual partition for u-boot environment

## local.conf
local.conf resides in: build-configs/rpi0w/conf  
I usually create a symbolic link from the build directory to conf: 
> conf -> ../meta-mgi/build-configs/rpi0w/conf

## Network configuration
local.conf includes a file credentials.inc which is not included in this repository. 
credentials.inc must contain the following:
> AP_SSID = "acces point SSID"

> AP_PSK  = "acces point password"

> STA_SSID = "SSID to connect to"

> STA_PSK  = "password/psk"


In client mode DHCP is used. When the client connection fails during boot, the access point is started with a 
static IP address at 192.168.1.1 (configured in /etc/network/interfaces) and a DHCP server (dnsmasq)

## Known issues 
This meta layer is far from complete, but it generates an image which can be flashed to and SD card and boots on an RPI Zero-W
Normally Yocto created a symlink (without tiemstamp) to the last sdcard image build, this symlink is missing here.  

## Next steps
* Implement boot partition selection 
* Move network configuration to persistent data partition, so it is not overwritten during filesystem updates.



