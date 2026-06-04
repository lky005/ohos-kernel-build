#!/bin/bash
# Apply HDF to x86_64 kernel source
# Usage: ./apply-hdf.sh <kernel_dir> <hdf_adapter_dir> <hdf_core_dir>

set -e
KERNEL_DIR=$1
HDF_ADAPTER=$2
HDF_CORE=$3

cd "$KERNEL_DIR"

# 1. Download and apply hdf.patch (x86-adapted)
echo "=== Downloading hdf.patch ==="
curl -sL "https://raw.githubusercontent.com/openharmony/kernel_linux_patches/main/linux-6.6/common_patch/hdf.patch" -o /tmp/hdf.patch
echo "Patch size: $(wc -l < /tmp/hdf.patch) lines"

# Fix patch paths for x86
sed -i 's|arch/arm64/kernel/vmlinux.lds.S|arch/x86/kernel/vmlinux.lds.S|g' /tmp/hdf.patch

# Apply patch (allow partial failures)
echo "=== Applying HDF patch ==="
patch -p1 < /tmp/hdf.patch || true

# 2. Create symlinks (same as patch_hdf.sh)
echo "=== Creating symlinks ==="
mkdir -p drivers/hdf
ln -sf "../../$HDF_ADAPTER" drivers/hdf/khdf
ln -sf "../../$HDF_CORE/framework" drivers/hdf/framework
ln -sf "../../$HDF_CORE/framework/include" include/hdf

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
print('OK: HDF section added')
"
else
    echo "HDF section already present or linker script not found"
fi

# 4. Verify
echo "=== Verification ==="
ls -la drivers/hdf/khdf/ | head -3
ls -la drivers/hdf/framework/ | head -3
ls -la include/hdf/ | head -3
echo "=== Done ==="
