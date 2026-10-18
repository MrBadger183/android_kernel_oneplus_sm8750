# ==========================================
# Step 3: Configure Kernel & Force Flags
# ==========================================
echo "[+] Generating defconfig: ${DEFCONFIG}..."
make -C "${KERNEL_SRC}" O="${OUT_DIR}" ${DEFCONFIG}

echo "[+] Checking and enabling Force Load & Force Unload options..."

CONFIG_HELPER="${KERNEL_SRC}/scripts/config"

# Enable Force Load and Force Unload in .config
"${CONFIG_HELPER}" --file "${OUT_DIR}/.config" --enable CONFIG_MODULE_FORCE_LOAD
"${CONFIG_HELPER}" --file "${OUT_DIR}/.config" --enable CONFIG_MODULE_FORCE_UNLOAD

# Resolve dependency constraints against the new flags
make -C "${KERNEL_SRC}" O="${OUT_DIR}" olddefconfig

# Verification check
check_config() {
    local opt="$1"
    if grep -q "^${opt}=y" "${OUT_DIR}/.config"; then
        echo "[✓] ${opt} is ENABLED"
    else
        echo "[!] WARNING: ${opt} could not be set. Check Kconfig dependencies."
    fi
}

check_config "CONFIG_MODULE_FORCE_LOAD"
check_config "CONFIG_MODULE_FORCE_UNLOAD"
