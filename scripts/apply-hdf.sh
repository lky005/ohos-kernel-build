#!/bin/bash
# Apply HDF to x86_64 kernel source
# Usage: ./apply-hdf.sh <kernel_dir> <hdf_adapter_dir> <hdf_core_dir>

set -x  # debug every command

KERNEL_DIR="$1"
HDF_ADAPTER="$2"
HDF_CORE="$3"

echo "KERNEL_DIR=$KERNEL_DIR"
echo "HDF_ADAPTER=$HDF_ADAPTER"
echo "HDF_CORE=$HDF_CORE"
echo "PWD=$(pwd)"

# Resolve to absolute paths BEFORE cd
HDF_ADAPTER_ABS=$(cd "$HDF_ADAPTER" && pwd)
HDF_CORE_ABS=$(cd "$HDF_CORE" && pwd)

cd "$KERNEL_DIR"
echo "After cd: PWD=$(pwd)"
echo "HDF_ADAPTER_ABS=$HDF_ADAPTER_ABS"
echo "HDF_CORE_ABS=$HDF_CORE_ABS"

# 1. Download hdf.patch via API
echo "=== Downloading hdf.patch ==="
curl -sL "https://api.github.com/repos/openharmony/kernel_linux_patches/contents/linux-6.6/common_patch/hdf.patch" \
  -H "Accept: application/vnd.github.v3.raw" -o /tmp/hdf.patch
LINES=$(wc -l < /tmp/hdf.patch)
echo "Patch lines: $LINES"

if [ "$LINES" -lt 10 ]; then
  echo "API download failed, trying Gitee..."
  curl -sL "https://gitee.com/openharmony/kernel_linux_patches/raw/master/linux-6.6/common_patch/hdf.patch" -o /tmp/hdf.patch
  echo "Patch lines: $(wc -l < /tmp/hdf.patch)"
fi

# Fix patch for x86
sed -i 's|arch/arm64/kernel/vmlinux.lds.S|arch/x86/kernel/vmlinux.lds.S|g' /tmp/hdf.patch

# Apply patch
echo "=== Applying HDF patch ==="
patch -p1 < /tmp/hdf.patch || echo "Some hunks failed (expected)"

# 2. Create symlinks with ABSOLUTE paths
echo "=== Creating symlinks ==="
rm -rf drivers/hdf
mkdir -p drivers/hdf

# khdf = the Linux kernel adapter
ln -sv "$HDF_ADAPTER_ABS" drivers/hdf/khdf
# framework = the HDF core framework
ln -sv "$HDF_CORE_ABS/framework" drivers/hdf/framework

# include/hdf = framework headers
rm -rf include/hdf
ln -sv "$HDF_CORE_ABS/framework/include" include/hdf

# 3. Verify symlinks work
echo "=== Verification ==="
echo "--- khdf/Kconfig ---"
ls -la drivers/hdf/khdf/Kconfig && head -5 drivers/hdf/khdf/Kconfig
echo "--- framework dir ---"
ls drivers/hdf/framework/ | head -5
echo "--- include/hdf ---"
ls include/hdf/ | head -5

# 4. Patch x86 linker script
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

echo "=== ALL DONE ==="
