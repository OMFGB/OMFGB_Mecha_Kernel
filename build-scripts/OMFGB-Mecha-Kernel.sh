#!/bin/sh
T=$PWD
PRODUCT=OMFGB-Mecha-Kernel
PRODUCT_CONFIG_FILE=omfgb_mecha_defconfig
RAMDISK_FILES=ramdisk
MKRAMDISK=$T/tools/update-zip-tools/mkbootfs
MKBOOTIMG=$T/tools/update-zip-tools/mkbootimg
VERSION=1.0
DATE=$(date +%Y-%m-%d_%H":"%M)

# Setup omfgb-defconfigs and build zImage

echo "===== Cleaning kernel build directories ======"
make ARCH=arm clean
echo "===== Setting up $PRODUCT defconfig ======"
make ARCH=arm defconfig $PRODUCT_CONFIG_FILE
echo "===== Starting the build ====="
make ARCH=arm -j`grep 'processor' /proc/cpuinfo | wc -l`

# Check to see if zImage is available, if not the build has failed, exit 
# the script and do not continue packaging.

    if [ -f "$T/arch/arm/boot/zImage" ];
    then
        echo "zImage found, continuing to packaging"
    else
        echo "zImage not found, exiting now. Fix your shit"
        exit 0
    fi

# Create working directories for packaging

mkdir -p $T/out/$PRODUCT
mkdir -p $T/out/$PRODUCT/kernel
mkdir -p $T/out/$PRODUCT/system/lib/modules
mkdir -p $T/out/$PRODUCT/META-INF/com/google/android

# Move zImage and modules to the respective out directory for packaging

echo "====== Moving zImage and modules ======"
mv $T/arch/arm/boot/zImage $T/out/$PRODUCT/kernel/zImage
mv $T/drivers/net/wireless/bcm4329/bcm4329.ko $T/out/$PRODUCT/system/lib/modules/bcm4329.ko

# Move update-zip-tools into the out directory for packaging

echo "====== Preparing update-zip-tools ======"
cp -R $T/tools/update-zip-tools/update-binary $T/out/$PRODUCT/META-INF/com/google/android/update-binary
cp -R $T/tools/update-zip-tools/updater-script $T/out/$PRODUCT/META-INF/com/google/android/updater-script
cp -R $T/tools/update-zip-tools/flash_image $T/out/$PRODUCT/flash_image

# make the boot.img for final update.zip

echo "====== Packing boot.img ======"
$MKRAMDISK $T/tools/$RAMDISK_FILES | gzip > $T/out/$PRODUCT/boot.img-ramdisk.cpio.gz
$MKBOOTIMG --kernel $T/out/$PRODUCT/kernel/zImage --ramdisk $T/out/$PRODUCT/boot.img-ramdisk.cpio.gz --cmdline no_console_suspend=1 --base 0x05200000 --pagesize 4096 -o $T/out/$PRODUCT/boot.img

# Create the update.zip with all files from out directory

echo "====== Creating update.zip package ======"
cd $T/out/$PRODUCT
zip -r $PRODUCT-$VERSION-$DATE.zip META-INF/ system/ boot.img flash_image
OUTPUT_ZIP=$PRODUCT-$VERSION-$DATE
cd $T
echo "====== Raw files are now in /out for the $PRODUCT ====="
echo "====== Signing... ======"
java -jar $T/tools/update-zip-tools/signapk.jar $T/tools/update-zip-tools/testkey.x509.pem $T/tools/update-zip-tools/testkey.pk8 $T/out/$PRODUCT/$OUTPUT_ZIP.zip $T/out/$PRODUCT/$OUTPUT_ZIP-signed.zip
rm $T/out/$PRODUCT/$OUTPUT_ZIP.zip
echo "====== Done with $PRODUCT.. ======"

