# 
# 
# Date 		: 01-05-2022
# Descr		: Overrrides dnsmasg.conf for DHCP server on acces point
#
FILESEXTRAPATHS_append := ":${THISDIR}/${PN}"
SRC_URI_append = " file://dnsmasq.conf"
