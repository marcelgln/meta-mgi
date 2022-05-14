inherit image_types

#
# Create an image that can be written onto a SD card using dd.
# Target card size <= 4 GiB
#
# Note: Although I could not find clear information, it seems the RPI-zeroW
#       requires the boot partition to be the first partition on the card. 
#
#	It is not strictly necessary, but it is sometimes convenient to have 
#	the u-boot environment accessible as mmcblk device.
#
# Disk image layout:
#
# PT   	   	   SIZE         FS type
# ----------------------------------------------------------------------------
# MBR		  		-	  First partition starts at 4MiB 		
# Unallocated  	          	-	  
# P1  BOOT 	-> 40MiB        Fat32 	  Bootloader (fat32 mandatory for RPI)
# P2  UBENV1	-> 4MiB		-	  U-Boot main environment
# P3  EXTENDED	-> 4MiB		-	  Extended partition definition
# L5  RECOVERY	-> 300MiB	ext3	  Optional recovery kernel+fs
# L6  UBENV2	-> 4MiB		-	  U-boot redundant environment	
# L7  KERNEL1	-> 40MiB	ext3	  Kernel + dt for boot image 1
# L8  ROOTFS1   -> 375MiB	ext3      Rootfs for boot image 1
# L9  KERNEL2	-> 40MiB	ext3	  Kernel + dt for boot image 2 
# L10 ROOTFS2   -> 375MiB	ext3      Rootfs for boot image 2
# L11 DATA	-> 200MiB	ext3	  Persistent data
# 
#    UBENV1, UBENV2 size == PRTITION_ALIGMENT == 4MiB 	
#
# To execute only the sdard image build, without re-creating the rootfs do: 
#
# bitbake -f -c do_image_dual_sdimg <image name>
#

# This image depends on the rootfs image
IMAGE_TYPEDEP_dual-sdimg = "${SDIMG_ROOTFS_TYPE}"

# Set kernel and boot loader
IMAGE_BOOTLOADER ?= "bootfiles"

# Kernel image name
SDIMG_KERNELIMAGE_raspberrypi  ?= "kernel.img"
SDIMG_KERNELIMAGE_raspberrypi2 ?= "kernel7.img"
SDIMG_KERNELIMAGE_raspberrypi3-64 ?= "kernel8.img"

# Boot partition volume id
BOOTDD_VOLUME_ID ?= "${MACHINE}"

# Set alignment to 4MB [in KiB]
PARTITION_ALIGNMENT = "4096"

# Size reserved for both u-boot environment areas
PT_UBENV_SIZE 		?= "${PARTITION_ALIGNMENT}"
# Boot partition size [in KiB] (will be rounded up to PARTITION_ALIGNMENT) Must be > 32768 due to FAT32 minimum size
PT_BOOT_SIZE 		?= "40960"
# Recovery partition size [in KiB]
PT_RECOVERY_SIZE 	?= "307200"
# Kernel partition size	(extended). 
# Size must be same as boot partition, currently we copy the FAT boot image to boot/kernel1/kernel2
PT_KERNEL_SIZE		?= "${PT_BOOT_SIZE}"
# Rootfs partition size (extended)
PT_ROOTFS_SIZE		?= "384000"
# Data partition size	(extended)
PT_DATA_SIZE		?= "102400"


# Use an uncompressed ext3 by default as rootfs
SDIMG_ROOTFS_TYPE ?= "ext3"
SDIMG_ROOTFS = "${IMGDEPLOYDIR}/${IMAGE_LINK_NAME}.${SDIMG_ROOTFS_TYPE}"

# For the names of kernel artifacts
inherit kernel-artifact-names

RPI_SDIMG_EXTRA_DEPENDS ?= ""

do_image_dual_sdimg[depends] = " \
    parted-native:do_populate_sysroot \
    mtools-native:do_populate_sysroot \
    dosfstools-native:do_populate_sysroot \
    virtual/kernel:do_deploy \
    ${IMAGE_BOOTLOADER}:do_deploy \
    rpi-config:do_deploy \
    ${@bb.utils.contains('MACHINE_FEATURES', 'armstub', 'armstubs:do_deploy', '' ,d)} \
    ${@bb.utils.contains('RPI_USE_U_BOOT', '1', 'u-boot:do_deploy', '',d)} \
    ${@bb.utils.contains('RPI_USE_U_BOOT', '1', 'u-boot-default-script:do_deploy', '',d)} \
    ${RPI_SDIMG_EXTRA_DEPENDS} \
"

do_image_rpi_sdimg[recrdeps] = "do_build"

# SD card image name
SDIMG = "${IMGDEPLOYDIR}/${IMAGE_NAME}${IMAGE_NAME_SUFFIX}.rpi-sdimg"

# Additional files and/or directories to be copied into the vfat partition from the IMAGE_ROOTFS.
FATPAYLOAD ?= ""

# SD card vfat partition image name
SDIMG_VFAT_DEPLOY ?= "${RPI_USE_U_BOOT}"
SDIMG_VFAT = "${IMAGE_NAME}.vfat"
SDIMG_LINK_VFAT = "${IMGDEPLOYDIR}/${IMAGE_LINK_NAME}.vfat"

def split_overlays(d, out, ver=None):
    dts = d.getVar("KERNEL_DEVICETREE")
    # Device Tree Overlays are assumed to be suffixed by '-overlay.dtb' (4.1.x) or by '.dtbo' (4.4.9+) string and will be put in a dedicated folder
    if out:
        overlays = oe.utils.str_filter_out('\S+\-overlay\.dtb$', dts, d)
        overlays = oe.utils.str_filter_out('\S+\.dtbo$', overlays, d)
    else:
        overlays = oe.utils.str_filter('\S+\-overlay\.dtb$', dts, d) + \
                   " " + oe.utils.str_filter('\S+\.dtbo$', dts, d)

    return overlays

IMAGE_CMD_dual-sdimg () {

    # Align partition sizes 
    PT_BOOT_SIZE_ALIGNED=$(expr ${PT_BOOT_SIZE} + ${PARTITION_ALIGNMENT} - 1)
    PT_BOOT_SIZE_ALIGNED=$(expr ${PT_BOOT_SIZE_ALIGNED} - ${PT_BOOT_SIZE_ALIGNED} % ${PARTITION_ALIGNMENT} )

    PT_RECOVERY_SIZE_ALIGNED=$(expr ${PT_RECOVERY_SIZE} + ${PARTITION_ALIGNMENT} - 1) 
    PT_RECOVERY_SIZE_ALIGNED=$(expr ${PT_RECOVERY_SIZE_ALIGNED} / ${PARTITION_ALIGNMENT} \* ${PARTITION_ALIGNMENT}) 

    # Extended parition size is increased by PRTITION_ALIGNMENT to compensate for extended partiton header 	
    PT_KERNEL_SIZE_ALIGNED=$(expr ${PT_KERNEL_SIZE} + ${PARTITION_ALIGNMENT} - 1)
    PT_KERNEL_SIZE_ALIGNED=$(expr ${PT_KERNEL_SIZE_ALIGNED} / ${PARTITION_ALIGNMENT} \* ${PARTITION_ALIGNMENT} )

    PT_ROOTFS_SIZE_ALIGNED=$(expr ${PT_ROOTFS_SIZE} + ${PARTITION_ALIGNMENT} - 1)
    PT_ROOTFS_SIZE_ALIGNED=$(expr ${PT_ROOTFS_SIZE_ALIGNED} / ${PARTITION_ALIGNMENT} \* ${PARTITION_ALIGNMENT} )

    PT_DATA_SIZE_ALIGNED=$(expr ${PT_DATA_SIZE} + ${PARTITION_ALIGNMENT} - 1)
    PT_DATA_SIZE_ALIGNED=$(expr ${PT_DATA_SIZE_ALIGNED} / ${PARTITION_ALIGNMENT} \* ${PARTITION_ALIGNMENT} )

    # Get start offsets
    PT_BOOT_START=${PARTITION_ALIGNMENT}	
    PT_UBENV1_START=$(expr ${PT_BOOT_START} + ${PT_BOOT_SIZE_ALIGNED} )	

    # Extended partions have a partition table header before actual partition data, 
    # we set start at end of previous partition + PARTITION_ALIGNMENT	
    PT_EXTENDED_START=$(expr ${PT_UBENV1_START}    + ${PT_UBENV_SIZE})
	
    PT_RECOVERY_START=$(expr ${PT_EXTENDED_START}  + ${PARTITION_ALIGNMENT})
    PT_UBENV2_START=$(expr   ${PT_RECOVERY_START}  + ${PT_RECOVERY_SIZE_ALIGNED} + ${PARTITION_ALIGNMENT})	
    PT_KERNEL1_START=$(expr  ${PT_UBENV2_START}    + ${PT_UBENV_SIZE} 		 + ${PARTITION_ALIGNMENT})	
    PT_ROOTFS1_START=$(expr  ${PT_KERNEL1_START}   + ${PT_KERNEL_SIZE_ALIGNED}   + ${PARTITION_ALIGNMENT})	
    PT_KERNEL2_START=$(expr  ${PT_ROOTFS1_START}   + ${PT_ROOTFS_SIZE_ALIGNED}   + ${PARTITION_ALIGNMENT})
    PT_ROOTFS2_START=$(expr  ${PT_KERNEL2_START}   + ${PT_KERNEL_SIZE_ALIGNED}   + ${PARTITION_ALIGNMENT})	
    PT_DATA_START=$(expr     ${PT_ROOTFS2_START}   + ${PT_ROOTFS_SIZE_ALIGNED}   + ${PARTITION_ALIGNMENT})	

    # Get end offsets
    PT_BOOT_END=$(expr     ${PT_BOOT_START}     + ${PT_BOOT_SIZE_ALIGNED})
    PT_UBENV1_END=$(expr   ${PT_UBENV1_START}   + ${PT_UBENV_SIZE})
    PT_UBENV2_END=$(expr   ${PT_UBENV2_START}   + ${PT_UBENV_SIZE}) 
    PT_RECOVERY_END=$(expr ${PT_RECOVERY_START} + ${PT_RECOVERY_SIZE_ALIGNED})	
    PT_KERNEL1_END=$(expr  ${PT_KERNEL1_START}  + ${PT_KERNEL_SIZE_ALIGNED})	
    PT_ROOTFS1_END=$(expr  ${PT_ROOTFS1_START}  + ${PT_ROOTFS_SIZE_ALIGNED})	
    PT_KERNEL2_END=$(expr  ${PT_KERNEL2_START}  + ${PT_KERNEL_SIZE_ALIGNED})	
    PT_ROOTFS2_END=$(expr  ${PT_ROOTFS2_START}  + ${PT_ROOTFS_SIZE_ALIGNED})	
    PT_DATA_END=$(expr     ${PT_DATA_START}     + ${PT_DATA_SIZE_ALIGNED})
	

	bbwarn "PT_BOOT_SIZE_ALIGNED=${PT_BOOT_SIZE_ALIGNED}"
	bbwarn "PT_RECOVERY_SIZE_ALIGNED=${PT_RECOVERY_SIZE_ALIGNED}"
	bbwarn "PT_KERNEL_SIZE_ALIGNED=${PT_KERNEL_SIZE_ALIGNED}"
	bbwarn "PT_ROOTFS_SIZE_ALIGNED=${PT_ROOTFS_SIZE_ALIGNED}"
	bbwarn "PT_DATA_SIZE_ALIGNED=${PT_DATA_SIZE_ALIGNED}"		
	
	bbwarn "PT_BOOT_START=${PT_BOOT_START}"
	bbwarn "PT_RECOVERY_START=${PT_RECOVERY_START}"
	bbwarn "PT_EXTENDED_START=${PT_EXTENDED_START}"
	bbwarn "PT_KERNEL1_START=${PT_KERNEL1_START}"
	bbwarn "PT_ROOTFS1_START=${PT_ROOTFS1_START}"
	bbwarn "PT_KERNEL2_START=${PT_KERNEL2_START}"			

	bbwarn "PT_KERNEL1_END=${PT_KERNEL1_END}"
	bbwarn "PT_ROOTFS1_END=${PT_ROOTFS1_END}"
	bbwarn "PT_KERNEL2_END=${PT_KERNEL2_END}"
	bbwarn "PT_ROOTFS2_END=${PT_ROOTFS2_END}"


	# Determine size for extended partition
	PT_EXTENDED_SIZE_ALIGNED=$(expr 8 \* ${PARTITION_ALIGNMENT} + ${PT_RECOVERY_SIZE_ALIGNED} + ${PT_UBENV_SIZE} + 2 \* ${PT_KERNEL_SIZE_ALIGNED} + 2 \* ${PT_ROOTFS_SIZE_ALIGNED} + ${PT_DATA_SIZE_ALIGNED} )
	PT_EXTENDED_END=$(expr ${PT_EXTENDED_START} + ${PT_EXTENDED_SIZE_ALIGNED} )
	echo "Extended partition size=${PT_EXTENDED_SIZE_ALIGNED} end=${PT_EXTENDED_END}"

	# Obtain card image size 		
	SDIMG_SIZE=$(expr ${PT_EXTENDED_END} + ${PARTITION_ALIGNMENT})

	echo "Creating SD card image of ${SDIMG_SIZE} KiB with a boot partition of ${PT_BOOT_SIZE_ALIGNED} KiB and a rootfs of ${PT_ROOTFS_SIZE_ALIGNED} KiB"

    # Check if we are building with device tree support
    DTS="${KERNEL_DEVICETREE}"

    # Initialize sdcard image file
    dd if=/dev/zero of=${SDIMG} bs=1024 count=0 seek=${SDIMG_SIZE}

    # Creat partition table
    parted -s ${SDIMG} mklabel msdos

    # Create boot partition and mark it as bootable
    parted -s ${SDIMG} unit KiB mkpart primary fat32  ${PT_BOOT_START} ${PT_BOOT_END}  
    parted -s ${SDIMG} set 1 boot on

    # Create partition for u-boot main environment
    parted -s ${SDIMG} unit KiB mkpart primary ${PT_UBENV1_START} ${PT_UBENV1_END} 	
    # Create extended partition
    parted -s ${SDIMG} unit KiB mkpart extended ${PT_EXTENDED_START} ${PT_EXTENDED_END}
    # Create recovery partition
    parted -s ${SDIMG} unit KiB mkpart logical ext2 ${PT_RECOVERY_START} ${PT_RECOVERY_END}
    # Create partition for u-boot redundant environment
    parted -s ${SDIMG} unit KiB mkpart logical ${PT_UBENV2_START} ${PT_UBENV2_END} 	
    # Create kernel 1 logical partition
    parted -s ${SDIMG} unit KiB mkpart logical ext2 ${PT_KERNEL1_START} ${PT_KERNEL1_END}  
    # Create rootfs 1 logical partition
    parted -s ${SDIMG} unit KiB mkpart logical ext2 ${PT_ROOTFS1_START} ${PT_ROOTFS1_END}   	
    # Create kernel 2 logical partition
    parted -s ${SDIMG} unit KiB mkpart logical ext2 ${PT_KERNEL2_START} ${PT_KERNEL2_END}
    # Create rootfs 2 logical partition
    parted -s ${SDIMG} unit KiB mkpart logical ext2 ${PT_ROOTFS2_START} ${PT_ROOTFS2_END} 	
    # Create data logical partition
    parted -s ${SDIMG} unit KiB mkpart logical ext2 ${PT_DATA_START} ${PT_DATA_END} 	

    # Print partition table	
    printf %s\\n 'unit KiB print' | parted  ${SDIMG} 


    # Create a vfat image with boot files
    BOOT_BLOCKS=$(LC_ALL=C parted -s ${SDIMG} unit b print | awk '/ 1 / { print substr($4, 1, length($4 -1)) / 512 /2 }')
    rm -f ${WORKDIR}/boot.img
    mkfs.vfat -F32 -n "${BOOTDD_VOLUME_ID}" -S 512 -C ${WORKDIR}/boot.img $BOOT_BLOCKS
    mcopy -v -i ${WORKDIR}/boot.img -s ${DEPLOY_DIR_IMAGE}/${BOOTFILES_DIR_NAME}/* ::/ || bbfatal "mcopy cannot copy ${DEPLOY_DIR_IMAGE}/${BOOTFILES_DIR_NAME}/* into boot.img"
    if [ "${@bb.utils.contains("MACHINE_FEATURES", "armstub", "1", "0", d)}" = "1" ]; then
        mcopy -v -i ${WORKDIR}/boot.img -s ${DEPLOY_DIR_IMAGE}/armstubs/${ARMSTUB} ::/ || bbfatal "mcopy cannot copy ${DEPLOY_DIR_IMAGE}/armstubs/${ARMSTUB} into boot.img"
    fi
    if test -n "${DTS}"; then
        # Copy board device trees to root folder
        for dtbf in ${@split_overlays(d, True)}; do
            dtb=`basename $dtbf`
            mcopy -v -i ${WORKDIR}/boot.img -s ${DEPLOY_DIR_IMAGE}/$dtb ::$dtb || bbfatal "mcopy cannot copy ${DEPLOY_DIR_IMAGE}/$dtb into boot.img"
        done

        # Copy device tree overlays to dedicated folder
        mmd -i ${WORKDIR}/boot.img overlays
        for dtbf in ${@split_overlays(d, False)}; do
            dtb=`basename $dtbf`
            mcopy -v -i ${WORKDIR}/boot.img -s ${DEPLOY_DIR_IMAGE}/$dtb ::overlays/$dtb || bbfatal "mcopy cannot copy ${DEPLOY_DIR_IMAGE}/$dtb into boot.img"
        done
    fi
    if [ "${RPI_USE_U_BOOT}" = "1" ]; then
        mcopy -v -i ${WORKDIR}/boot.img -s ${DEPLOY_DIR_IMAGE}/u-boot.bin ::${SDIMG_KERNELIMAGE} || bbfatal "mcopy cannot copy ${DEPLOY_DIR_IMAGE}/u-boot.bin into boot.img"
        mcopy -v -i ${WORKDIR}/boot.img -s ${DEPLOY_DIR_IMAGE}/boot.scr ::boot.scr || bbfatal "mcopy cannot copy ${DEPLOY_DIR_IMAGE}/boot.scr into boot.img"
        if [ ! -z "${INITRAMFS_IMAGE}" -a "${INITRAMFS_IMAGE_BUNDLE}" = "1" ]; then
            mcopy -v -i ${WORKDIR}/boot.img -s ${DEPLOY_DIR_IMAGE}/${KERNEL_IMAGETYPE}-${INITRAMFS_LINK_NAME}.bin ::${KERNEL_IMAGETYPE} || bbfatal "mcopy cannot copy ${DEPLOY_DIR_IMAGE}/${KERNEL_IMAGETYPE}-${INITRAMFS_LINK_NAME}.bin into boot.img"
        else
            mcopy -v -i ${WORKDIR}/boot.img -s ${DEPLOY_DIR_IMAGE}/${KERNEL_IMAGETYPE} ::${KERNEL_IMAGETYPE} || bbfatal "mcopy cannot copy ${DEPLOY_DIR_IMAGE}/${KERNEL_IMAGETYPE} into boot.img"
        fi
    else
        if [ ! -z "${INITRAMFS_IMAGE}" -a "${INITRAMFS_IMAGE_BUNDLE}" = "1" ]; then
            mcopy -v -i ${WORKDIR}/boot.img -s ${DEPLOY_DIR_IMAGE}/${KERNEL_IMAGETYPE}-${INITRAMFS_LINK_NAME}.bin ::${SDIMG_KERNELIMAGE} || bbfatal "mcopy cannot copy ${DEPLOY_DIR_IMAGE}/${KERNEL_IMAGETYPE}-${INITRAMFS_LINK_NAME}.bin into boot.img"
        else
            mcopy -v -i ${WORKDIR}/boot.img -s ${DEPLOY_DIR_IMAGE}/${KERNEL_IMAGETYPE} ::${SDIMG_KERNELIMAGE} || bbfatal "mcopy cannot copy ${DEPLOY_DIR_IMAGE}/${KERNEL_IMAGETYPE} into boot.img"
        fi
    fi

    # Add files (eg. hypervisor binaries) from the deploy dir
    if [ -n "${DEPLOYPAYLOAD}" ] ; then
        echo "Copying deploy file payload into VFAT"
        for entry in ${DEPLOYPAYLOAD} ; do
            # Split entry at optional ':' to enable file renaming for the destination
            if [ $(echo "$entry" | grep -c :) = "0" ] ; then
                DEPLOY_FILE="$entry"
                DEST_FILENAME="$entry"
            else
                DEPLOY_FILE="$(echo "$entry" | cut -f1 -d:)"
                DEST_FILENAME="$(echo "$entry" | cut -f2- -d:)"
            fi
            mcopy -v -i ${WORKDIR}/boot.img -s ${DEPLOY_DIR_IMAGE}/${DEPLOY_FILE} ::${DEST_FILENAME} || bbfatal "mcopy cannot copy ${DEPLOY_DIR_IMAGE}/${DEPLOY_FILE} into boot.img"
        done
    fi

    if [ -n "${FATPAYLOAD}" ] ; then
        echo "Copying payload into VFAT"
        for entry in ${FATPAYLOAD} ; do
            # use bbwarn instead of bbfatal to stop aborting on vfat issues like not supporting .~lock files
            mcopy -v -i ${WORKDIR}/boot.img -s ${IMAGE_ROOTFS}$entry :: || bbwarn "mcopy cannot copy ${IMAGE_ROOTFS}$entry into boot.img"
        done
    fi

    # Add stamp file
    echo "${IMAGE_NAME}" > ${WORKDIR}/image-version-info
    mcopy -v -i ${WORKDIR}/boot.img ${WORKDIR}/image-version-info :: || bbfatal "mcopy cannot copy ${WORKDIR}/image-version-info into boot.img"

    # Deploy vfat partition
    if [ "${SDIMG_VFAT_DEPLOY}" = "1" ]; then
        cp ${WORKDIR}/boot.img ${IMGDEPLOYDIR}/${SDIMG_VFAT}
        ln -sf ${SDIMG_VFAT} ${SDIMG_LINK_VFAT}
    fi

    # Burn Partitions ( Just duplicate ) 
    dd if=${WORKDIR}/boot.img of=${SDIMG} conv=notrunc seek=1 bs=$(expr ${PT_BOOT_START}    \* 1024)
    dd if=${WORKDIR}/boot.img of=${SDIMG} conv=notrunc seek=1 bs=$(expr ${PT_KERNEL1_START} \* 1024)
    dd if=${WORKDIR}/boot.img of=${SDIMG} conv=notrunc seek=1 bs=$(expr ${PT_KERNEL2_START} \* 1024)
    # If SDIMG_ROOTFS_TYPE is a .xz file use xzcat
    # Make both root partitions identical when creating a complete SD card
    if echo "${SDIMG_ROOTFS_TYPE}" | egrep -q "*\.xz"
    then
        xzcat ${SDIMG_ROOTFS} | dd if=${SDIMG_ROOTFS} of=${SDIMG} conv=notrunc seek=1 bs=$(expr ${PT_ROOTFS1_START} \* 1024)
        xzcat ${SDIMG_ROOTFS} | dd if=${SDIMG_ROOTFS} of=${SDIMG} conv=notrunc seek=1 bs=$(expr ${PT_ROOTFS1_START} \* 1024)
    else
        dd if=${SDIMG_ROOTFS} of=${SDIMG} conv=notrunc seek=1 bs=$(expr ${PT_ROOTFS1_START} \* 1024)
        dd if=${SDIMG_ROOTFS} of=${SDIMG} conv=notrunc seek=1 bs=$(expr ${PT_ROOTFS2_START} \* 1024)
    fi
}

ROOTFS_POSTPROCESS_COMMAND += " rpi_generate_sysctl_config ; "

rpi_generate_sysctl_config() {
    # systemd sysctl config
    test -d ${IMAGE_ROOTFS}${sysconfdir}/sysctl.d && \
        echo "vm.min_free_kbytes = 8192" > ${IMAGE_ROOTFS}${sysconfdir}/sysctl.d/rpi-vm.conf

    # sysv sysctl config
    IMAGE_SYSCTL_CONF="${IMAGE_ROOTFS}${sysconfdir}/sysctl.conf"
    test -e ${IMAGE_ROOTFS}${sysconfdir}/sysctl.conf && \
        sed -e "/vm.min_free_kbytes/d" -i ${IMAGE_SYSCTL_CONF}
    echo "" >> ${IMAGE_SYSCTL_CONF} && echo "vm.min_free_kbytes = 8192" >> ${IMAGE_SYSCTL_CONF}
}
