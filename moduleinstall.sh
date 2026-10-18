#!/system/bin/sh
# ==============================================================================
# Android Kernel Module Manager: Load, Unload, and Inspect
# ==============================================================================

MODULE_DIR="${1:-/data/local/tmp/modules}"
ACTION="${2:-load}"

usage() {
    echo "Usage: $0 <path_to_modules_dir> [load|unload|reload|status]"
    echo "Example: $0 /data/local/tmp/modules load"
    exit 1
}

if [ -z "$1" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "[-] Error: Root privileges required. Run via 'su'."
    exit 1
fi

if [ ! -d "${MODULE_DIR}" ]; then
    echo "[-] Error: Directory ${MODULE_DIR} not found."
    exit 1
fi

# ==========================================
# Module Management Functions
# ==========================================
load_modules() {
    echo "[+] Loading kernel modules from ${MODULE_DIR}..."
    
    # If a custom load order file exists, use it; otherwise iterate alphabetically
    if [ -f "${MODULE_DIR}/modules.load" ]; then
        MODULE_LIST=$(cat "${MODULE_DIR}/modules.load")
    else
        MODULE_LIST=$(ls "${MODULE_DIR}"/*.ko 2>/dev/null)
    fi

    for mod in ${MODULE_LIST}; do
        mod_path="${mod}"
        # Handle relative names from modules.load
        [ ! -f "${mod_path}" ] && mod_path="${MODULE_DIR}/${mod}"

        if [ -f "${mod_path}" ]; then
            mod_name=$(basename "${mod_path}" .ko)
            if lsmod | grep -q "^${mod_name} "; then
                echo "[=] Module already loaded: ${mod_name}"
            else
                echo "[+] Inserting: ${mod_name}"
                # -f forces load even if kernel version magic mismatches
                insmod "${mod_path}" 2>/dev/null || insmod -f "${mod_path}"
                if [ $? -eq 0 ]; then
                    echo "    [OK] ${mod_name} loaded."
                else
                    echo "    [!] Failed to load: ${mod_name} (check dmesg)"
                fi
            fi
        fi
    done
}

unload_modules() {
    echo "[+] Unloading kernel modules from ${MODULE_DIR} (reverse order)..."

    # Reverse list for safe dependency teardown
    if [ -f "${MODULE_DIR}/modules.load" ]; then
        MODULE_LIST=$(tail -r "${MODULE_DIR}/modules.load" 2>/dev/null || tac "${MODULE_DIR}/modules.load" 2>/dev/null || sed '1!G;h;$!d' "${MODULE_DIR}/modules.load")
    else
        MODULE_LIST=$(ls -r "${MODULE_DIR}"/*.ko 2>/dev/null)
    fi

    for mod in ${MODULE_LIST}; do
        mod_name=$(basename "${mod}" .ko)
        if lsmod | grep -q "^${mod_name} "; then
            echo "[-] Removing: ${mod_name}"
            # -f forces removal even if marked in-use (requires CONFIG_MODULE_FORCE_UNLOAD)
            rmmod -f "${mod_name}" 2>/dev/null || rmmod "${mod_name}"
            if [ $? -eq 0 ]; then
                echo "    [OK] ${mod_name} removed."
            else
                echo "    [!] Failed to remove: ${mod_name} (module may be busy/locked)"
            fi
        else
            echo "[=] Module not loaded: ${mod_name}"
        fi
    done
}

status_modules() {
    echo "================ Loaded Modules ================"
    for mod in "${MODULE_DIR}"/*.ko; do
        if [ -f "${mod}" ]; then
            mod_name=$(basename "${mod}" .ko)
            if lsmod | grep -q "^${mod_name} "; then
                echo "[LOADED]   ${mod_name}"
            else
                echo "[UNLOADED] ${mod_name}"
            fi
        fi
    done
    echo "================================================"
}

# ==========================================
# Dispatcher
# ==========================================
case "${ACTION}" in
    load)
        load_modules
        ;;
    unload)
        unload_modules
        ;;
    reload)
        unload_modules
        load_modules
        ;;
    status)
        status_modules
        ;;
    *)
        usage
        ;;
esac
