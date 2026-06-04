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
# Create include/hdf as a REAL directory (not symlink) so we can copy headers into it
rm -rf include/hdf
mkdir -p include/hdf

# Copy ALL headers from framework/include
echo "=== Collecting ALL HDF headers into include/hdf/ ==="
cp -rv "$HDF_CORE/framework/include/"* include/hdf/ 2>/dev/null || true

# Copy from interfaces/inner_api/*
for subdir in utils core; do
  src="$HDF_CORE/interfaces/inner_api/$subdir"
  if [ -d "$src" ]; then
    mkdir -p "include/hdf/$subdir"
    cp -v "$src"/*.h "include/hdf/$subdir/" 2>/dev/null || true
  fi
done
# osal/shared → include/hdf/osal
mkdir -p include/hdf/osal
cp -v "$HDF_CORE/interfaces/inner_api/osal/shared/"*.h include/hdf/osal/ 2>/dev/null || true

# From adapter osal/include
cp -v "$HDF_ADAPTER/osal/include/"*.h include/hdf/osal/ 2>/dev/null || true

# From adapter include
if [ -d "$HDF_ADAPTER/include" ]; then
  cp -rv "$HDF_ADAPTER/include/"* include/hdf/ 2>/dev/null || true
fi

# From adapter utils
find "$HDF_ADAPTER/utils" -name "*.h" -exec cp -v {} include/hdf/utils/ \; 2>/dev/null || true

# From framework/core/common/include
if [ -d "$HDF_CORE/framework/core/common/include" ]; then
  cp -rv "$HDF_CORE/framework/core/common/include/"* include/hdf/ 2>/dev/null || true
fi

# From framework/model/input (HID)
find "$HDF_CORE/framework/model" -name "*.h" -exec cp -v {} include/hdf/ \; 2>/dev/null || true

# From adapter network
find "$HDF_ADAPTER/network" -name "*.h" -exec cp -v {} include/hdf/ \; 2>/dev/null || true

# Copy bounds_checking_function headers (securec.h)
if [ -n "$BOUNDS_CHECK" ] && [ -d "$BOUNDS_CHECK/include" ]; then
  mkdir -p include/hdf/securec
  cp -v "$BOUNDS_CHECK/include/"*.h include/hdf/securec/ 2>/dev/null || true
  echo "Copied bounds_checking headers"
fi
# Verify key headers exist
echo "=== Header verification ==="
for h in hdf_base.h osal_mem.h hdf_log.h hdf_types.h; do
  found=$(find include/hdf -name "$h" 2>/dev/null | head -1)
  if [ -n "$found" ]; then
    echo "  $h: $found ✓"
  else
    echo "  $h: NOT FOUND ✗"
  fi
done
echo "Total headers: $(find include/hdf -name '*.h' | wc -l)"

# 4. Create drivers/hdf/Makefile (after symlinks, so it won't be deleted)
echo "=== Creating drivers/hdf/Makefile ==="
cat > drivers/hdf/Makefile << 'MKF'
export PROJECT_ROOT := ../../../../../
export PRODUCT_PATH := vendor/x86_64/pc
obj-$(CONFIG_DRIVERS_HDF) += khdf/
MKF

# Create HDF config in MULTIPLE possible locations
# The Makefile uses abspath which resolves relative to the runner home dir
# Try both kernel-relative and absolute paths
for HCS_BASE in \
  "$KERNEL_DIR/vendor/x86_64/pc/hdf_config" \
  "/home/runner/vendor/x86_64/pc/hdf_config" \
  "$HOME/vendor/x86_64/pc/hdf_config"; do
  mkdir -p "$HCS_BASE/khdf"
  cat > "$HCS_BASE/khdf/pc.hcs" << 'HCS'
root {
    device_info {
        match_attr = "linux_device";
    }
}
HCS
  echo "Created HDF config at: $HCS_BASE/khdf"
done

# Also fix the Makefile syntax bug (unterminated abspath on line 32)
# Replace the buggy error block with a simpler one
ADAPTER_MAKEFILE="$HDF_ADAPTER/Makefile"
if grep -q 'HCS_ABS_DIR := $(abspath' "$ADAPTER_MAKEFILE"; then
  echo "Fixing Makefile syntax bug..."
  sed -i 's|HCS_ABS_DIR := $(abspath $(CURRENT_DIR)/$(HCS_DIR)|HCS_ABS_DIR := $(abspath $(CURRENT_DIR)/$(HCS_DIR))|' "$ADAPTER_MAKEFILE"
fi

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
