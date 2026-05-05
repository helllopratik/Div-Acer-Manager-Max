# Div Acer Manager Max (DAMX)

<p align="center">
  <img src="https://github.com/user-attachments/assets/6d383e82-8221-438b-9d6d-a19e998fcc59" alt="icon" width="100">
</p>

**Div Acer Manager Max (DAMX)** is a powerful Linux utility for Acer laptops. It replicates and expands on Acer’s NitroSense and PredatorSense capabilities on Linux with full fan control, performance modes, and more.

![Hardware Manager](https://image.pollinations.ai/prompt/Acer%20Predator%20Nitro%20Gaming%20Laptop%20HUD%20Display%20Linux%20Tux%20Mascot%20Cyberpunk%20Circuitry%20Neon%20Blue%20and%20Red%20High%20Detail%208k?width=1000&height=400&nologo=true)

## 🚀 Modern Kernel Support (6.1 - 6.17+)
This fork features a **hard-patched Linuwu-Sense driver (v25.701-Unified)** with advanced compatibility layers:
*   **WMI Bus API Bridge**: Works on Kernel 6.12+ where legacy WMI handlers were removed.
*   **Platform Profile 2.0**: Compatible with Kernel 6.14+ API changes.
*   **Backward Compatibility**: Fixed support for older kernels (e.g., 6.1) by resolving backlight constant issues.
*   **Secure Boot Ready**: Automatically signs the driver module during installation.

## ✨ Features
*   🔋 **Thermal Profiles**: Eco, Silent, Balanced, Performance, Turbo.
*   🌡 **Fan Control**: Full manual/auto control for CPU and GPU fans.
*   ⌨️ **Keyboard Mapping**: Map the Nitro/Predator button to launch DAMX.
*   🔐 **Secure Boot**: Integrated module signing for easy driver installation.

## 🖥️ Installation (Unified One-Script Method)

To install DAMX, simply clone the repository and run the unified setup script. This script will automatically handle dependencies (including .NET 9 SDK), build the components locally, and install them to your system.

```bash
git clone https://github.com/helllopratik/Div-Acer-Manager-Max.git
cd Div-Acer-Manager-Max
sudo ./setup.sh
```

*(Note: The installer will handle everything from building the driver to setting up the GUI and Daemon).*

## 🧭 Compatibility
Check the [Compatibility List](Compatibility.md) for verified models. DAMX is built for modern Acer laptops (2022+) but supports many older models through legacy quirks.

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

## 📄 License
This project is licensed under the **GNU General Public License v3.0**. See the [LICENSE](LICENSE) file for details.
