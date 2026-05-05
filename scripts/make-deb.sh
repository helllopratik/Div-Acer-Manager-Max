#!/bin/bash
# DAMX .deb Package Generator
# This script creates a .deb package for the DAMX Suite.

set -e

# Configuration
PACKAGE_NAME="damx"
PACKAGE_VERSION=$(grep -oP 'private readonly string ProjectVersion\s*=\s*"\K[\d.]+' DivAcerManagerMax/MainWindow.axaml.cs || echo "1.0.0")
PACKAGE_ARCH="amd64"
PACKAGE_DIR="build/deb"
DEBIAN_DIR="${PACKAGE_DIR}/DEBIAN"

echo "Building DAMX .deb package v${PACKAGE_VERSION}..."

# Clean previous builds
rm -rf build/deb
mkdir -p "${PACKAGE_DIR}/usr/bin"
mkdir -p "${PACKAGE_DIR}/usr/lib/damx"
mkdir -p "${PACKAGE_DIR}/usr/share/applications"
mkdir -p "${PACKAGE_DIR}/usr/share/icons/hicolor/256x256/apps"
mkdir -p "${PACKAGE_DIR}/etc/systemd/system"
mkdir -p "${DEBIAN_DIR}"

# Create control file
cat > "${DEBIAN_DIR}/control" << EOL
Package: ${PACKAGE_NAME}
Version: ${PACKAGE_VERSION}
Section: utils
Priority: optional
Architecture: ${PACKAGE_ARCH}
Depends: python3, python3-evdev, libc6, libgcc-s1, libstdc++6
Maintainer: helllopratik <pratikgondane07@gmail.com>
Description: Div Acer Manager Max (DAMX)
 A feature-rich GUI utility for Acer laptops to manage fans, performance,
 and backlight settings on Linux.
EOL

# Create postinst script
cat > "${DEBIAN_DIR}/postinst" << EOL
#!/bin/bash
set -e
echo "Setting up DAMX..."
# Reload systemd
systemctl daemon-reload
# Note: Driver installation is usually handled by the setup script, 
# but we could trigger it here if sources were included.
exit 0
EOL
chmod 755 "${DEBIAN_DIR}/postinst"

# Create prerm script
cat > "${DEBIAN_DIR}/prerm" << EOL
#!/bin/bash
set -e
echo "Stopping DAMX services..."
systemctl stop damx-daemon.service || true
systemctl disable damx-daemon.service || true
exit 0
EOL
chmod 755 "${DEBIAN_DIR}/prerm"

# Build components if possible (simulated here or skipped if binaries exist)
GUI_BIN_DIR=$1
DAEMON_BIN_DIR=$2

# Packaging components...
mkdir -p "${PACKAGE_DIR}/opt/damx/src"

if [ -d "Linuwu-Sense" ]; then
    echo "Including Linuwu-Sense source..."
    cp -r Linuwu-Sense "${PACKAGE_DIR}/opt/damx/src/"
    # Remove build artifacts from the source copy
    find "${PACKAGE_DIR}/opt/damx/src/Linuwu-Sense" -name "*.o" -delete || true
    find "${PACKAGE_DIR}/opt/damx/src/Linuwu-Sense" -name "*.ko" -delete || true
    find "${PACKAGE_DIR}/opt/damx/src/Linuwu-Sense" -name ".*.cmd" -delete || true
fi

if [ -n "$GUI_BIN_DIR" ] && [ -d "$GUI_BIN_DIR" ]; then
    echo "Using GUI binaries from ${GUI_BIN_DIR}"
    cp -r "${GUI_BIN_DIR}/"* "${PACKAGE_DIR}/usr/lib/damx/"
else
    # Fallback to local search
    if [ -d "Publish/DAMX-${PACKAGE_VERSION}/DAMX-GUI" ]; then
        cp -r "Publish/DAMX-${PACKAGE_VERSION}/DAMX-GUI/"* "${PACKAGE_DIR}/usr/lib/damx/"
    fi
fi

if [ -n "$DAEMON_BIN_DIR" ] && [ -d "$DAEMON_BIN_DIR" ]; then
    echo "Using Daemon binaries from ${DAEMON_BIN_DIR}"
    cp -r "${DAEMON_BIN_DIR}/"* "${PACKAGE_DIR}/usr/lib/damx/"
else
    # Fallback to local search
    if [ -d "Publish/DAMX-${PACKAGE_VERSION}/DAMX-Daemon" ]; then
        cp -r "Publish/DAMX-${PACKAGE_VERSION}/DAMX-Daemon/"* "${PACKAGE_DIR}/usr/lib/damx/"
    fi
fi

# Ensure icons and desktop files are in the right place
if [ -f "${PACKAGE_DIR}/usr/lib/damx/icon.png" ]; then
    cp "${PACKAGE_DIR}/usr/lib/damx/icon.png" "${PACKAGE_DIR}/usr/share/icons/hicolor/256x256/apps/damx.png"
fi

# Create desktop entry if missing
if [ ! -f "${PACKAGE_DIR}/usr/share/applications/damx.desktop" ]; then
    cat > "${PACKAGE_DIR}/usr/share/applications/damx.desktop" << EOL
[Desktop Entry]
Name=DAMX
Comment=Div Acer Manager Max
Exec=/usr/bin/damx
Icon=damx
Terminal=false
Type=Application
Categories=Utility;System;
Keywords=acer;laptop;system;
EOL
fi

# Create a wrapper script in /usr/bin
cat > "${PACKAGE_DIR}/usr/bin/damx" << EOL
#!/bin/bash
/usr/lib/damx/DivAcerManagerMax "\$@"
EOL
chmod 755 "${PACKAGE_DIR}/usr/bin/damx"

# Build the package
dpkg-deb --build "${PACKAGE_DIR}" "${PACKAGE_NAME}_${PACKAGE_VERSION}_${PACKAGE_ARCH}.deb"

echo "Successfully generated ${PACKAGE_NAME}_${PACKAGE_VERSION}_${PACKAGE_ARCH}.deb"
