#!/bin/sh
#
#
# SCRIPT  : wifi_ap_fallback.sh
# AUTHOR  : Marcel Gielen <design@mgielen.nl>
# DATE	  : 2022-04-30
# DESCR	  : Intended for a Raspberry PI Zero W to handle configuration of the built-in acces point 
#           from wpa_supplicant, which is started in case a network connection could not be established.      
# USED ON : Poky Dunfell using meta-raspberripi (git://git.yoctoproject.org/meta-raspberrypi) 
#	    'core-image-base' with MACHINE=raspberrypi0-wifi and the following added packages: 
#		- linux-firmware-bcm43430
#		- wpa_supplicant 
#		- dnsmasq
#
# The script should be executed somewhere at the end of the boot sequence. 
#
# It uses the 'id_str' from the acces point definition in wpa_supplicant.conf to obtain the AP
# static ip address from: /etc/network/interfaces. 
#
# === Example wpa_supplicant.conf === 
#
#	ctrl_interface=/var/run/wpa_supplicant
#	ctrl_interface_group=0
#	update_config=1
#	ap_scan=1
#
### auto hotspot ###      	      # has to be the first network section!
#	network={
#    		priority=0            # Lowest priority, so wpa_supplicant prefers the other networks below
#    		ssid="hotspot"        # Access point name
#    		mode=2
#    		key_mgmt=WPA-PSK
#    		psk=<PASSWORD FOR ACCES POINT>  
#    		frequency=2462
#    		id_str="acces_point"  # links to interfaces file for AP static IP address
#	}
#
#
### Client (STA) mode
#	network={
#        	ssid=<SSID to connect to>
#        	psk=<password or key>
#        	proto=RSN
#        	key_mgmt=WPA-PSK
#	}
#
#
# === Example interfaces ===
#
## Loopback interface
#	auto lo
#	iface lo inet loopback
#
## Client using DHCP
#	auto wlan0
#	iface wlan0 inet dhcp
#	wireless_mode managed
#       wireless_essid any
#       wpa-driver nl80211
#       wpa-conf /etc/wpa_supplicant.conf
#
## Access point using static IP
#	iface acces_point inet static	# name 'acces_point' corresponds with id_str 
#        	address 192.168.1.1
#

# Our interface
INTERFACE=wlan0

# Avoid an endless loop and generate a log message on failure.
# it should not be too short, otherwise the AP might not have been started by wpa_supplicant.
MAX_RETRY_SECONDS=45

attempts=1
while [ $attempts -le $MAX_RETRY_SECONDS ]
do

	WPA_STATUS=`wpa_cli -i $INTERFACE status`

	if echo $WPA_STATUS | grep -q "mode=station" && echo $WPA_STATUS | grep -q "wpa_state=COMPLETED"; then
		logger "$INTERFACE: STA mode detected and connected"
		exit 0
	elif echo $WPA_STATUS | grep -q "mode=AP" && echo $WPA_STATUS | grep -q "wpa_state=COMPLETED"; then
		ID_STR=`wpa_cli status | grep id_str | awk -F "=" '{print $2}'`
		IP_ADDR=`grep -A 1 $ID_STR /etc/network/interfaces | grep address | awk '{print $2;}'`
		logger "$INTERFACE: AP mode detected, setting static IP address to: $IP_ADDR"
		ifconfig wlan0 $IP_ADDR
		exit 0
	fi
	attempts=$((attempts+1))
	sleep 1
done

if [ $attempts -gt $MAX_RETRY_SECONDS ]; then
	logger -p user.err "$0 $INTERFACE: No valid connection or access point in wpa_cli status" 
fi 
