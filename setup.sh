#!/bin/bash
# AcerNX Unified Setup Utility
# This script builds the Linuwu-Sense driver and installs the lightweight Python GUI.

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}        AcerNX Unified Setup              ${NC}"
echo -e "${BLUE}    Complete Base & Lightweight UI        ${NC}"
echo -e "${BLUE}==========================================${NC}"

# Check for root
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}Please run with sudo or as root.${NC}"
  exec sudo "$0" "$@"
  exit $?
fi

# Detect Version
VERSION="2.0.0-AcerNX"
echo -e "${GREEN}Version: ${VERSION}${NC}"

# 1. Install Dependencies
echo -e "\n${YELLOW}[1/4] Installing Build Dependencies...${NC}"
apt-get update
apt-get install -y build-essential linux-headers-$(uname -r) python3 python3-pip python3-venv python3-tk pkexec

# Install CustomTkinter for the UI
echo -e "\n${YELLOW}[2/4] Installing CustomTkinter...${NC}"
pip3 install customtkinter --break-system-packages || pip3 install customtkinter

# 3. Build & Install Drivers
echo -e "\n${YELLOW}[3/4] Building Linuwu-Sense Drivers...${NC}"
cd Linuwu-Sense
make clean && make
make install
cd ..

# 4. Install UI and Permissions
echo -e "\n${YELLOW}[4/4] Installing AcerNX UI and configuring permissions...${NC}"

# Dynamically find model path
MODEL_DIR=$(ls /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/ | grep -E 'predator_sense|nitro_sense' || true)

cat > /etc/tmpfiles.d/acernx.conf << EOL
# AcerNX permissions
f /sys/firmware/acpi/platform_profile 0660 root linuwu_sense
f /sys/class/leds/acer-wmi::kbd_backlight/brightness 0660 root linuwu_sense
EOL

if [ -n "$MODEL_DIR" ]; then
    echo "f /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/$MODEL_DIR/fan_speed 0660 root linuwu_sense" >> /etc/tmpfiles.d/acernx.conf
    echo "f /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/$MODEL_DIR/battery_limiter 0660 root linuwu_sense" >> /etc/tmpfiles.d/acernx.conf
    echo "f /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/$MODEL_DIR/usb_charging 0660 root linuwu_sense" >> /etc/tmpfiles.d/acernx.conf
    echo "f /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/$MODEL_DIR/lcd_override 0660 root linuwu_sense" >> /etc/tmpfiles.d/acernx.conf
    echo "f /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/$MODEL_DIR/boot_animation_sound 0660 root linuwu_sense" >> /etc/tmpfiles.d/acernx.conf
    echo "f /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/$MODEL_DIR/backlight_timeout 0660 root linuwu_sense" >> /etc/tmpfiles.d/acernx.conf
    echo "f /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/four_zoned_kb/four_zone_mode 0660 root linuwu_sense" >> /etc/tmpfiles.d/acernx.conf
fi

systemd-tmpfiles --create /etc/tmpfiles.d/acernx.conf || true

# Copy UI script
cp acernx.py /usr/local/bin/acernx
chmod 755 /usr/local/bin/acernx

# Create Desktop Entry
mkdir -p /usr/share/applications
cat > /usr/share/applications/acernx.desktop << EOL
[Desktop Entry]
Name=AcerNX
Comment=Acer Linux Control Center
Exec=/usr/local/bin/acernx
Icon=acernx
Terminal=false
Type=Application
Categories=Utility;System;
EOL

# Download AI Icon
echo "Downloading AI-generated Icon..."
wget -qO /usr/share/icons/hicolor/256x256/apps/acernx.png "https://image.pollinations.ai/prompt/Modern%20Minimalist%20Cyberpunk%20Tux%20Penguin%20Neon%20Blue%20App%20Icon?width=256&height=256&nologo=true" || true
gtk-update-icon-cache /usr/share/icons/hicolor || true

# Add pkexec policy for silent sysfs writes (Fallback)
mkdir -p /usr/share/polkit-1/actions
cat > /usr/share/polkit-1/actions/com.acernx.sysfs.policy << EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE policyconfig PUBLIC "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN" "http://www.freedesktop.org/standards/PolicyKit/1/policyconfig.dtd">
<policyconfig>
  <action id="com.acernx.sysfs">
    <description>Write to Acer Sysfs</description>
    <message>Authentication is required to change hardware settings</message>
    <defaults>
      <allow_any>yes</allow_any>
      <allow_inactive>yes</allow_inactive>
      <allow_active>yes</allow_active>
    </defaults>
    <annotate key="org.freedesktop.policykit.exec.path">/bin/sh</annotate>
  </action>
</policyconfig>
EOL

echo -e "\n${GREEN}🎉 AcerNX has been installed successfully!${NC}"
echo -e "You can now run it from your application menu or by typing ${BLUE}acernx${NC} in the terminal."
echo -e "${YELLOW}Note: Ensure your user is in the 'linuwu_sense' group. You may need to log out and log back in.${NC}"
