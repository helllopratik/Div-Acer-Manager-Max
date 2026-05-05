#!/bin/bash
# DAMX Unified Installer - Build & Install from Source
# This script builds the drivers, daemon, and GUI locally and installs them.

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}       DAMX Unified Setup Utility         ${NC}"
echo -e "${BLUE}    Build & Install directly from Source  ${NC}"
echo -e "${BLUE}==========================================${NC}"

# Check for root
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}Please run with sudo or as root.${NC}"
  exec sudo "$0" "$@"
  exit $?
fi

# Detect Version
VERSION=$(grep -oP 'private readonly string ProjectVersion\s*=\s*"\K[^"]+' DivAcerManagerMax/MainWindow.axaml.cs || echo "1.0.0")
echo -e "${GREEN}Detected Version: ${VERSION}${NC}"

# 1. Install Dependencies
echo -e "\n${YELLOW}[1/5] Installing Build Dependencies...${NC}"
apt-get update
apt-get install -y build-essential linux-headers-$(uname -r) python3 python3-pip python3-venv python3-evdev dpkg-dev wget gpg

# Check for .NET 9 SDK
if ! command -v dotnet &> /dev/null || [[ $(dotnet --version) != 9.* ]]; then
    echo -e "${YELLOW}.NET 9 SDK not found. Installing...${NC}"
    wget https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh
    chmod +x dotnet-install.sh
    ./dotnet-install.sh --channel 9.0 --install-dir /usr/share/dotnet
    ln -sf /usr/share/dotnet/dotnet /usr/bin/dotnet
fi

# Check for PyInstaller
if ! command -v pyinstaller &> /dev/null; then
    echo -e "${YELLOW}PyInstaller not found. Installing via pip...${NC}"
    pip3 install pyinstaller --break-system-packages || pip3 install pyinstaller
fi

# 2. Build Drivers
echo -e "\n${YELLOW}[2/5] Building Linuwu-Sense Drivers...${NC}"
cd Linuwu-Sense
make clean && make
cd ..

# 3. Build Daemon
echo -e "\n${YELLOW}[3/5] Building DAMX-Daemon...${NC}"
cd DAMM-Daemon
pyinstaller --onefile --clean DAMX-Daemon.py
cd ..

# 4. Build GUI
echo -e "\n${YELLOW}[4/5] Building DAMX-GUI (.NET 9)...${NC}"
cd DivAcerManagerMax
dotnet publish -c Release -r linux-x64 --self-contained true /p:PublishSingleFile=true /p:IncludeNativeLibrariesForSelfExtract=true
cd ..

# 5. Package Locally
echo -e "\n${YELLOW}[5/5] Generating DEB Package...${NC}"
BUILD_DIR="local_build_deb"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/DEBIAN"
mkdir -p "$BUILD_DIR/usr/bin"
mkdir -p "$BUILD_DIR/usr/lib/damx"
mkdir -p "$BUILD_DIR/usr/share/applications"
mkdir -p "$BUILD_DIR/usr/share/icons/hicolor/256x256/apps"
mkdir -p "$BUILD_DIR/opt/damx/src"

# Copy binaries
cp DAMM-Daemon/dist/DAMX-Daemon "$BUILD_DIR/usr/lib/damx/"
cp DivAcerManagerMax/bin/Release/net9.0/linux-x64/publish/DivAcerManagerMax "$BUILD_DIR/usr/lib/damx/"
cp DivAcerManagerMax/icon.png "$BUILD_DIR/usr/share/icons/hicolor/256x256/apps/damx.png"
cp -r Linuwu-Sense "$BUILD_DIR/opt/damx/src/"

# Create control file
cat > "$BUILD_DIR/DEBIAN/control" << EOL
Package: damx
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: amd64
Depends: python3, python3-evdev, libc6, libgcc-s1, libstdc++6
Maintainer: helllopratik <pratikgondane07@gmail.com>
Description: Div Acer Manager Max (DAMX)
 Built locally from source. Modern Acer laptop management suite.
EOL

# Create systemd service file
mkdir -p "$BUILD_DIR/etc/systemd/system"
cat > "$BUILD_DIR/etc/systemd/system/damx-daemon.service" << EOL
[Unit]
Description=DAMX Daemon for Acer laptops
After=network.target

[Service]
Type=simple
ExecStart=/usr/lib/damx/DAMX-Daemon
Restart=on-failure
RestartSec=5
User=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOL

# Post-install script (Install driver)
cat > "$BUILD_DIR/DEBIAN/postinst" << EOL
#!/bin/bash
set -e
echo "Installing drivers..."
cd /opt/damx/src/Linuwu-Sense
make install
echo "Reloading systemd..."
systemctl daemon-reload
systemctl enable damx-daemon.service || true
systemctl start damx-daemon.service || true
exit 0
EOL
chmod 755 "$BUILD_DIR/DEBIAN/postinst"

# Pre-remove script
cat > "$BUILD_DIR/DEBIAN/prerm" << EOL
#!/bin/bash
set -e
echo "Stopping DAMX services..."
systemctl stop damx-daemon.service || true
systemctl disable damx-daemon.service || true
exit 0
EOL
chmod 755 "$BUILD_DIR/DEBIAN/prerm"

# Wrapper script
cat > "$BUILD_DIR/usr/bin/damx" << EOL
#!/bin/bash
/usr/lib/damx/DivAcerManagerMax "\$@"
EOL
chmod 755 "$BUILD_DIR/usr/bin/damx"

# Desktop entry
cat > "$BUILD_DIR/usr/share/applications/damx.desktop" << EOL
[Desktop Entry]
Name=DAMX
Comment=Div Acer Manager Max
Exec=/usr/bin/damx
Icon=damx
Terminal=false
Type=Application
Categories=Utility;System;
EOL

# Build the DEB
dpkg-deb --build "$BUILD_DIR" "damx_local.deb"

# Install the DEB
echo -e "\n${GREEN}Installing the generated package...${NC}"
dpkg -i damx_local.deb || apt-get install -f -y

echo -e "\n${GREEN}🎉 DAMX has been built and installed successfully!${NC}"
echo -e "You can now run it by typing ${BLUE}damx${NC} in the terminal or finding it in your menu."

# Cleanup
rm -rf "$BUILD_DIR"
rm -f damx_local.deb
