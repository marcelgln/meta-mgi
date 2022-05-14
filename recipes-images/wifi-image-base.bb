SUMMARY = "A console-only image that th WIFI support, including default AP for configuration and opkg package management" 

IMAGE_FEATURES_append = " ssh-server-openssh"

PACKAGE_CLASSES = "package_ipk"

# DISTRO_FEATURES_remove = " 3g irda nfc"

IMAGE_INSTALL_append = " \
 	opkg \
	kernel-modules \
	linux-firmware-bcm43430 \
	wpa-supplicant 	\
	wpa-ap-fallback-cfg \
	dnsmasq 	\
"


LICENSE = "MIT"


inherit core-image
