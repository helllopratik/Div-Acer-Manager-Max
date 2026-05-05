# AcerNX - Acer Linux Control Center

<p align="center">
  <img src="https://image.pollinations.ai/prompt/Modern%20Minimalist%20Cyberpunk%20Tux%20Penguin%20Neon%20Blue%20App%20Icon?width=256&height=256&nologo=true" alt="icon" width="128">
</p>

**AcerNX** is a completely modern, lightweight, and fast Linux utility for Acer laptops. It replicates the functionality of Acer’s NitroSense and PredatorSense on Linux with an extremely simple architecture.

![AcerNX GUI](https://image.pollinations.ai/prompt/Modern%20Dark%20Mode%20GUI%20Dashboard%20with%20Neon%20Blue%20Accents%20Showing%20Fan%20Speeds%20and%20Temperatures%20High%20Detail?width=1000&height=400&nologo=true)

## ✨ Why AcerNX?
The entire codebase has been heavily refactored from the ground up:
*   **Zero Daemons**: By leveraging modern Linux permissions (`tmpfiles.d`), AcerNX runs entirely in user-space as a standard desktop application. No sockets, no background services!
*   **Minimalist Python UI**: Built with `CustomTkinter` for a beautiful, responsive, and highly maintainable dark-mode UI.
*   **One-Script Installer**: Everything is built and deployed locally via a single `setup.sh` file.

## 🚀 Features
*   🔋 **Thermal Profiles**: Quiet, Balanced, Performance, Turbo, Eco.
*   🌡 **Fan Control**: Set fans to Auto or Max.
*   🔋 **Battery Health**: Toggle the 80% charge limiter to preserve battery lifespan.
*   💡 **Keyboard Backlight**: Adjust brightness seamlessly.

## 🖥️ Installation

To install AcerNX, simply clone this repository and run the unified setup script. This script will compile the required drivers, install Python dependencies, configure system permissions, and install the UI.

```bash
git clone https://github.com/helllopratik/Div-Acer-Manager-Max.git
cd Div-Acer-Manager-Max
sudo ./setup.sh
```

After installation, you can launch the app from your application menu or by running `acernx` in your terminal.

*(Note: Ensure your user is added to the `linuwu_sense` group. You may need to log out and log back in after installation for permissions to apply).*

## ❤️ Powered by Linuwu-Sense
AcerNX operates on top of the excellent [Linuwu Sense](https://github.com/0x7375646F/Linuwu-Sense) drivers, providing the critical hardware-level access needed for these features. Huge thanks to the original developers!

This fork includes advanced compatibility layers for Linuwu-Sense, ensuring it works on modern kernels (6.12+ WMI API, 6.14+ Platform Profile) as well as older stable kernels (6.1+).

## 📄 License
This project is licensed under the **GNU General Public License v3.0**. See the [LICENSE](LICENSE) file for details.
