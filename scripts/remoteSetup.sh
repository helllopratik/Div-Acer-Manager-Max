#!/bin/bash

# DAMX Remote Installer Script
# This script downloads and installs the latest DAMX Suite for Acer laptops on Linux
# Usage: curl -sSL https://raw.githubusercontent.com/PXDiv/Div-Acer-Manager-Max/main/remote-setup.sh | bash

# Constants
SCRIPT_VERSION="1.0.0"
GITHUB_REPO="PXDiv/Div-Acer-Manager-Max"
INSTALL_DIR="/opt/damx"
BIN_DIR="/usr/local/bin"
SYSTEMD_DIR="/etc/systemd/system"
DAEMON_SERVICE_NAME="damx-daemon.service"
DESKTOP_FILE_DIR="/usr/share/applications"
ICON_DIR="/usr/share/icons/hicolor/256x256/apps"
TEMP_DIR="/tmp/damx-install-$$"

# Legacy paths for cleanup (uppercase naming convention)
LEGACY_INSTALL_DIR="/opt/DAMX"
LEGACY_DAEMON_SERVICE_NAME="DAMX-Daemon.service"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to pause script execution
pause() {
  echo -e "${BLUE}Press any key to continue...${NC}"
  read -n 1 -s -r
}

# Function to check and elevate privileges
check_root() {
  if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}This script requires root privileges.${NC}"

    # Check if sudo is available
    if command -v sudo &> /dev/null; then
      echo -e "${BLUE}Attempting to run with sudo...${NC}"
      exec sudo "$0" "$@"
      exit $?
    else
      echo -e "${RED}Error: sudo not found. Please run this script as root.${NC}"
      pause
      exit 1
    fi
  fi
}

print_banner() {
  clear
  echo -e "${BLUE}==========================================${NC}"
  echo -e "${BLUE}    DAMX Remote Installer v${SCRIPT_VERSION}     ${NC}"
  echo -e "${BLUE}    Acer Laptop WMI Controls for Linux  ${NC}"
  echo -e "${BLUE}==========================================${NC}"
  echo ""
}

# Function to check required tools
check_dependencies() {
  echo -e "${YELLOW}Checking dependencies...${NC}"

  local missing_deps=()

  # Check for required tools
  if ! command -v curl &> /dev/null; then
    missing_deps+=("curl")
  fi

  if ! command -v tar &> /dev/null; then
    missing_deps+=("tar")
  fi

  if ! command -v jq &> /dev/null; then
    missing_deps+=("jq")
  fi

  # Install missing dependencies
  if [ ${#missing_deps[@]} -gt 0 ]; then
    echo -e "${YELLOW}Installing missing dependencies: ${missing_deps[*]}${NC}"

    # Detect package manager and install
    if command -v apt-get &> /dev/null; then
      apt-get update && apt-get install -y "${missing_deps[@]}"
    elif command -v yum &> /dev/null; then
      yum install -y "${missing_deps[@]}"
    elif command -v dnf &> /dev/null; then
      dnf install -y "${missing_deps[@]}"
    elif command -v pacman &> /dev/null; then
      pacman -S --noconfirm "${missing_deps[@]}"
    elif command -v zypper &> /dev/null; then
      zypper install -y "${missing_deps[@]}"
    else
      echo -e "${RED}Error: Cannot install dependencies automatically. Please install: ${missing_deps[*]}${NC}"
      exit 1
    fi
  fi

  echo -e "${GREEN}Dependencies check completed.${NC}"
}

install_kernel_build_dependencies() {
  echo -e "${YELLOW}Checking kernel build dependencies...${NC}"

  local kernel_release
  local build_dir
  local missing=()

  kernel_release="$(uname -r)"
  build_dir="/lib/modules/${kernel_release}/build"

  command -v gcc &> /dev/null || missing+=("gcc")
  command -v make &> /dev/null || missing+=("make")
  command -v python3 &> /dev/null || missing+=("python3")

  if [ ! -e "${build_dir}/Makefile" ]; then
    missing+=("kernel headers for ${kernel_release}")
  fi

  if [ ${#missing[@]} -eq 0 ]; then
    echo -e "${GREEN}Kernel build dependencies are ready for ${kernel_release}.${NC}"
    return 0
  fi

  echo -e "${YELLOW}Installing missing build dependencies: ${missing[*]}${NC}"

  if command -v apt-get &> /dev/null; then
    apt-get update && apt-get install -y build-essential "linux-headers-${kernel_release}" python3
  elif command -v dnf &> /dev/null; then
    dnf install -y gcc make "kernel-devel-${kernel_release}" python3 || dnf install -y gcc make kernel-devel python3
  elif command -v yum &> /dev/null; then
    yum install -y gcc make "kernel-devel-${kernel_release}" python3 || yum install -y gcc make kernel-devel python3
  elif command -v pacman &> /dev/null; then
    pacman -S --noconfirm --needed base-devel linux-headers python
  elif command -v zypper &> /dev/null; then
    zypper install -y gcc make kernel-devel python3
  else
    echo -e "${RED}Error: Cannot install build dependencies automatically.${NC}"
    echo "Please install gcc, make, python3, and headers for ${kernel_release}."
    return 1
  fi

  if ! command -v gcc &> /dev/null || ! command -v make &> /dev/null || ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: gcc, make, or python3 is still missing.${NC}"
    return 1
  fi

  if [ ! -e "${build_dir}/Makefile" ]; then
    echo -e "${RED}Error: Kernel headers for ${kernel_release} were not found at ${build_dir}.${NC}"
    echo "Please install the matching kernel header package and rerun this installer."
    return 1
  fi

  echo -e "${GREEN}Kernel build dependencies are ready for ${kernel_release}.${NC}"
  return 0
}

apply_linuwu_kernel_compat() {
  local driver_dir="$1"
  local source_file="${driver_dir}/src/linuwu_sense.c"

  if [ ! -f "$source_file" ]; then
    echo -e "${RED}Error: Linuwu-Sense source file not found: ${source_file}${NC}"
    return 1
  fi

  echo -e "${YELLOW}Applying Linuwu-Sense kernel compatibility patch...${NC}"

  python3 - "$source_file" <<'PY'
from pathlib import Path
import re
import sys

source = Path(sys.argv[1])
text = source.read_text()
changed = False

def replace_once(old, new, description):
    global text, changed
    if old not in text:
        raise SystemExit(f"Could not patch Linuwu-Sense source: {description}")
    text = text.replace(old, new, 1)
    changed = True

if "#include <linux/version.h>" not in text:
    replace_once("#include <linux/kernel.h>\n",
                 "#include <linux/kernel.h>\n#include <linux/version.h>\n",
                 "linux/version.h include")

if "#include <linux/err.h>" not in text:
    replace_once("#include <linux/bitmap.h>\n",
                 "#include <linux/bitmap.h>\n#include <linux/err.h>\n",
                 "linux/err.h include")

if "#include <linux/unaligned.h>" in text and "#include <asm/unaligned.h>" not in text:
    replace_once("#include <linux/unaligned.h>\n",
                 "#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 12, 0)\n"
                 "#include <asm/unaligned.h>\n"
                 "#else\n"
                 "#include <linux/unaligned.h>\n"
                 "#endif\n",
                 "unaligned include compatibility")

if "DAMX_BACKLIGHT_POWER_COMPAT" not in text:
    replace_once("#include <linux/err.h>\n",
                 "#include <linux/err.h>\n\n"
                 "#ifndef BACKLIGHT_POWER_ON\n"
                 "#define DAMX_BACKLIGHT_POWER_COMPAT\n"
                 "#define BACKLIGHT_POWER_ON FB_BLANK_UNBLANK\n"
                 "#endif\n",
                 "backlight power compatibility")

if "DAMX kernel compatibility layer" not in text:
    compat = r'''
/* DAMX kernel compatibility layer for platform_profile API changes.
 * Linux 6.14+ uses struct platform_profile_ops and devm registration.
 * Linux 6.13 and older use struct platform_profile_handler.
 */
#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 14, 0)
struct platform_profile_ops {
    int (*probe)(void *drvdata, unsigned long *choices);
    int (*hidden_choices)(void *drvdata, unsigned long *choices);
    int (*profile_get)(struct device *dev, enum platform_profile_option *profile);
    int (*profile_set)(struct device *dev, enum platform_profile_option profile);
};

static struct platform_profile_handler acer_platform_profile_handler;
static const struct platform_profile_ops *acer_platform_profile_ops_compat;
static bool acer_platform_profile_legacy_registered;

static int acer_platform_profile_get_compat(struct platform_profile_handler *pprof,
                                            enum platform_profile_option *profile)
{
    if (!acer_platform_profile_ops_compat || !acer_platform_profile_ops_compat->profile_get)
        return -ENODEV;

    return acer_platform_profile_ops_compat->profile_get(NULL, profile);
}

static int acer_platform_profile_set_compat(struct platform_profile_handler *pprof,
                                            enum platform_profile_option profile)
{
    if (!acer_platform_profile_ops_compat || !acer_platform_profile_ops_compat->profile_set)
        return -ENODEV;

    return acer_platform_profile_ops_compat->profile_set(NULL, profile);
}

static struct device *damx_devm_platform_profile_register(struct device *dev,
                                                          const char *name,
                                                          void *drvdata,
                                                          const struct platform_profile_ops *ops)
{
    int err;

    memset(&acer_platform_profile_handler, 0, sizeof(acer_platform_profile_handler));
    acer_platform_profile_ops_compat = ops;

    if (ops && ops->probe) {
        err = ops->probe(drvdata, acer_platform_profile_handler.choices);
        if (err)
            return ERR_PTR(err);
    }

    acer_platform_profile_handler.profile_get = acer_platform_profile_get_compat;
    acer_platform_profile_handler.profile_set = acer_platform_profile_set_compat;

    err = platform_profile_register(&acer_platform_profile_handler);
    if (err)
        return ERR_PTR(err);

    acer_platform_profile_legacy_registered = true;
    return dev;
}

static void damx_platform_profile_remove_compat(void)
{
    if (acer_platform_profile_legacy_registered) {
        platform_profile_remove();
        acer_platform_profile_legacy_registered = false;
        acer_platform_profile_ops_compat = NULL;
    }
}

#define devm_platform_profile_register(dev, name, drvdata, ops) \
    damx_devm_platform_profile_register(dev, name, drvdata, ops)
#define platform_profile_notify(dev) platform_profile_notify()
#else
static inline void damx_platform_profile_remove_compat(void) {}
#endif
'''
    text, count = re.subn(
        r"(static struct device \*platform_profile_device;\s*static bool platform_profile_support;\s*)",
        r"\1\n" + compat + "\n",
        text,
        count=1,
    )
    if count != 1:
        raise SystemExit("Could not patch Linuwu-Sense source: platform_profile compatibility")
    changed = True

if "#define acer_wmi_notify_handler" not in text:
    needle = "     }\n }\n \n static acpi_status __init\n wmid3_set_function_mode"
    wrapper = '''     }
 }

#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 12, 0)
static void acer_wmi_notify_event(u32 value, void *context)
{
    struct acpi_buffer response = { ACPI_ALLOCATE_BUFFER, NULL };
    acpi_status status;

    status = wmi_get_event_data(value, &response);
    if (ACPI_FAILURE(status)) {
        pr_warn("bad event status 0x%x\\n", status);
        return;
    }

    acer_wmi_notify(response.pointer, context);
    kfree(response.pointer);
}
#define acer_wmi_notify_handler acer_wmi_notify_event
#else
#define acer_wmi_notify_handler acer_wmi_notify
#endif

 static acpi_status __init
 wmid3_set_function_mode'''
    replace_once(needle, wrapper, "WMI notify compatibility")

if "acer_wmi_notify_handler" in text:
    new_text = text.replace("                         acer_wmi_notify, NULL);",
                            "                         acer_wmi_notify_handler, NULL);")
    if new_text != text:
        text = new_text
        changed = True

if "#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 4, 0)\n static const struct hwmon_channel_info *acer_wmi_hwmon_info[]" not in text:
    old = " static const struct hwmon_channel_info *const acer_wmi_hwmon_info[] = {"
    if old in text:
        text = text.replace(
            old,
            " #if LINUX_VERSION_CODE < KERNEL_VERSION(6, 4, 0)\n"
            " static const struct hwmon_channel_info *acer_wmi_hwmon_info[] = {\n"
            " #else\n"
            " static const struct hwmon_channel_info *const acer_wmi_hwmon_info[] = {\n"
            " #endif",
            1,
        )
        changed = True

if "static int acer_platform_remove(struct platform_device *device)" not in text:
    text, count = re.subn(
        r"(?m)^(\s*)static void acer_platform_remove\(struct platform_device \*device\)\n\1\{",
        r"\1#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 11, 0)\n"
        r"\1static int acer_platform_remove(struct platform_device *device)\n"
        r"\1#else\n"
        r"\1static void acer_platform_remove(struct platform_device *device)\n"
        r"\1#endif\n"
        r"\1{",
        text,
        count=1,
    )
    if count != 1:
        raise SystemExit("Could not patch Linuwu-Sense source: platform remove signature")
    changed = True

remove_start = text.find("acer_platform_remove")
pm_start = text.find("#ifdef CONFIG_PM_SLEEP", remove_start)
if remove_start != -1 and pm_start != -1 and "damx_platform_profile_remove_compat();" not in text[remove_start:pm_start]:
    replace_once("     acer_rfkill_exit();\n }\n \n #ifdef CONFIG_PM_SLEEP",
                 "     if (platform_profile_support)\n"
                 "         damx_platform_profile_remove_compat();\n"
                 " \n"
                 "     acer_rfkill_exit();\n"
                 " \n"
                 " #if LINUX_VERSION_CODE < KERNEL_VERSION(6, 11, 0)\n"
                 "     return 0;\n"
                 " #endif\n"
                 " }\n"
                 " \n"
                 " #ifdef CONFIG_PM_SLEEP",
                 "platform remove cleanup")

if changed:
    source.write_text(text)
    print("Applied DAMX kernel compatibility patch.")
else:
    print("DAMX kernel compatibility patch already present.")
PY
}

# Function to get latest release info
get_latest_release() {
  echo -e "${YELLOW}Fetching latest release information...${NC}"

  local api_url="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
  local release_info

  release_info=$(curl -s "$api_url")

  if [ $? -ne 0 ] || [ -z "$release_info" ]; then
    echo -e "${RED}Error: Failed to fetch release information from GitHub API${NC}"
    return 1
  fi

  # Check if the response contains an error
  if echo "$release_info" | jq -e '.message' &> /dev/null; then
    local error_msg=$(echo "$release_info" | jq -r '.message')
    echo -e "${RED}Error: GitHub API returned: $error_msg${NC}"
    return 1
  fi

  # Extract release information
  RELEASE_TAG=$(echo "$release_info" | jq -r '.tag_name')
  RELEASE_NAME=$(echo "$release_info" | jq -r '.name')
  DOWNLOAD_URL=$(echo "$release_info" | jq -r '.assets[] | select(.name | endswith(".tar.xz")) | .browser_download_url')
  CHECKSUM_URL=$(echo "$release_info" | jq -r '.assets[] | select(.name | endswith(".tar.xz.sha256")) | .browser_download_url')

  if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" = "null" ]; then
    echo -e "${RED}Error: No suitable package found in the latest release${NC}"
    return 1
  fi

  echo -e "${GREEN}Latest release found: $RELEASE_NAME${NC}"
  echo -e "Download URL: $DOWNLOAD_URL"

  return 0
}

# Function to download and verify package
download_package() {
  echo -e "${YELLOW}Downloading DAMX package...${NC}"

  # Create temporary directory
  mkdir -p "$TEMP_DIR"
  cd "$TEMP_DIR"

  # Extract filename from URL
  local package_file=$(basename "$DOWNLOAD_URL")
  local checksum_file="${package_file}.sha256"

  # Download package
  echo "Downloading $package_file..."
  if ! curl -L -o "$package_file" "$DOWNLOAD_URL"; then
    echo -e "${RED}Error: Failed to download package${NC}"
    return 1
  fi

  # Download and verify checksum if available
  if [ -n "$CHECKSUM_URL" ] && [ "$CHECKSUM_URL" != "null" ]; then
    echo "Downloading checksum file..."
    if curl -L -o "$checksum_file" "$CHECKSUM_URL"; then
      echo "Verifying package integrity..."
      if sha256sum -c "$checksum_file"; then
        echo -e "${GREEN}Package integrity verified successfully.${NC}"
      else
        echo -e "${RED}Error: Package integrity check failed${NC}"
        return 1
      fi
    else
      echo -e "${YELLOW}Warning: Could not download checksum file, skipping verification${NC}"
    fi
  else
    echo -e "${YELLOW}Warning: No checksum available, skipping verification${NC}"
  fi

  # Extract package
  echo "Extracting package..."
  if ! tar -xJf "$package_file"; then
    echo -e "${RED}Error: Failed to extract package${NC}"
    return 1
  fi

  # Find extracted directory
  EXTRACTED_DIR=$(find . -maxdepth 1 -type d -name "DAMX-*" | head -1)
  if [ -z "$EXTRACTED_DIR" ]; then
    echo -e "${RED}Error: Could not find extracted DAMX directory${NC}"
    return 1
  fi

  echo -e "${GREEN}Package downloaded and extracted successfully.${NC}"
  return 0
}

# Function to detect and clean up legacy installations
cleanup_legacy_installation() {
  echo -e "${YELLOW}Checking for legacy installations...${NC}"
  local cleanup_performed=false

  # Check for legacy service file (uppercase naming)
  if [ -f "${SYSTEMD_DIR}/${LEGACY_DAEMON_SERVICE_NAME}" ]; then
    echo -e "${BLUE}Found legacy service file: ${LEGACY_DAEMON_SERVICE_NAME}${NC}"

    # Stop the legacy service if it's running
    if systemctl is-active --quiet ${LEGACY_DAEMON_SERVICE_NAME} 2>/dev/null; then
      echo "Stopping legacy service..."
      systemctl stop ${LEGACY_DAEMON_SERVICE_NAME}
    fi

    # Disable the legacy service if it's enabled
    if systemctl is-enabled --quiet ${LEGACY_DAEMON_SERVICE_NAME} 2>/dev/null; then
      echo "Disabling legacy service..."
      systemctl disable ${LEGACY_DAEMON_SERVICE_NAME}
    fi

    # Remove the legacy service file
    echo "Removing legacy service file..."
    rm -f "${SYSTEMD_DIR}/${LEGACY_DAEMON_SERVICE_NAME}"
    cleanup_performed=true
  fi

  # Check for legacy installation directory (uppercase naming)
  if [ -d "${LEGACY_INSTALL_DIR}" ]; then
    echo -e "${BLUE}Found legacy installation directory: ${LEGACY_INSTALL_DIR}${NC}"
    echo "Removing legacy installation directory..."
    rm -rf "${LEGACY_INSTALL_DIR}"
    cleanup_performed=true
  fi

  # Check for other potential legacy artifacts
  local legacy_artifacts=(
    "/usr/local/bin/DAMX-Daemon"
    "/usr/share/applications/DAMX.desktop"
    "/usr/share/icons/hicolor/256x256/apps/DAMX.png"
  )

  for artifact in "${legacy_artifacts[@]}"; do
    if [ -f "$artifact" ] || [ -d "$artifact" ]; then
      echo "Removing legacy artifact: $artifact"
      rm -rf "$artifact"
      cleanup_performed=true
    fi
  done

  # Reload systemd daemon if any service changes were made
  if [ "$cleanup_performed" = true ]; then
    echo "Reloading systemd daemon configuration..."
    systemctl daemon-reload
    echo -e "${GREEN}Legacy installation cleanup completed.${NC}"
  else
    echo -e "${GREEN}No legacy installations found.${NC}"
  fi

  return 0
}

# Function to perform comprehensive cleanup for uninstall/reinstall
comprehensive_cleanup() {
  echo -e "${YELLOW}Performing comprehensive cleanup...${NC}"

  # Stop and disable current daemon service
  if systemctl is-active --quiet ${DAEMON_SERVICE_NAME} 2>/dev/null; then
    echo "Stopping current DAMX-Daemon service..."
    systemctl stop ${DAEMON_SERVICE_NAME}
  fi

  if systemctl is-enabled --quiet ${DAEMON_SERVICE_NAME} 2>/dev/null; then
    echo "Disabling current DAMX-Daemon service..."
    systemctl disable ${DAEMON_SERVICE_NAME}
  fi

  # Remove current service file
  if [ -f "${SYSTEMD_DIR}/${DAEMON_SERVICE_NAME}" ]; then
    echo "Removing current service file..."
    rm -f "${SYSTEMD_DIR}/${DAEMON_SERVICE_NAME}"
  fi

  # Clean up legacy installations
  cleanup_legacy_installation

  # Remove current installed files
  echo "Removing current installation files..."
  rm -rf ${INSTALL_DIR}
  rm -f ${BIN_DIR}/DAMX
  rm -f ${DESKTOP_FILE_DIR}/damx.desktop
  rm -f ${ICON_DIR}/damx.png

  # Final systemd daemon reload
  systemctl daemon-reload

  echo -e "${GREEN}Comprehensive cleanup completed.${NC}"
  return 0
}

install_drivers() {
  echo -e "${YELLOW}Installing Linuwu-Sense drivers...${NC}"

  if [ ! -d "$EXTRACTED_DIR/Linuwu-Sense" ]; then
    echo -e "${RED}Error: Linuwu-Sense directory not found in package!${NC}"
    return 1
  fi

  cd "$EXTRACTED_DIR/Linuwu-Sense"

  if ! install_kernel_build_dependencies; then
    cd "$TEMP_DIR"
    return 1
  fi

  if ! apply_linuwu_kernel_compat "."; then
    cd "$TEMP_DIR"
    return 1
  fi

  if make clean && make && make install; then
    echo -e "${GREEN}Linuwu-Sense drivers installed successfully!${NC}"
    cd "$TEMP_DIR"
    return 0
  else
    echo -e "${RED}Error: Failed to install Linuwu-Sense drivers${NC}"
    cd "$TEMP_DIR"
    return 1
  fi
}

install_daemon() {
  echo -e "${YELLOW}Installing DAMX-Daemon...${NC}"

  if [ ! -d "$EXTRACTED_DIR/DAMX-Daemon" ]; then
    echo -e "${RED}Error: DAMX-Daemon directory not found in package!${NC}"
    return 1
  fi

  # Create installation directory
  mkdir -p ${INSTALL_DIR}/daemon

  # Copy daemon binary
  cp -f "$EXTRACTED_DIR/DAMX-Daemon/DAMX-Daemon" ${INSTALL_DIR}/daemon/
  chmod +x ${INSTALL_DIR}/daemon/DAMX-Daemon

  # Create systemd service file with improved configuration
  cat > ${SYSTEMD_DIR}/${DAEMON_SERVICE_NAME} << EOL
[Unit]
Description=DAMX Daemon for Acer laptops
After=network.target

[Service]
Type=simple
ExecStart=${INSTALL_DIR}/daemon/DAMX-Daemon
Restart=on-failure
RestartSec=5
User=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOL

  # Enable and start the service
  systemctl daemon-reload
  systemctl enable ${DAEMON_SERVICE_NAME}
  systemctl start ${DAEMON_SERVICE_NAME}

  # Verify service is running
  if systemctl is-active --quiet ${DAEMON_SERVICE_NAME}; then
    echo -e "${GREEN}DAMX-Daemon installed and service started successfully!${NC}"
    return 0
  else
    echo -e "${RED}Warning: DAMX-Daemon service may not have started correctly. Check with 'systemctl status ${DAEMON_SERVICE_NAME}'${NC}"
    return 1
  fi
}

install_gui() {
  echo -e "${YELLOW}Installing DAMX-GUI...${NC}"

  if [ ! -d "$EXTRACTED_DIR/DAMX-GUI" ]; then
    echo -e "${RED}Error: DAMX-GUI directory not found in package!${NC}"
    return 1
  fi

  # Create installation directory
  mkdir -p ${INSTALL_DIR}/gui

  # Copy GUI files
  cp -rf "$EXTRACTED_DIR/DAMX-GUI"/* ${INSTALL_DIR}/gui/
  chmod +x ${INSTALL_DIR}/gui/DivAcerManagerMax

  # Create icon directory if it doesn't exist
  mkdir -p ${ICON_DIR}

  # Copy icon (try different possible icon names)
  if [ -f "$EXTRACTED_DIR/DAMX-GUI/icon.png" ]; then
    cp -f "$EXTRACTED_DIR/DAMX-GUI/icon.png" ${ICON_DIR}/damx.png
  elif [ -f "$EXTRACTED_DIR/DAMX-GUI/iconTransparent.png" ]; then
    cp -f "$EXTRACTED_DIR/DAMX-GUI/iconTransparent.png" ${ICON_DIR}/damx.png
  fi

  # Create desktop entry
  cat > ${DESKTOP_FILE_DIR}/damx.desktop << EOL
[Desktop Entry]
Name=DAMX
Comment=Div Acer Manager Max
Exec=${INSTALL_DIR}/gui/DivAcerManagerMax
Icon=damx
Terminal=false
Type=Application
Categories=Utility;System;
Keywords=acer;laptop;system;
EOL

  # Create command shortcut
  cat > ${BIN_DIR}/DAMX << EOL
#!/bin/bash
${INSTALL_DIR}/gui/DivAcerManagerMax "\$@"
EOL
  chmod +x ${BIN_DIR}/DAMX

  echo -e "${GREEN}DAMX-GUI installed successfully!${NC}"
  return 0
}

perform_install() {
  echo -e "${BLUE}Performing cleanup before installation...${NC}"
  comprehensive_cleanup
  echo ""

  # Create main installation directory
  mkdir -p ${INSTALL_DIR}

  # Install components
  install_drivers
  DRIVER_RESULT=$?

  install_daemon
  DAEMON_RESULT=$?

  install_gui
  GUI_RESULT=$?

  # Check if all installations were successful
  if [ $DRIVER_RESULT -eq 0 ] && [ $DAEMON_RESULT -eq 0 ] && [ $GUI_RESULT -eq 0 ]; then
    echo -e "${GREEN}DAMX Suite installation completed successfully!${NC}"
    echo -e "You can now run the GUI using the ${BLUE}DAMX${NC} command or from your application launcher."

    # Show service status
    echo ""
    echo -e "${BLUE}Service Status:${NC}"
    systemctl status ${DAEMON_SERVICE_NAME} --no-pager -l
    return 0
  else
    echo -e "${RED}Some components failed to install. Please check the errors above.${NC}"
    return 1
  fi
}

uninstall() {
  echo -e "${YELLOW}Uninstalling DAMX Suite...${NC}"
  comprehensive_cleanup
  echo -e "${GREEN}DAMX Suite uninstalled successfully!${NC}"
  return 0
}

# Function to check system compatibility
check_system() {
  echo -e "${BLUE}Checking system compatibility...${NC}"

  # Check if systemd is available (hard requirement)
  if ! command -v systemctl &> /dev/null; then
    echo -e "${RED}Error: systemd is required but not found on this system.${NC}"
    return 1
  fi
  echo -e "${GREEN}✓ systemd found${NC}"

  # Check kernel version (warning only)
  local kernel_release
  local kernel_version
  local kernel_major
  local kernel_minor

  kernel_release="$(uname -r)"
  kernel_version="$(echo "$kernel_release" | cut -d. -f1,2)"
  kernel_major="$(echo "$kernel_version" | cut -d. -f1)"
  kernel_minor="$(echo "$kernel_version" | cut -d. -f2)"

  echo "Kernel version: ${kernel_release}"

  # Linux 6.1 and newer are covered by the installer compatibility patch.
  if [ "$kernel_major" -lt 6 ] || ([ "$kernel_major" -eq 6 ] && [ "$kernel_minor" -lt 1 ]); then
    echo -e "${YELLOW}Warning: Kernel version $kernel_version is lower than the validated 6.1+ baseline. Installation will continue, but the driver may need additional kernel API fixes.${NC}"
  else
    echo -e "${GREEN}✓ Kernel version $kernel_version is supported${NC}"
  fi

  # Check distribution (informational only)
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "Detected OS: $PRETTY_NAME"

    # Check if it's Ubuntu (officially supported)
    if echo "$ID" | grep -q "ubuntu"; then
      echo -e "${GREEN}✓ Ubuntu detected (officially supported)${NC}"
    else
      echo -e "${YELLOW}Note: Only Ubuntu is officially supported. Other distributions may work but are not guaranteed.${NC}"
    fi
  else
    echo -e "${YELLOW}Note: Could not detect distribution. Only Ubuntu is officially supported.${NC}"
  fi

  echo -e "${GREEN}System compatibility check completed.${NC}"
  return 0
}

# Cleanup function to remove temporary files
cleanup_temp() {
  if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
    echo -e "${YELLOW}Cleaning up temporary files...${NC}"
    rm -rf "$TEMP_DIR"
  fi
}

# Main installation function
main() {
  # Set trap to cleanup on exit
  trap cleanup_temp EXIT

  print_banner

  # Check and elevate privileges if needed
  check_root "$@"

  # Perform initial system check
  if ! check_system; then
    echo -e "${RED}Critical system compatibility check failed. Exiting.${NC}"
    exit 1
  fi

  # Check dependencies
  check_dependencies

  # Get latest release information
  if ! get_latest_release; then
    echo -e "${RED}Failed to get release information. Exiting.${NC}"
    exit 1
  fi

  # Download package
  if ! download_package; then
    echo -e "${RED}Failed to download package. Exiting.${NC}"
    exit 1
  fi

  # Perform installation
  echo ""
  echo -e "${BLUE}Starting DAMX Suite installation...${NC}"
  if perform_install; then
    echo ""
    echo -e "${GREEN}🎉 DAMX Suite has been installed successfully!${NC}"
    echo -e "Release: ${RELEASE_NAME}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo -e "• Run ${GREEN}DAMX${NC} from the command line"
    echo -e "• Or find 'DAMX' in your application launcher"
    echo -e "• Check service status: ${GREEN}systemctl status ${DAEMON_SERVICE_NAME}${NC}"
    echo ""
  else
    echo -e "${RED}Installation failed. Please check the errors above.${NC}"
    exit 1
  fi
}

# Handle command line arguments
case "${1:-}" in
  --uninstall)
    check_root "$@"
    print_banner
    uninstall
    exit 0
    ;;
  --help|-h)
    echo "DAMX Remote Installer"
    echo ""
    echo "Usage:"
    echo "  curl -sSL https://raw.githubusercontent.com/PXDiv/Div-Acer-Manager-Max/main/remote-setup.sh | bash"
    echo "  curl -sSL https://raw.githubusercontent.com/PXDiv/Div-Acer-Manager-Max/main/remote-setup.sh | bash -s -- --uninstall"
    echo ""
    echo "Options:"
    echo "  --uninstall    Uninstall DAMX Suite"
    echo "  --help, -h     Show this help message"
    exit 0
    ;;
  *)
    main "$@"
    ;;
esac
