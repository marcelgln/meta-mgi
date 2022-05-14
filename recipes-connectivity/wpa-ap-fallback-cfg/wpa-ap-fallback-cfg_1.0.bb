SUMMARY = "Recipe which installs init script which configures static IP if wpa_supplicant AP is started at boot"
DESCRIPTION = ""
LICENSE = "CLOSED"

inherit update-rc.d

INITSCRIPT_NAME = "wpa-ap-fallback-cfg"
INITSCRIPT_PARAMS = "start 50 2 3 4 5 ."

SRC_URI = "file://wpa-ap-fallback-cfg.sh \
           file://initscript \
	"

S = "${WORKDIR}"

do_install () {
	install -d ${D}${bindir}
	install -m 0755 ${WORKDIR}/wpa-ap-fallback-cfg.sh ${D}${bindir}/

	install -d ${D}${sysconfdir}/init.d/
        install -m 0755 ${WORKDIR}/initscript ${D}${sysconfdir}/init.d/wpa-ap-fallback-cfg
}

