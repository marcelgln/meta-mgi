# Custom init-ifupdown

# Files directory
FILESEXTRAPATHS_prepend := "${THISDIR}/files:"

# Sources
SRC_URI_append = " \
    file://wlan0.dhcp \
"

# Maybe later add selection option for static cfg via local.conf
do_install_append() {
	install -m 0644 ${S}/wlan0.dhcp ${D}${sysconfdir}/network/interfaces
}
