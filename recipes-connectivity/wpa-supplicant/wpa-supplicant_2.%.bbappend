# 
# 
# Date 		: 26-04-2022
# Descr		: Initial pre-configured WPA supplicant
#


FILESEXTRAPATHS_append := ":${THISDIR}/${PN}"
SRC_URI_append = " file://wpa_supplicant.conf-sane"

# Set some defaults, so build always works
AP_SSID  ?= "AP SSID HERE"
AP_PSK   ?= "AP PSK HERE"
STA_SSID ?= "STA SSID HERE"
STA_PSK  ?= "STA PSK HERE"

# Add our SSID and credentials from local.conf or include file
do_install_append() {
	sed -i 's/<AP_SSID>/${AP_SSID}/g'  	${D}${sysconfdir}/wpa_supplicant.conf
	sed -i 's/<AP_PSK>/${AP_PSK}/g'   	${D}${sysconfdir}/wpa_supplicant.conf	
	sed -i 's/<STA_SSID>/${STA_SSID}/g' 	${D}${sysconfdir}/wpa_supplicant.conf	
	sed -i 's/<STA_PSK>/${STA_PSK}/g'  	${D}${sysconfdir}/wpa_supplicant.conf	
}
