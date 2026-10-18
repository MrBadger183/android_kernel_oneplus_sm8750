#!/usr/bin/env bash
# ==============================================================================
# OnePlus 13 (SM8750 / Snapdragon 8 Elite) Kernel Build Script
# Manifest: https://github.com/OnePlusOSS/kernel_manifest (oneplus_13_global.xml)
# ==============================================================================
set -e

# ==========================================
# Directory & Path Configuration
# ==========================================
ROOT_DIR="$(pwd)"
KERNEL_PLATFORM_DIR="${ROOT_DIR}/kernel_platform"
CUSTOM_MODULES_SRC="/home/mr-badger/custom-modules/oneplus13-modules"

OUT_DIR="${ROOT_DIR}/out"
DIST_DIR="${ROOT_DIR}/dist"
MODULES_STAGING_DIR="${OUT_DIR}/modules_staging"

# Manifest Repository
MANIFEST_REPO="https://github.com/OnePlusOSS/kernel_manifest.git"
MANIFEST_BRANCH="oneplus/sm8750"
MANIFEST_FILE="oneplus_13_global.xml"

# ==========================================
# Toolchain & Cross-Compile Setup
# ==========================================
TOOLCHAIN_DIR="${KERNEL_PLATFORM_DIR}/prebuilts/clang/host/linux-x86/clang-r510928"
TOOLCHAIN_BIN="${TOOLCHAIN_DIR}/bin"
export PATH="${TOOLCHAIN_BIN}:${ROOT_DIR}/.bin:${HOME}/.bin:${PATH}"

export ARCH="arm64"
export SUBARCH="arm64"
export LLVM=1
export LLVM_IAS=1
export CC="clang"
export LD="ld.lld"
export AR="llvm-ar"
export NM="llvm-nm"
export OBJCOPY="llvm-objcopy"
export OBJDUMP="llvm-objdump"
export READELF="llvm-readelf"
export STRIP="llvm-strip"
export CROSS_COMPILE="aarch64-linux-gnu-"
export CROSS_COMPILE_COMPAT="arm-linux-gnueabi-"

JOBS="$(nproc --all)"
BUILD_TARGET="${1:-sun}"
BUILD_VARIANT="${2:-perf}"

# ==========================================
# Step 1: Verify Environment & Toolchain
# ==========================================
if [ ! -d "${TOOLCHAIN_BIN}" ]; then
    echo "[-] Error: Toolchain directory ${TOOLCHAIN_BIN} does not exist."
    exit 1
fi

echo "[+] Using Compiler: $(clang --version | head -n 1)"
echo "[+] Using Linker:   $(ld.lld --version | head -n 1)"

# Ensure 'repo' tool is available
if ! command -v repo &> /dev/null; then
    echo "[!] 'repo' tool not found. Downloading repo bootstrap script..."
    mkdir -p "${ROOT_DIR}/.bin"
    curl -s https://storage.googleapis.com/git-repo-downloads/repo > "${ROOT_DIR}/.bin/repo"
    chmod a+rx "${ROOT_DIR}/.bin/repo"
    export PATH="${ROOT_DIR}/.bin:${PATH}"
fi

# ==========================================
# Step 2: Initialize & Sync Kernel Manifest
# ==========================================
if [ ! -d "${ROOT_DIR}/.repo" ]; then
    echo "[+] Initializing repo with manifest: ${MANIFEST_FILE} (${MANIFEST_BRANCH})..."
    repo init -u "${MANIFEST_REPO}" -b "${MANIFEST_BRANCH}" -m "${MANIFEST_FILE}" --depth=1
else
    echo "[+] Found existing .repo directory."
fi

if [ ! -d "${KERNEL_PLATFORM_DIR}/msm-kernel" ] || [ ! -d "${KERNEL_PLATFORM_DIR}/common" ]; then
    echo "[+] Synchronizing repositories (${JOBS} threads)..."
    repo sync -c -j"${JOBS}" --no-tags --no-clone-bundle --force-sync
else
    echo "[+] Repositories already synced."
fi

# Clean output and distribution paths
mkdir -p "${OUT_DIR}" "${DIST_DIR}" "${MODULES_STAGING_DIR}"

# ==========================================
# Step 3: Patch Bazel / Kleaf Toolchain Files
# ==========================================
echo "[+] Configuring Bazel / Kleaf to use custom Neutron Clang toolchain..."

# 1. Configure OPlus modules variant to prevent duplicate Bazel rule definitions
if [ -f "${KERNEL_PLATFORM_DIR}/build/kernel/oplus/oplus_modules_variant.sh" ]; then
    echo "[+] Setting OPlus target variant to ${BUILD_TARGET} ${BUILD_VARIANT}..."
    sh "${KERNEL_PLATFORM_DIR}/build/kernel/oplus/oplus_modules_variant.sh" "${BUILD_TARGET}" "${BUILD_VARIANT}"
fi

# 2. Patch clang_toolchain_repository.bzl to register user clang only for target_os == android (host tools use default clang)
CLANG_REPO_BZL="${KERNEL_PLATFORM_DIR}/prebuilts/clang/host/linux-x86/kleaf/clang_toolchain_repository.bzl"
if [ -f "${CLANG_REPO_BZL}" ]; then
    if ! grep -q "if target_os == \"android\"" "${CLANG_REPO_BZL}"; then
        echo "[+] Patching clang_toolchain_repository.bzl for Android target compiler resolution..."
        sed -i 's/for target_os, target_cpu in SUPPORTED_ARCHITECTURES\]/for target_os, target_cpu in SUPPORTED_ARCHITECTURES if target_os == "android"\]/g' "${CLANG_REPO_BZL}"
    fi
fi

# 3. Patch kernel_toolchains.bzl to allow user clang toolchain version check skip
KERNEL_TOOLCHAINS_BZL="${KERNEL_PLATFORM_DIR}/build/kernel/kleaf/impl/kernel_toolchains.bzl"
if [ -f "${KERNEL_TOOLCHAINS_BZL}" ]; then
    if ! grep -q "kleaf_user_clang_toolchain_skip_version_check" "${KERNEL_TOOLCHAINS_BZL}"; then
        echo "[+] Patching kernel_toolchains.bzl for user toolchain validation..."
        sed -i 's/if target.compiler_version != exec.compiler_version:/if target.compiler_version != exec.compiler_version and target.compiler_version != "kleaf_user_clang_toolchain_skip_version_check":/g' "${KERNEL_TOOLCHAINS_BZL}"
    fi
fi

# ==========================================
# Step 4: Configure Kernel & Force Flags
# ==========================================
echo "[+] Configuring Force Load / Unload options in vendor defconfigs..."
CONFIG_SNIPPET="
CONFIG_MODULE_FORCE_LOAD=y
CONFIG_MODULE_FORCE_UNLOAD=y
"

# Append to sun_perf.config vendor fragment
CONFIG_TARGETS=$(find "${KERNEL_PLATFORM_DIR}/msm-kernel" -name "sun_perf.config" 2>/dev/null || true)
for cfg in ${CONFIG_TARGETS}; do
    if ! grep -q "CONFIG_MODULE_FORCE_LOAD=y" "${cfg}"; then
        echo "[+] Appending force module options to ${cfg}"
        echo "${CONFIG_SNIPPET}" >> "${cfg}"
    fi
done

# ==========================================
# Step 5: Build Kernel & Modules with Bazel
# ==========================================
echo "[+] Building OnePlus 13 Kernel (Target: ${BUILD_TARGET}, Variant: ${BUILD_VARIANT})..."

if [ -f "${KERNEL_PLATFORM_DIR}/build_with_bazel.py" ]; then
    python3 "${KERNEL_PLATFORM_DIR}/build_with_bazel.py" \
        -t "${BUILD_TARGET}" "${BUILD_VARIANT}" \
        -s dtc \
        --out_dir "${DIST_DIR}" \
        --user_clang_toolchain="${TOOLCHAIN_DIR}" \
        --jobs="${JOBS}" || {
            echo "[-] build_with_bazel.py failed. Attempting direct tools/bazel invocation..."
            if [ -x "${KERNEL_PLATFORM_DIR}/tools/bazel" ]; then
                (
                    cd "${KERNEL_PLATFORM_DIR}"
                    ./tools/bazel run \
                        "//msm-kernel:${BUILD_TARGET}_${BUILD_VARIANT}_dist" \
                        --user_clang_toolchain="${TOOLCHAIN_DIR}" \
                        -- --destdir="${DIST_DIR}"
                )
            fi
        }
elif [ -x "${KERNEL_PLATFORM_DIR}/tools/bazel" ]; then
    (
        cd "${KERNEL_PLATFORM_DIR}"
        ./tools/bazel run \
            "//msm-kernel:${BUILD_TARGET}_${BUILD_VARIANT}_dist" \
            --user_clang_toolchain="${TOOLCHAIN_DIR}" \
            -- --destdir="${DIST_DIR}"
    )
else
    echo "[-] Error: Neither build_with_bazel.py nor tools/bazel found in ${KERNEL_PLATFORM_DIR}"
    exit 1
fi

# ==========================================
# Step 6: Build Custom Modules (if provided)
# ==========================================
KERNEL_SRC="${KERNEL_PLATFORM_DIR}/msm-kernel"
MODULE_SYMVERS="${DIST_DIR}/Module.symvers"

if [ -d "${CUSTOM_MODULES_SRC}" ]; then
    echo "[+] Building Custom Modules from: ${CUSTOM_MODULES_SRC}..."

    if [ -f "${CUSTOM_MODULES_SRC}/Makefile" ] || [ -f "${CUSTOM_MODULES_SRC}/Kbuild" ]; then
        make -j"${JOBS}" \
            -C "${KERNEL_SRC}" \
            O="${OUT_DIR}" \
            M="${CUSTOM_MODULES_SRC}" \
            KBUILD_EXTRA_SYMBOLS="${MODULE_SYMVERS}" \
            modules
        
        make -C "${KERNEL_SRC}" \
            O="${OUT_DIR}" \
            M="${CUSTOM_MODULES_SRC}" \
            INSTALL_MOD_PATH="${MODULES_STAGING_DIR}" \
            INSTALL_MOD_STRIP=1 \
            modules_install
    else
        for custom_dir in $(find "${CUSTOM_MODULES_SRC}" -mindepth 1 -maxdepth 2 -name "Makefile" -exec dirname {} \;); do
            echo "[+] Compiling custom module: ${custom_dir}"
            make -j"${JOBS}" \
                -C "${KERNEL_SRC}" \
                O="${OUT_DIR}" \
                M="${custom_dir}" \
                KBUILD_EXTRA_SYMBOLS="${MODULE_SYMVERS}" \
                modules
            
            make -C "${KERNEL_SRC}" \
                O="${OUT_DIR}" \
                M="${custom_dir}" \
                INSTALL_MOD_PATH="${MODULES_STAGING_DIR}" \
                INSTALL_MOD_STRIP=1 \
                modules_install
        done
    fi
else
    echo "[*] Custom modules path ${CUSTOM_MODULES_SRC} not found. Skipping."
fi

# ==========================================
# Step 7: Collect & Organize Artifacts
# ==========================================
echo "[+] Organizing build artifacts in ${DIST_DIR}..."

if [ -d "${DIST_DIR}/dist" ]; then
    cp -rf "${DIST_DIR}/dist/"* "${DIST_DIR}/" 2>/dev/null || true
    rm -rf "${DIST_DIR}/dist"
fi

mkdir -p "${DIST_DIR}/modules"
find "${DIST_DIR}" -maxdepth 1 -name "*.ko" -exec mv {} "${DIST_DIR}/modules/" \; 2>/dev/null || true
find "${MODULES_STAGING_DIR}" -name "*.ko" -exec cp {} "${DIST_DIR}/modules/" \; 2>/dev/null || true
find "${KERNEL_PLATFORM_DIR}/out" -name "*.ko" -exec cp -u {} "${DIST_DIR}/modules/" \; 2>/dev/null || true
find "${ROOT_DIR}/bazel-cache" -name "*.ko" -exec cp -u {} "${DIST_DIR}/modules/" \; 2>/dev/null || true
# if [ -d "${CUSTOM_MODULES_SRC}" ]; then
#     find "${CUSTOM_MODULES_SRC}" -name "*.ko" -exec cp -u {} "${DIST_DIR}/modules/" \; 2>/dev/null || true
# fi

echo "================================================================="
echo "[+] Build Complete!"
echo "[+] Artifacts Stored in: ${DIST_DIR}"
echo "[+] Kernel Images: $(find "${DIST_DIR}" -maxdepth 1 -name "Image*" -printf "%f " 2>/dev/null || true)"
echo "[+] Boot Images:   $(find "${DIST_DIR}" -maxdepth 1 -name "*boot*.img" -printf "%f " 2>/dev/null || true)"
echo "[+] Total Modules: $(find "${DIST_DIR}/modules" -name "*.ko" | wc -l)"
echo "================================================================="
