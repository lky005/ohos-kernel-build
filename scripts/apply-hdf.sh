#!/bin/bash
set -e

KERNEL_DIR="$1"
HDF_ADAPTER="$2"
HDF_CORE="$3"
BOUNDS_CHECK="${4:-}"

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

sed -i 's|arch/arm64/kernel/vmlinux.lds.S|arch/x86/kernel/vmlinux.lds.S|g' /tmp/hdf.patch

echo "=== Applying HDF patch ==="
patch -p1 < /tmp/hdf.patch || true

if [ ! -f drivers/hdf/Makefile ]; then
  echo "Creating drivers/hdf/Makefile manually..."
  cat > drivers/hdf/Makefile << 'MKF'
export PROJECT_ROOT := ../../../../../
export PRODUCT_PATH := vendor/x86_64/pc
obj-$(CONFIG_DRIVERS_HDF) += khdf/
MKF
fi

# 2. Create symlinks
echo "=== Creating symlinks ==="
rm -rf drivers/hdf
mkdir -p drivers/hdf
ln -sv "$HDF_ADAPTER" drivers/hdf/khdf
ln -sv "$HDF_CORE/framework" drivers/hdf/framework

# 3. Create include/hdf as real directory with ALL headers
rm -rf include/hdf
mkdir -p include/hdf
echo "=== Collecting ALL HDF headers ==="
cp -rv "$HDF_CORE/framework/include/"* include/hdf/ 2>/dev/null || true
for subdir in utils core; do
  src="$HDF_CORE/interfaces/inner_api/$subdir"
  if [ -d "$src" ]; then
    mkdir -p "include/hdf/$subdir"
    cp -v "$src"/*.h "include/hdf/$subdir/" 2>/dev/null || true
  fi
done
mkdir -p include/hdf/osal
cp -v "$HDF_CORE/interfaces/inner_api/osal/shared/"*.h include/hdf/osal/ 2>/dev/null || true
cp -v "$HDF_ADAPTER/osal/include/"*.h include/hdf/osal/ 2>/dev/null || true
if [ -d "$HDF_ADAPTER/include" ]; then
  cp -rv "$HDF_ADAPTER/include/"* include/hdf/ 2>/dev/null || true
fi
find "$HDF_ADAPTER/utils" -name "*.h" -exec cp -v {} include/hdf/utils/ \; 2>/dev/null || true
if [ -d "$HDF_CORE/framework/core/common/include" ]; then
  cp -rv "$HDF_CORE/framework/core/common/include/"* include/hdf/ 2>/dev/null || true
fi
find "$HDF_CORE/framework/model" -name "*.h" -exec cp -v {} include/hdf/ \; 2>/dev/null || true
find "$HDF_ADAPTER/network" -name "*.h" -exec cp -v {} include/hdf/ \; 2>/dev/null || true

# Copy bounds_checking headers
if [ -n "$BOUNDS_CHECK" ] && [ -d "$BOUNDS_CHECK/include" ]; then
  mkdir -p include/hdf/securec
  cp -v "$BOUNDS_CHECK/include/"*.h include/hdf/securec/ 2>/dev/null || true
  echo "Copied bounds_checking headers"
fi

# Verify
echo "=== Header verification ==="
for h in hdf_base.h osal_mem.h securec.h hdf_log.h; do
  found=$(find include/hdf -name "$h" 2>/dev/null | head -1)
  [ -n "$found" ] && echo "  $h: $found OK" || echo "  $h: MISSING"
done
echo "Total: $(find include/hdf -name '*.h' | wc -l) headers"

# 4. Create Makefile (after symlinks)
cat > drivers/hdf/Makefile << 'MKF'
export PROJECT_ROOT := ../../../../../
export PRODUCT_PATH := vendor/x86_64/pc
obj-$(CONFIG_DRIVERS_HDF) += khdf/
MKF

# Create HDF config
for HCS_BASE in "$KERNEL_DIR/vendor/x86_64/pc/hdf_config" "/home/runner/vendor/x86_64/pc/hdf_config"; do
  mkdir -p "$HCS_BASE/khdf"
  cat > "$HCS_BASE/khdf/pc.hcs" << 'HCS'
root { device_info { match_attr = "linux_device"; } }
HCS
done

# Fix adapter Makefile syntax bug
ADAPTER_MAKEFILE="$HDF_ADAPTER/Makefile"
grep -q 'HCS_ABS_DIR := $(abspath' "$ADAPTER_MAKEFILE" 2>/dev/null && \
  sed -i 's|HCS_ABS_DIR := $(abspath $(CURRENT_DIR)/$(HCS_DIR)|HCS_ABS_DIR := $(abspath $(CURRENT_DIR)/$(HCS_DIR))|' "$ADAPTER_MAKEFILE"

# Create bounds_checking_function symlink
if [ -n "$BOUNDS_CHECK" ]; then
  ln -svf "$BOUNDS_CHECK" bounds_checking_function
  echo "Created bounds_checking_function symlink"
fi

# 5. Patch x86 linker script
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
