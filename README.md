# Div Acer Manager Max (DAMX)

<p align="center">
  <img src="https://github.com/user-attachments/assets/6d383e82-8221-438b-9d6d-a19e998fcc59" alt="icon" width="100">
</p>

**Div Acer Manager Max** is a powerful Linux GUI utility for Acer laptops. It replicates and expands on Acer’s NitroSense and PredatorSense capabilities on Linux with full fan control, performance modes, and more.

![AI Generated Hardware Manager](https://image.pollinations.ai/prompt/Acer%20Predator%20Nitro%20Gaming%20Laptop%20HUD%20Display%20Linux%20Tux%20Mascot%20Cyberpunk%20Circuitry%20Neon%20Blue%20and%20Red%20High%20Detail%208k?width=1000&height=400&nologo=true)

## 🚀 Modern Kernel Support (6.1 - 6.17+)
This fork features a **hard-patched Linuwu-Sense driver (v25.701)** with advanced compatibility layers for modern Linux kernels:
*   **WMI Bus API Bridge**: Works on Kernel 6.12+ where legacy WMI handlers were removed.
*   **Platform Profile 2.0**: Compatible with Kernel 6.14+ API changes.
*   **Secure Boot Ready**: Automatically signs the driver module during installation.

## ✨ Features
*   🔋 **Thermal Profiles**: Eco, Silent, Balanced, Performance, Turbo.
*   🌡 **Fan Control**: Full manual/auto control for CPU and GPU fans.
*   🔐 **Secure Boot**: Integrated MOK enrollment script.
*   📦 **DEB Installer**: Native Debian/Ubuntu packaging.

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
Check the [Compatibility List](https://github.com/PXDiv/Div-Acer-Manager-Max/blob/main/Compatibility.md) for verified models.

---
⭐ **Please star this repository to show support!**

## 🖥️ Troubleshooting

You can check the logs at /var/log/DAMX_Daemon_Log.log

If you get UNKNOWN as Laptop type, try restarting (it happens sometimes)
But if it still happens that might mean the Drivers Installation failed, Make sure you have the appropriate kernel headers to compile the drivers.

Also, check out the [FAQ page](https://github.com/PXDiv/Div-Acer-Manager-Max/blob/main/FAQ.md) before opening any issues.

Please open a new issue or discussion and include the logs to get support and help the project grow if you need any info, report a bug or just give ideas for the future versions of DAMX

## Screenshots

![image](https://github.com/user-attachments/assets/10d44e8c-14e4-4441-b60c-538af1840cf6)
![image](https://github.com/user-attachments/assets/89217b26-b94c-4c78-8fe8-3de2b22a7095)
![image](https://github.com/user-attachments/assets/72a7b944-5efc-4520-83b6-88069fc05723)
![image](https://github.com/user-attachments/assets/f9a9d663-70c6-482e-a0c4-15a4ea08a8d2)

## ❤️ Powered by Linuwu

The custom drivers for this project [Div-Linuwu Sense project](https://github.com/PXDiv/Div-Linuwu-Sense) is built entirely on top of the [Linuwu Sense](https://github.com/0x7375646F/Linuwu-Sense) drivers — huge thanks to their developers for enabling hardware-level access on Acer laptops.

## 🤝 Contributing

* Report bugs or request features via GitHub Issues
* Submit pull requests to improve code or UI
* Help test on different Acer laptop models

## 📄 License

This project is licensed under the **GNU General Public License v3.0**.  
See the [LICENSE](LICENSE) file for details.
