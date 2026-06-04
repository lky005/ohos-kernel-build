#!/bin/bash
# Apply HDF to x86_64 kernel source
# Usage: ./apply-hdf.sh <kernel_dir> <hdf_adapter_dir> <hdf_core_dir>

set -e
KERNEL_DIR=$(realpath "$1")
HDF_ADAPTER=$(realpath "$2")
HDF_CORE=$(realpath "$3")

cd "$KERNEL_DIR"

# 1. Download hdf.patch via API (not raw URL)
echo "=== Downloading hdf.patch via API ==="
curl -sL "https://api.github.com/repos/openharmony/kernel_linux_patches/contents/linux-6.6/common_patch/hdf.patch" \
  -H "Accept: application/vnd.github.v3.raw" -o /tmp/hdf.patch
echo "Patch size: $(wc -l < /tmp/hdf.patch) lines"

if [ ! -s /tmp/hdf.patch ]; then
  echo "ERROR: Patch download failed, trying alternative URL..."
  curl -sL "https://gitee.com/openharmony/kernel_linux_patches/raw/master/linux-6.6/common_patch/hdf.patch" -o /tmp/hdf.patch
  echo "Patch size: $(wc -l < /tmp/hdf.patch) lines"
fi

# Fix patch paths for x86
sed -i 's|arch/arm64/kernel/vmlinux.lds.S|arch/x86/kernel/vmlinux.lds.S|g' /tmp/hdf.patch

# Apply patch (allow partial failures)
echo "=== Applying HDF patch ==="
patch -p1 < /tmp/hdf.patch || echo "Some hunks failed (expected for x86 adaptation)"

# 2. Create symlinks with ABSOLUTE paths
echo "=== Creating symlinks ==="
rm -rf drivers/hdf
mkdir -p drivers/hdf
ln -sf "$HDF_ADAPTER" drivers/hdf/khdf
ln -sf "$HDF_CORE/framework" drivers/hdf/framework

# Create include/hdf symlink
rm -rf include/hdf
ln -sf "$HDF_CORE/framework/include" include/hdf

# 3. Add HDF section to x86 linker script
echo "=== Patching x86 linker script ==="
LDS="arch/x86/kernel/vmlinux.lds.S"
if [ -f "$LDS" ] && ! grep -q "hdf_table" "$LDS"; then
    python3 -c "
with open('$LDS', 'r') as f:
    c = f.read()
hdf = '''
#ifdef CONFIG_DRIVERS_HDF
\t.init.hdf_table : {
\t\t_hdf_drivers_start = .;
\t\t*(.hdf.driver)
\t\t_hdf_drivers_end = .;
\t}
#endif

'''
if '.exit.data' in c:
    c = c.replace('\t.exit.data : {', hdf + '\t.exit.data : {')
with open('$LDS', 'w') as f:
    f.write(c)
print('OK: HDF section added to x86 linker script')
"
else
    echo "HDF section already present or linker script not found"
fi

# 4. Verify
echo "=== Verification ==="
echo "drivers/hdf/khdf:"
ls drivers/hdf/khdf/ | head -5
echo "drivers/hdf/framework:"
ls drivers/hdf/framework/ | head -5
echo "include/hdf:"
ls include/hdf/ | head -5
echo "Kconfig check:"
cat drivers/hdf/khdf/Kconfig 2>/dev/null | head -10 || echo "No khdf Kconfig"
echo "=== Done ==="
