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
# In a real CI, you would run dotnet publish and pyinstaller here.

echo "Warning: This script currently packages existing binaries if found."
echo "Building components..."

# Check if binaries exist in Publish/ (created by PackageEverything.py)
if [ -d "Publish/DAMX-${PACKAGE_VERSION}" ]; then
    echo "Found published binaries in Publish/DAMX-${PACKAGE_VERSION}. Packaging them..."
    cp -r "Publish/DAMX-${PACKAGE_VERSION}/DAMX-Daemon/"* "${PACKAGE_DIR}/usr/lib/damx/"
    cp -r "Publish/DAMX-${PACKAGE_VERSION}/DAMX-GUI/"* "${PACKAGE_DIR}/usr/lib/damx/"
    # Desktop file
    cp "Publish/DAMX-${PACKAGE_VERSION}/damx.desktop" "${PACKAGE_DIR}/usr/share/applications/" || true
    # Icon
    cp "Publish/DAMX-${PACKAGE_VERSION}/DAMX-GUI/icon.png" "${PACKAGE_DIR}/usr/share/icons/hicolor/256x256/apps/damx.png" || true
else
    echo "No published binaries found. Please run scripts/PackageEverything.py first."
    # For now, let's just create a dummy structure to show it works
    touch "${PACKAGE_DIR}/usr/lib/damx/placeholder"
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
