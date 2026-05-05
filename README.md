# Div Acer Manager Max (DAMX)

<p align="center">
  <img src="https://github.com/user-attachments/assets/6d383e82-8221-438b-9d6d-a19e998fcc59" alt="icon" width="100">
</p>

**Div Acer Manager Max (DAMX)** is a powerful Linux utility for Acer laptops. it Replicates and expands on Acer’s NitroSense and PredatorSense capabilities on Linux with full fan control, performance modes, and more.

![Hardware Manager](https://image.pollinations.ai/prompt/Acer%20Predator%20Nitro%20Gaming%20Laptop%20HUD%20Display%20Linux%20Tux%20Mascot%20Cyberpunk%20Circuitry%20Neon%20Blue%20and%20Red%20High%20Detail%208k?width=1000&height=400&nologo=true)

## 🚀 Modern Kernel Support (6.1 - 6.17+)
This fork features a **hard-patched Linuwu-Sense driver (v25.701)** with advanced compatibility layers for both old and modern Linux kernels:
*   **WMI Bus API Bridge**: Works on Kernel 6.12+ where legacy WMI handlers were removed.
*   **Platform Profile 2.0**: Compatible with Kernel 6.14+ API changes.
*   **Backward Compatibility**: Fixed support for older kernels (e.g., 6.1) by resolving backlight constant issues.
*   **Secure Boot Ready**: Automatically signs the driver module during installation using MOK.

## ✨ Features
*   🔋 **Thermal Profiles**: Eco, Silent, Balanced, Performance, Turbo.
*   🌡 **Fan Control**: Full manual/auto control for CPU and GPU fans.
*   ⌨️ **Keyboard Mapping**: Map the Nitro/Predator button to launch DAMX.
*   🔐 **Secure Boot**: Integrated MOK enrollment script for easy driver signing.
*   📦 **DEB Installer**: Native Debian/Ubuntu packaging for easy installation.

## 🖥️ Installation

### 🔗 Easy Install (Recommended)
Run the remote installer to automatically download and set up the latest DEB package and drivers:
```bash
curl -fsSL https://raw.githubusercontent.com/helllopratik/Div-Acer-Manager-Max/main/scripts/remoteSetup.sh | sudo bash
```

### 📦 Debian/Ubuntu DEB
Download the `.deb` from the [Releases](https://github.com/helllopratik/Div-Acer-Manager-Max/releases) page and install:
```bash
sudo apt install ./damx_*.deb
```
*(Note: The installer will prompt you to set a MOK password if Secure Boot is enabled. You must reboot and Enroll MOK on the blue screen).*

## 🧭 Compatibility
Check the [Compatibility List](Compatibility.md) for verified models. DAMX is built for modern Acer laptops (2022+) but supports many older models through legacy quirks.

## 🛠️ Building from Source
If you wish to build the components yourself:
1.  **Drivers**: `cd Linuwu-Sense && make`
2.  **Daemon**: Requires Python and PyInstaller.
3.  **GUI**: Requires .NET 9.0 SDK.

Alternatively, use the provided packaging script:
```bash
./scripts/make-deb.sh <path_to_gui_bin> <path_to_daemon_bin>
```

---
⭐ **Please star this repository to show support!**

## 🖥️ Troubleshooting
*   **Logs**: Check `/var/log/DAMX_Daemon_Log.log` for daemon errors.
*   **Laptop Type**: If it shows `UNKNOWN`, try restarting the service or check if headers are installed.
*   **FAQ**: See the [FAQ page](FAQ.md) for common solutions.

## ❤️ Powered by Linuwu
Built on top of the excellent [Linuwu Sense](https://github.com/0x7375646F/Linuwu-Sense) drivers. Special thanks to the original developers for enabling hardware-level access on Acer laptops.

## 🤝 Contributing
*   Report bugs or request features via GitHub Issues.
*   Submit pull requests to improve code or UI.
*   Help test on different Acer laptop models.

## 📄 License
This project is licensed under the **GNU General Public License v3.0**. See the [LICENSE](LICENSE) file for details.
