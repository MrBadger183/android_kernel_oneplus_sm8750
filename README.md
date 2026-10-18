# BadgerHunter Kernel for OnePlus 13  (SM8750 / Snapdragon 8 Elite)

BadgerHunter is a high-performance, security-auditing, and penetration-testing kernel for the **OnePlus 13** (Codename: `dodge`, Platform: `sm8750` / Qualcomm Snapdragon 8 Elite).

Designed for power users, security researchers, and mobile penetration testers, BadgerHunter brings native **KernelSU-Next**, advanced **SuSFS v2.3.0** stealth isolation, comprehensive **Kali NetHunter** wireless & SDR injection capabilities, and GPU gaming/battery optimizations into a unified, rock-solid kernel build.

---

## 🌟 Key Features

### 🛡️ Root & Stealth Isolation
* **KernelSU-Next (v1.0.5 / 33239)**: Native, in-kernel su management with minimal footprint and maximum app compatibility.
* **SuSFS v2.3.0 (Suspicious File System)**:
  * Complete root hiding and mount namespace unsharing protection.
  * Hides ksu loop devices, unshared mounts, and `kstat` path spoofing.
  * `TIF_PROC_UMOUNTED` protection to hide root traces from aggressive root-detection banking and enterprise apps.
  * Strict compatibility fixes for Linux 6.6+ VFS.

### 📡 Kali NetHunter & Penetration Testing
* **Internal Wi-Fi Packet Injection**: Fully patched Qualcomm FastConnect 7900 (`qcacld-3.0` / peach) supporting native raw packet injection and monitor mode on `wlan0`.
* **External Wi-Fi Drivers**: Comprehensive USB Wi-Fi dongle support with mac80211 monitor mode & packet injection:
  * Realtek: RTL8812AU, RTL8821CU, RTL8822BU, RTL8822CU, RTL8187, RTL8xxxu
  * MediaTek: MT7601U, MT7615, MT7663U, MT76x0U, MT76x2U, MT7921U
  * Ralink: RT2800USB, RT2500USB, RT73USB, RT2X00
  * Atheros: ATH9K-HTC, CARL9170
* **Software Defined Radio (SDR)**: RTL-SDR, HackRF, and Airspy support.
* **CAN Bus & Automotive Hacking**: SocketCAN, slcan, vcan, mcp251x, gs_usb, peak_usb, c_can, m_can.
* **Hardware & Serial Hacking**: FTDI, CH341, CP210x, PL2303, USB CDC-ACM.

### ⚡ Performance & Gaming Optimization
* **Adreno GPU Boost**: Dynamic frequency scaling responsiveness for extreme graphics benchmarks and high-refresh-rate gaming.
* **Adreno Idler**: Intelligently downclocks the Adreno GPU during static display content and low-workload tasks, drastically reducing idle power consumption and thermal throttling.

### 🎵 Audio & Media
* **Hi-Fi Audio**: Full DAC/codec pass-through for studio-grade audio output.
* **LHDC / LHDCv5**: Advanced low-latency, high-definition Bluetooth audio codec support.

---

## 📱 Compatibility Notice
Tested and validated on:
* **OnePlus 13** (`dodge` / `CPH2649`, `CPH2653`, `CPH2655`)
* **OxygenOS 16/Android 16**

> [!NOTE]
> If building for specific custom ROMs with strict module verification or specific seccomp policies:
> - `CONFIG_FHANDLE` should be set to `n`
> - `CONFIG_SYSVIPC` should be set to `n`
> - `CONFIG_MODULE_FORCE_UNLOAD` should be set to `n`
> - When building the kernel with a custom ROM lineage based, PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false must
> - be set in the device/sm8750-common/common.mk file to bypass the VF_Compatibility checks the build verifies against. 
---

## ⚡ How to Flash

Choose any of the following flashing methods depending on your setup.

### Method 1: Kernel Managers (Recommended)
You can flash BadgerHunter on a running rooted device using **BadgerKernelManager**, **Franco Kernel Manager (FKM)**, or **KernelFlasher**:

1. Download the latest AnyKernel3 zip: `BadgerHunter-OP13-NetHunter.zip`.
2. Open your preferred Kernel Manager:
   * **BadgerKernelManager**: Go to **Flasher** -> Tap **Select Zip** -> Select `BadgerHunter-OP13-NetHunter.zip` -> Tap **Flash**.
   * **Franco Kernel Manager (FKM)**: Tap the **Menu** -> **Flasher** -> **Manual Flasher** -> Browse and select the zip file -> Tap **Flash**.
   * **KernelFlasher**: Tap **Flash** -> Choose `BadgerHunter-OP13-NetHunter.zip` -> Confirm flash.
3. Allow the installer to complete the AnyKernel3 ramdisk repack.
4. Reboot the device.

---

### Method 2: Custom Recovery (TWRP / OrangeFox / EvolutionX Recovery)
1. Download `BadgerHunter-OP13-NetHunter.zip`.
2. Boot into Custom Recovery:
   ```bash
   adb reboot recovery
   ```
3. **Flashing via Recovery GUI (TWRP / OrangeFox)**:
   * Tap **Install**.
   * Locate and select `BadgerHunter-OP13-NetHunter.zip`.
   * Swipe to confirm flash.
   * Tap **Reboot System**.
4. **Flashing via ADB Sideload (AOSP / EvolutionX Recovery)**:
   * Select **Apply update** -> **Apply from ADB**.
   * On your computer, run:
     ```bash
     adb sideload BadgerHunter-OP13-NetHunter.zip
     ```
   * Once finished, select **Reboot system now**.

---

### Method 3: Fastboot (Direct Boot Image)
If you prefer fastboot or are recovering from a bootloop:

1. Download the prebuilt `boot.img`.
2. Boot into Fastboot / Bootloader mode:
   ```bash
   adb reboot bootloader
   ```
3. Flash `boot.img` to your active boot slot:
   ```bash
   fastboot flash boot boot.img
   ```
4. Reboot:
   ```bash
   fastboot reboot
   ```

---

## 📦 NetHunter External Kernel Modules

External Wi-Fi and CAN bus modules are provided in `BadgerHunter-OP13-NetHunter-Modules-Pack-Stripped.zip`.

### Installing and Loading Modules On-Device:
1. Extract the module pack to your device:
   ```bash
   adb push modules /data/local/tmp/modules
   adb push moduleinstall.sh /data/local/tmp/
   ```
2. Open a root shell on your phone:
   ```bash
   adb shell
   su
   ```
3. Load the modules using `moduleinstall.sh`:
   ```bash
   sh /data/local/tmp/moduleinstall.sh /data/local/tmp/modules load
   ```
4. Check status of loaded modules:
   ```bash
   sh /data/local/tmp/moduleinstall.sh /data/local/tmp/modules status
   ```
5. To safely unload:
   ```bash
   sh /data/local/tmp/moduleinstall.sh /data/local/tmp/modules unload
   ```

---

## 🛠️ Building from Source

### Prerequisites
* Linux environment (Ubuntu 22.04 / 24.04 or Debian)
* Clang Toolchain: Android Clang `clang-r510928`
* Python 3.10+, Bazel / Kleaf, ccache, git

### Build Instructions
1. Clone this repository into your kernel platform:
   ```bash
   git clone -b nethunter https://github.com/MrBadger183/android_kernel_oneplus_sm8750.git kernel_platform/msm-kernel
   ```
2. Run the build script:
   ```bash
   ./build.sh sun perf
   ```
3. The build script will compile the kernel Image, vendor DTBs, and modules, depositing flashable artifacts into `dist/`.

---

## 🙏 Credits & Acknowledgments
* **Qualcomm & OnePlusOSS** for base kernel sources.
* **KernelSU-Next Project** for modern, secure kernel-level su.
* **simonsmh / SuSFS** for the revolutionary stealth root filesystem.
* **Offensive Security / Kali NetHunter** for wireless injection patches.
* **OnePlusOSS** / For the kernel manifest that brought all this about.
* **MrBadger183** - Lead maintainer & developer.
