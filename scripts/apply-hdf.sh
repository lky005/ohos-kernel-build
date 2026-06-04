#!/bin/bash
# Apply HDF to x86_64 kernel source
# Usage: ./apply-hdf.sh <kernel_abs_path> <hdf_adapter_abs_path> <hdf_core_abs_path>

set -e

KERNEL_DIR="$1"
HDF_ADAPTER="$2"
HDF_CORE="$3"

[ -d "$KERNEL_DIR" ] || { echo "ERROR: kernel dir not found: $KERNEL_DIR"; exit 1; }
[ -d "$HDF_ADAPTER" ] || { echo "ERROR: hdf_adapter not found: $HDF_ADAPTER"; exit 1; }
[ -d "$HDF_CORE" ] || { echo "ERROR: hdf_core not found: $HDF_CORE"; exit 1; }

cd "$KERNEL_DIR"

# 1. Download hdf.patch
echo "=== Downloading hdf.patch ==="
curl -sL "https://api.github.com/repos/openharmony/kernel_linux_patches/contents/linux-6.6/common_patch/hdf.patch" \
  -H "Accept: application/vnd.github.v3.raw" -o /tmp/hdf.patch
LINES=$(wc -l < /tmp/hdf.patch)
echo "Patch lines: $LINES"
if [ "$LINES" -lt 10 ]; then
  curl -sL "https://gitee.com/openharmony/kernel_linux_patches/raw/master/linux-6.6/common_patch/hdf.patch" -o /tmp/hdf.patch
fi

# Fix for x86
sed -i 's|arch/arm64/kernel/vmlinux.lds.S|arch/x86/kernel/vmlinux.lds.S|g' /tmp/hdf.patch

# 2. Apply patch (for Kconfig/Makefile/hid/usb changes, NOT for drivers/hdf/Makefile)
echo "=== Applying HDF patch ==="
patch -p1 < /tmp/hdf.patch || true

# 3. Create symlinks FIRST (before touching drivers/hdf/)
echo "=== Creating symlinks ==="
rm -rf drivers/hdf
mkdir -p drivers/hdf
ln -sv "$HDF_ADAPTER" drivers/hdf/khdf
ln -sv "$HDF_CORE/framework" drivers/hdf/framework
rm -rf include/hdf
ln -sv "$HDF_CORE/framework/include" include/hdf

# 4. Create drivers/hdf/Makefile (after symlinks, so it won't be deleted)
echo "=== Creating drivers/hdf/Makefile ==="
cat > drivers/hdf/Makefile << 'MKF'
export PROJECT_ROOT := ../../../../../
export PRODUCT_PATH := vendor/x86_64/pc
obj-$(CONFIG_DRIVERS_HDF) += khdf/
MKF

# Create minimal HDF config directory that the adapter expects
mkdir -p vendor/x86_64/pc/hdf_config/khdf
touch vendor/x86_64/pc/hdf_config/khdf/.placeholder

cat drivers/hdf/Makefile

# 5. Patch x86 linker script
echo "=== Patching x86 linker script ==="
LDS="arch/x86/kernel/vmlinux.lds.S"
if [ -f "$LDS" ] && ! grep -q "hdf_table" "$LDS"; then
    python3 << 'PYEOF'
with open("arch/x86/kernel/vmlinux.lds.S", "r") as f:
    c = f.read()
hdf = """
#ifdef CONFIG_DRIVERS_HDF
\t.init.hdf_table : {
\t\t_hdf_drivers_start = .;
\t\t*(.hdf.driver)
\t\t_hdf_drivers_end = .;
\t}
#endif

"""
if ".exit.data" in c:
    c = c.replace("\t.exit.data : {", hdf + "\t.exit.data : {")
with open("arch/x86/kernel/vmlinux.lds.S", "w") as f:
    f.write(c)
print("OK: HDF section added")
PYEOF
fi

# 6. Final verification
echo "=== Final verification ==="
echo "drivers/hdf/:"
ls -la drivers/hdf/
echo "drivers/hdf/Makefile:"
cat drivers/hdf/Makefile
echo "drivers/hdf/khdf/Kconfig:"
head -5 drivers/hdf/khdf/Kconfig 2>/dev/null || echo "NOT FOUND"
echo "drivers/hdf/framework/:"
ls drivers/hdf/framework/ | head -3
echo "include/hdf/:"
ls include/hdf/ | head -3
echo "=== ALL DONE ==="
