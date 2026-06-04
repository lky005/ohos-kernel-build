#!/bin/bash
BOUNDS_CHECK="${4:-}"
# Apply HDF to x86_64 kernel source
BOUNDS_CHECK="${4:-}"
# Usage: ./apply-hdf.sh <kernel_abs_path> <hdf_adapter_abs_path> <hdf_core_abs_path>
BOUNDS_CHECK="${4:-}"

BOUNDS_CHECK="${4:-}"
set -e
BOUNDS_CHECK="${4:-}"

BOUNDS_CHECK="${4:-}"
KERNEL_DIR="$1"
BOUNDS_CHECK="${4:-}"
HDF_ADAPTER="$2"
BOUNDS_CHECK="${4:-}"
HDF_CORE="$3"
BOUNDS_CHECK="${4:-}"

BOUNDS_CHECK="${4:-}"
[ -d "$KERNEL_DIR" ] || { echo "ERROR: kernel dir not found: $KERNEL_DIR"; exit 1; }
BOUNDS_CHECK="${4:-}"
[ -d "$HDF_ADAPTER" ] || { echo "ERROR: hdf_adapter not found: $HDF_ADAPTER"; exit 1; }
BOUNDS_CHECK="${4:-}"
[ -d "$HDF_CORE" ] || { echo "ERROR: hdf_core not found: $HDF_CORE"; exit 1; }
BOUNDS_CHECK="${4:-}"

BOUNDS_CHECK="${4:-}"
cd "$KERNEL_DIR"
BOUNDS_CHECK="${4:-}"

BOUNDS_CHECK="${4:-}"
# 1. Download hdf.patch
BOUNDS_CHECK="${4:-}"
echo "=== Downloading hdf.patch ==="
BOUNDS_CHECK="${4:-}"
curl -sL "https://api.github.com/repos/openharmony/kernel_linux_patches/contents/linux-6.6/common_patch/hdf.patch" \
BOUNDS_CHECK="${4:-}"
  -H "Accept: application/vnd.github.v3.raw" -o /tmp/hdf.patch
BOUNDS_CHECK="${4:-}"
LINES=$(wc -l < /tmp/hdf.patch)
BOUNDS_CHECK="${4:-}"
echo "Patch lines: $LINES"
BOUNDS_CHECK="${4:-}"
if [ "$LINES" -lt 10 ]; then
BOUNDS_CHECK="${4:-}"
  curl -sL "https://gitee.com/openharmony/kernel_linux_patches/raw/master/linux-6.6/common_patch/hdf.patch" -o /tmp/hdf.patch
BOUNDS_CHECK="${4:-}"
fi
BOUNDS_CHECK="${4:-}"

BOUNDS_CHECK="${4:-}"
# Fix for x86
BOUNDS_CHECK="${4:-}"
sed -i 's|arch/arm64/kernel/vmlinux.lds.S|arch/x86/kernel/vmlinux.lds.S|g' /tmp/hdf.patch
BOUNDS_CHECK="${4:-}"

BOUNDS_CHECK="${4:-}"
# 2. Apply patch (for Kconfig/Makefile/hid/usb changes, NOT for drivers/hdf/Makefile)
BOUNDS_CHECK="${4:-}"
echo "=== Applying HDF patch ==="
BOUNDS_CHECK="${4:-}"
patch -p1 < /tmp/hdf.patch || true
BOUNDS_CHECK="${4:-}"

BOUNDS_CHECK="${4:-}"
# 3. Create symlinks FIRST (before touching drivers/hdf/)
BOUNDS_CHECK="${4:-}"
echo "=== Creating symlinks ==="
BOUNDS_CHECK="${4:-}"
rm -rf drivers/hdf
BOUNDS_CHECK="${4:-}"
mkdir -p drivers/hdf
BOUNDS_CHECK="${4:-}"
ln -sv "$HDF_ADAPTER" drivers/hdf/khdf
BOUNDS_CHECK="${4:-}"
ln -sv "$HDF_CORE/framework" drivers/hdf/framework
BOUNDS_CHECK="${4:-}"
# Create include/hdf as a REAL directory (not symlink) so we can copy headers into it
BOUNDS_CHECK="${4:-}"
rm -rf include/hdf
BOUNDS_CHECK="${4:-}"
mkdir -p include/hdf
BOUNDS_CHECK="${4:-}"

BOUNDS_CHECK="${4:-}"
# Copy ALL headers from framework/include
BOUNDS_CHECK="${4:-}"
echo "=== Collecting ALL HDF headers into include/hdf/ ==="
BOUNDS_CHECK="${4:-}"
cp -rv "$HDF_CORE/framework/include/"* include/hdf/ 2>/dev/null || true
BOUNDS_CHECK="${4:-}"

BOUNDS_CHECK="${4:-}"
# Copy from interfaces/inner_api/*
BOUNDS_CHECK="${4:-}"
for subdir in utils core; do
BOUNDS_CHECK="${4:-}"
  src="$HDF_CORE/interfaces/inner_api/$subdir"
BOUNDS_CHECK="${4:-}"
  if [ -d "$src" ]; then
BOUNDS_CHECK="${4:-}"
    mkdir -p "include/hdf/$subdir"
BOUNDS_CHECK="${4:-}"
    cp -v "$src"/*.h "include/hdf/$subdir/" 2>/dev/null || true
BOUNDS_CHECK="${4:-}"
  fi
BOUNDS_CHECK="${4:-}"
done
BOUNDS_CHECK="${4:-}"
# osal/shared → include/hdf/osal
BOUNDS_CHECK="${4:-}"
mkdir -p include/hdf/osal
BOUNDS_CHECK="${4:-}"
cp -v "$HDF_CORE/interfaces/inner_api/osal/shared/"*.h include/hdf/osal/ 2>/dev/null || true
BOUNDS_CHECK="${4:-}"

BOUNDS_CHECK="${4:-}"
# From adapter osal/include
BOUNDS_CHECK="${4:-}"
cp -v "$HDF_ADAPTER/osal/include/"*.h include/hdf/osal/ 2>/dev/null || true
BOUNDS_CHECK="${4:-}"

BOUNDS_CHECK="${4:-}"
# From adapter include
BOUNDS_CHECK="${4:-}"
if [ -d "$HDF_ADAPTER/include" ]; then
BOUNDS_CHECK="${4:-}"
  cp -rv "$HDF_ADAPTER/include/"* include/hdf/ 2>/dev/null || true
BOUNDS_CHECK="${4:-}"
fi
BOUNDS_CHECK="${4:-}"

BOUNDS_CHECK="${4:-}"
# From adapter utils
BOUNDS_CHECK="${4:-}"
find "$HDF_ADAPTER/utils" -name "*.h" -exec cp -v {} include/hdf/utils/ \; 2>/dev/null || true
BOUNDS_CHECK="${4:-}"

BOUNDS_CHECK="${4:-}"
# From framework/core/common/include
BOUNDS_CHECK="${4:-}"
if [ -d "$HDF_CORE/framework/core/common/include" ]; then
BOUNDS_CHECK="${4:-}"
  cp -rv "$HDF_CORE/framework/core/common/include/"* include/hdf/ 2>/dev/null || true
BOUNDS_CHECK="${4:-}"
fi
BOUNDS_CHECK="${4:-}"

BOUNDS_CHECK="${4:-}"
# From framework/model/input (HID)
BOUNDS_CHECK="${4:-}"
find "$HDF_CORE/framework/model" -name "*.h" -exec cp -v {} include/hdf/ \; 2>/dev/null || true
BOUNDS_CHECK="${4:-}"

BOUNDS_CHECK="${4:-}"
# From adapter network
BOUNDS_CHECK="${4:-}"
find "$HDF_ADAPTER/network" -name "*.h" -exec cp -v {} include/hdf/ \; 2>/dev/null || true
BOUNDS_CHECK="${4:-}"

BOUNDS_CHECK="${4:-}"
# Copy bounds_checking_function headers (securec.h)
BOUNDS_CHECK="${4:-}"
if [ -n "$BOUNDS_CHECK" ] && [ -d "$BOUNDS_CHECK/include" ]; then
BOUNDS_CHECK="${4:-}"
  mkdir -p include/hdf/securec
BOUNDS_CHECK="${4:-}"
  cp -v "$BOUNDS_CHECK/include/"*.h include/hdf/securec/ 2>/dev/null || true
BOUNDS_CHECK="${4:-}"
  echo "Copied bounds_checking headers"
BOUNDS_CHECK="${4:-}"
fi
BOUNDS_CHECK="${4:-}"
# Verify key headers exist
BOUNDS_CHECK="${4:-}"
echo "=== Header verification ==="
BOUNDS_CHECK="${4:-}"
for h in hdf_base.h osal_mem.h hdf_log.h hdf_types.h; do
BOUNDS_CHECK="${4:-}"
  found=$(find include/hdf -name "$h" 2>/dev/null | head -1)
BOUNDS_CHECK="${4:-}"
  if [ -n "$found" ]; then
BOUNDS_CHECK="${4:-}"
    echo "  $h: $found ✓"
BOUNDS_CHECK="${4:-}"
  else
BOUNDS_CHECK="${4:-}"
    echo "  $h: NOT FOUND ✗"
BOUNDS_CHECK="${4:-}"
  fi
BOUNDS_CHECK="${4:-}"
done
BOUNDS_CHECK="${4:-}"
echo "Total headers: $(find include/hdf -name '*.h' | wc -l)"
BOUNDS_CHECK="${4:-}"

BOUNDS_CHECK="${4:-}"
# 4. Create drivers/hdf/Makefile (after symlinks, so it won't be deleted)
BOUNDS_CHECK="${4:-}"
echo "=== Creating drivers/hdf/Makefile ==="
BOUNDS_CHECK="${4:-}"
cat > drivers/hdf/Makefile << 'MKF'
BOUNDS_CHECK="${4:-}"
export PROJECT_ROOT := ../../../../../
BOUNDS_CHECK="${4:-}"
export PRODUCT_PATH := vendor/x86_64/pc
BOUNDS_CHECK="${4:-}"
obj-$(CONFIG_DRIVERS_HDF) += khdf/
BOUNDS_CHECK="${4:-}"
MKF
BOUNDS_CHECK="${4:-}"

BOUNDS_CHECK="${4:-}"
# Create HDF config in MULTIPLE possible locations
BOUNDS_CHECK="${4:-}"
# The Makefile uses abspath which resolves relative to the runner home dir
BOUNDS_CHECK="${4:-}"
# Try both kernel-relative and absolute paths
BOUNDS_CHECK="${4:-}"
for HCS_BASE in \
BOUNDS_CHECK="${4:-}"
  "$KERNEL_DIR/vendor/x86_64/pc/hdf_config" \
BOUNDS_CHECK="${4:-}"
  "/home/runner/vendor/x86_64/pc/hdf_config" \
BOUNDS_CHECK="${4:-}"
  "$HOME/vendor/x86_64/pc/hdf_config"; do
BOUNDS_CHECK="${4:-}"
  mkdir -p "$HCS_BASE/khdf"
BOUNDS_CHECK="${4:-}"
  cat > "$HCS_BASE/khdf/pc.hcs" << 'HCS'
BOUNDS_CHECK="${4:-}"
root {
BOUNDS_CHECK="${4:-}"
    device_info {
BOUNDS_CHECK="${4:-}"
        match_attr = "linux_device";
BOUNDS_CHECK="${4:-}"
    }
BOUNDS_CHECK="${4:-}"
}
BOUNDS_CHECK="${4:-}"
HCS
BOUNDS_CHECK="${4:-}"
  echo "Created HDF config at: $HCS_BASE/khdf"
BOUNDS_CHECK="${4:-}"
done
BOUNDS_CHECK="${4:-}"

BOUNDS_CHECK="${4:-}"
# Also fix the Makefile syntax bug (unterminated abspath on line 32)
BOUNDS_CHECK="${4:-}"
# Replace the buggy error block with a simpler one
BOUNDS_CHECK="${4:-}"
ADAPTER_MAKEFILE="$HDF_ADAPTER/Makefile"
BOUNDS_CHECK="${4:-}"
if grep -q 'HCS_ABS_DIR := $(abspath' "$ADAPTER_MAKEFILE"; then
BOUNDS_CHECK="${4:-}"
  echo "Fixing Makefile syntax bug..."
BOUNDS_CHECK="${4:-}"
  sed -i 's|HCS_ABS_DIR := $(abspath $(CURRENT_DIR)/$(HCS_DIR)|HCS_ABS_DIR := $(abspath $(CURRENT_DIR)/$(HCS_DIR))|' "$ADAPTER_MAKEFILE"
BOUNDS_CHECK="${4:-}"
fi
BOUNDS_CHECK="${4:-}"

BOUNDS_CHECK="${4:-}"
cat drivers/hdf/Makefile
BOUNDS_CHECK="${4:-}"

BOUNDS_CHECK="${4:-}"
# 5. Patch x86 linker script
BOUNDS_CHECK="${4:-}"
echo "=== Patching x86 linker script ==="
BOUNDS_CHECK="${4:-}"
LDS="arch/x86/kernel/vmlinux.lds.S"
BOUNDS_CHECK="${4:-}"
if [ -f "$LDS" ] && ! grep -q "hdf_table" "$LDS"; then
BOUNDS_CHECK="${4:-}"
    python3 << 'PYEOF'
BOUNDS_CHECK="${4:-}"
with open("arch/x86/kernel/vmlinux.lds.S", "r") as f:
BOUNDS_CHECK="${4:-}"
    c = f.read()
BOUNDS_CHECK="${4:-}"
hdf = """
BOUNDS_CHECK="${4:-}"
#ifdef CONFIG_DRIVERS_HDF
BOUNDS_CHECK="${4:-}"
\t.init.hdf_table : {
BOUNDS_CHECK="${4:-}"
\t\t_hdf_drivers_start = .;
BOUNDS_CHECK="${4:-}"
\t\t*(.hdf.driver)
BOUNDS_CHECK="${4:-}"
\t\t_hdf_drivers_end = .;
BOUNDS_CHECK="${4:-}"
\t}
BOUNDS_CHECK="${4:-}"
#endif
BOUNDS_CHECK="${4:-}"

BOUNDS_CHECK="${4:-}"
"""
BOUNDS_CHECK="${4:-}"
if ".exit.data" in c:
BOUNDS_CHECK="${4:-}"
    c = c.replace("\t.exit.data : {", hdf + "\t.exit.data : {")
BOUNDS_CHECK="${4:-}"
with open("arch/x86/kernel/vmlinux.lds.S", "w") as f:
BOUNDS_CHECK="${4:-}"
    f.write(c)
BOUNDS_CHECK="${4:-}"
print("OK: HDF section added")
BOUNDS_CHECK="${4:-}"
PYEOF
BOUNDS_CHECK="${4:-}"
fi
BOUNDS_CHECK="${4:-}"

BOUNDS_CHECK="${4:-}"
# 6. Final verification
BOUNDS_CHECK="${4:-}"
echo "=== Final verification ==="
BOUNDS_CHECK="${4:-}"
echo "drivers/hdf/:"
BOUNDS_CHECK="${4:-}"
ls -la drivers/hdf/
BOUNDS_CHECK="${4:-}"
echo "drivers/hdf/Makefile:"
BOUNDS_CHECK="${4:-}"
cat drivers/hdf/Makefile
BOUNDS_CHECK="${4:-}"
echo "drivers/hdf/khdf/Kconfig:"
BOUNDS_CHECK="${4:-}"
head -5 drivers/hdf/khdf/Kconfig 2>/dev/null || echo "NOT FOUND"
BOUNDS_CHECK="${4:-}"
echo "drivers/hdf/framework/:"
BOUNDS_CHECK="${4:-}"
ls drivers/hdf/framework/ | head -3
BOUNDS_CHECK="${4:-}"
echo "include/hdf/:"
BOUNDS_CHECK="${4:-}"
ls include/hdf/ | head -3
BOUNDS_CHECK="${4:-}"
# Create bounds_checking_function symlink at kernel root
BOUNDS_CHECK="${4:-}"
if [ -n "$BOUNDS_CHECK" ]; then
BOUNDS_CHECK="${4:-}"
  ln -svf "$BOUNDS_CHECK" bounds_checking_function
BOUNDS_CHECK="${4:-}"
  echo "Created bounds_checking_function symlink"
BOUNDS_CHECK="${4:-}"
fi
BOUNDS_CHECK="${4:-}"
echo "=== ALL DONE ==="
BOUNDS_CHECK="${4:-}"
