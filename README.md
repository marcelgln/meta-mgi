# meta-mgi

This is Yocto meta layer intended for some Raspberry Pi projects. It is used on top of [meta-raspberrypi](https://github.com/agherzan/meta-raspberrypi)
It first use will be for a headless [squeezelite](https://github.com/ralph-irving/squeezelite) using an RPI Zero-W on a custom baseboard (I do not like using a 'hat' for a small board). The baseboard does not include a power aamplifier, instead it has mains input and a switched mains output to control power of an external amplifier. The used DAC is a PCM5142 with (optional) a PLL1708 as clock source. 

## Current functionality (wifi-image-base)
*   WIFI client mode with fallback to an acces point during boot in case of failure
*   u-boot bootloader
*   Partition layout prepared for redundant kernel/rootfs which allows for complete filesystem update
    * Dual partition for kernel/device tree
    * Dual rootfs partition
    * Partition for optional recovery system
    * Partition for persistent data
    * Dual partition for u-boot environment

## Partition layout
Currently the rootfs partitions are not really large. For dedicated applications often a roots < 350MiB is more than sufficient. Size is however easy adaptable in the sdcard class. 
In a later stage, u-boot will be configured to store its environment as RAW on the SD-card. In practice it is not required to use a 
partition for this. Free space with a sector offset is enough for u-boot. It is however convenient to be able to access it as an mtdblockpx device for accessing the environment from within Linux. The partitions for u-boot main/redundant are chosen to reside not in the same erase block of the card. This minimizes the risk that both get corrupted or erased.  

## local.conf
local.conf resides in: build-configs/rpi0w/conf  
I usually create a symbolic link from the build directory to conf: 
> conf -> ../meta-mgi/build-configs/rpi0w/conf

## Access point falback
Most other solutions I have seen use hostapd for the access point and either rely heavily on Raspian, or use 
constructs where scripts are symlinked or rewritten during boot. Since this platform will be used for dedicated solutions with 
reliability in mind, writing to sdcard is whereever possible minimized. The solution here does not used hostapd, but the 
integrated accespoint from wpa_supplicant. No write are performed to change from DHCP for client mode to static IP for AP mode. 

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
This meta layer is far from complete, but it generates an image which can be flashed to and SD card and boots on an RPI Zero-W.
Normally Yocto creates a symlink (without timestamp) to the last sdcard image build, this symlink is currently not created.  
At this moment the RPI fat32 boot partition is duplicated to both kernel partitions (which are not used yet). This wil be change later  and the kernel partitions will be changed from Fat32 to ext4, since fat32 more sensitive for corruption. 

## Next steps
* Implement boot partition selection 
* Move network configuration to persistent data partition, so it is not overwritten during filesystem updates.



