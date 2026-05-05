#!/bin/bash

# DAMX Installer Script
# This script installs, uninstalls, or updates the DAMX Suite for Acer laptops on Linux
# Components: Linuwu-Sense (drivers), DAMX-Daemon, and DAMX-GUI

# Constants
SCRIPT_VERSION="0.8.8"
INSTALL_DIR="/opt/damx"
BIN_DIR="/usr/local/bin"
SYSTEMD_DIR="/etc/systemd/system"
DAEMON_SERVICE_NAME="damx-daemon.service"
DESKTOP_FILE_DIR="/usr/share/applications"
ICON_DIR="/usr/share/icons/hicolor/256x256/apps"

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
  echo -e "${BLUE}       DAMX Suite Installer v${SCRIPT_VERSION}        ${NC}"
  echo -e "${BLUE}    Acer Laptop WMI Controls for Linux  ${NC}"
  echo -e "${BLUE}==========================================${NC}"
  echo ""
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

  # Uninstall drivers if Linuwu-Sense folder exists
  if [ -d "Linuwu-Sense" ]; then
    echo "Uninstalling drivers..."
    cd Linuwu-Sense
    if [ -f "Makefile" ]; then
      make uninstall 2>/dev/null || true
    fi
    cd ..
  fi

  # Final systemd daemon reload
  systemctl daemon-reload

  echo -e "${GREEN}Comprehensive cleanup completed.${NC}"
  return 0
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

def re_replace_once(pattern, replacement, description):
    global text, changed
    new_text, count = re.subn(pattern, replacement, text, count=1, flags=re.MULTILINE)
    if count == 0:
        raise SystemExit(f"Could not patch Linuwu-Sense source: {description}")
    text = new_text
    changed = True

if "#include <linux/version.h>" not in text:
    re_replace_once(r'^(\s*)#include <linux/kernel\.h>',
                    r'\1#include <linux/kernel.h>\n\1#include <linux/version.h>',
                    "linux/version.h include")

if "#include <linux/err.h>" not in text:
    re_replace_once(r'^(\s*)#include <linux/bitmap\.h>',
                    r'\1#include <linux/bitmap.h>\n\1#include <linux/err.h>',
                    "linux/err.h include")

if "#include <linux/unaligned.h>" in text and "#include <asm/unaligned.h>" not in text:
    re_replace_once(r'^(\s*)#include <linux/unaligned\.h>',
                    r'#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 12, 0)\n'
                    r'\1#include <asm/unaligned.h>\n'
                    r'#else\n'
                    r'\1#include <linux/unaligned.h>\n'
                    r'#endif',
                    "unaligned include compatibility")

if "DAMX_BACKLIGHT_POWER_COMPAT" not in text:
    re_replace_once(r'^(\s*)#include <linux/err\.h>',
                    r'\1#include <linux/err.h>\n\n'
                    r'#ifndef BACKLIGHT_POWER_ON\n'
                    r'#define DAMX_BACKLIGHT_POWER_COMPAT\n'
                    r'#define BACKLIGHT_POWER_ON FB_BLANK_UNBLANK\n'
                    r'#endif',
                    "backlight power compatibility")

if "DAMX kernel compatibility layer" not in text:
    compat = r'''
/* DAMX kernel compatibility layer for platform_profile and WMI changes.
 * platform_profile: Linux 6.14+ uses struct platform_profile_ops and devm registration.
 * WMI: Linux 6.12+ removed legacy wmi_install_notify_handler.
 */
#if LINUX_VERSION_CODE >= 61200
#include <linux/wmi.h>
static void acer_wmi_notify(union acpi_object *obj, void *context);
static void damx_wmi_notify(struct wmi_device *wdev, union acpi_object *data) {
    acer_wmi_notify(data, NULL);
}
static const struct wmi_device_id damx_wmi_id_table[] = {
    { "676AA15E-6A47-4D9F-A2CC-1E6D18D14026", NULL },
    { }
};
static struct wmi_driver damx_wmi_driver = {
    .driver = { .name = "damx-wmi-event", },
    .id_table = damx_wmi_id_table,
    .notify = damx_wmi_notify,
};
static inline acpi_status damx_wmi_install_notify_handler(const char *guid, void *handler, void *data) {
    return wmi_driver_register(&damx_wmi_driver) ? AE_ERROR : AE_OK;
}
static inline void damx_wmi_remove_notify_handler(const char *guid) {
    wmi_driver_unregister(&damx_wmi_driver);
}
#define wmi_install_notify_handler(guid, handler, data) damx_wmi_install_notify_handler(guid, handler, data)
#define wmi_remove_notify_handler(guid) damx_wmi_remove_notify_handler(guid)
#endif

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
    re_replace_once(r'(static struct device \*platform_profile_device;\s*static bool platform_profile_support;\s*)',
                    r'\1\n' + compat + '\n',
                    "platform_profile compatibility")

if "#define acer_wmi_notify_handler" not in text:
    needle = r'^\s*static acpi_status __init\n\s*wmid3_set_function_mode'
    wrapper = '''
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

'''
    re_replace_once(needle, wrapper + r'\g<0>', "WMI notify compatibility")

if "acer_wmi_notify_handler" in text:
    text = text.replace("acer_wmi_notify, NULL);", "acer_wmi_notify_handler, NULL);")
    changed = True

if "#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 4, 0)\n static const struct hwmon_channel_info *acer_wmi_hwmon_info[]" not in text:
    re_replace_once(r'^(\s*)static const struct hwmon_channel_info \*const acer_wmi_hwmon_info\[\] = \{',
                    r'\1#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 4, 0)\n'
                    r'\1static const struct hwmon_channel_info *acer_wmi_hwmon_info[] = {\n'
                    r'#else\n'
                    r'\1static const struct hwmon_channel_info *const acer_wmi_hwmon_info[] = {\n'
                    r'#endif',
                    "hwmon channel info compatibility")

if "static int acer_platform_remove(struct platform_device *device)" not in text:
    re_replace_once(r'^(\s*)static void acer_platform_remove\(struct platform_device \*device\)\n\1\{',
                    r'\1#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 11, 0)\n'
                    r'\1static int acer_platform_remove(struct platform_device *device)\n'
                    r'\1#else\n'
                    r'\1static void acer_platform_remove(struct platform_device *device)\n'
                    r'\1#endif\n'
                    r'\1{',
                    "platform remove signature")

remove_start = text.find("acer_platform_remove")
pm_start = text.find("#ifdef CONFIG_PM_SLEEP", remove_start)
if remove_start != -1 and pm_start != -1 and "damx_platform_profile_remove_compat();" not in text[remove_start:pm_start]:
    re_replace_once(r'(\s*acer_rfkill_exit\(\);\n\s*\}\n\s*\n\s*#ifdef CONFIG_PM_SLEEP)',
                    r'\n     if (platform_profile_support)\n'
                    r'         damx_platform_profile_remove_compat();\n'
                    r'\n'
                    r'     acer_rfkill_exit();\n'
                    r'\n'
                    r' #if LINUX_VERSION_CODE < KERNEL_VERSION(6, 11, 0)\n'
                    r'     return 0;\n'
                    r' #endif\n'
                    r' }\n'
                    r'\n'
                    r' #ifdef CONFIG_PM_SLEEP',
                    "platform remove cleanup")

if changed:
    source.write_text(text)
    print("Applied DAMX kernel compatibility patch.")
else:
    print("DAMX kernel compatibility patch already present.")
PY
}

handle_secure_boot() {
  local module_to_sign="$1"
  local sb_state=$(mokutil --sb-state 2>/dev/null || true)
  if ! echo "$sb_state" | grep -iq "enabled"; then
    echo -e "${GREEN}Secure Boot is disabled or not supported. Skipping module signing.${NC}"
    return 0
  fi

  echo -e "${YELLOW}Secure Boot is enabled. Setting up module signing...${NC}"
  local real_user="${SUDO_USER:-$USER}"
  local user_home=$(getent passwd "$real_user" | cut -d: -f6 2>/dev/null)
  [ -z "$user_home" ] && user_home="/root"
  local keydir="$user_home/module-signing"

  mkdir -p "$keydir"
  cd "$keydir"

  if [[ ! -f MOK.priv || ! -f MOK.pem ]]; then
    echo "Creating MOK key pair..."
    openssl req -new -x509 -newkey rsa:2048 -keyout MOK.priv -out MOK.pem -nodes -days 36500 -subj "/CN=Linuwu Sense Module Signing/" 2>/dev/null
  fi
  if [[ ! -f MOK.der ]]; then
    openssl x509 -in MOK.pem -outform DER -out MOK.der 2>/dev/null
  fi

  local kdir="/lib/modules/$(uname -r)/build"
  local signfile="$kdir/scripts/sign-file"

  if [[ -x "$signfile" && -f "$module_to_sign" ]]; then
    echo "Signing module: $module_to_sign"
    sudo "$signfile" sha256 MOK.priv MOK.pem "$module_to_sign"
  else
    echo -e "${RED}Could not sign module (missing sign-file or module).${NC}"
  fi

  if ! mokutil --list-enrolled 2>/dev/null | grep -q "Linuwu Sense Module Signing"; then
    echo -e "${RED}===========================================${NC}"
    echo -e "${RED}             REBOOT REQUIRED               ${NC}"
    echo -e "${YELLOW}MOK key not enrolled. Importing key...${NC}"
    echo -e "${YELLOW}On reboot, you MUST enroll the MOK key.${NC}"
    echo -e "${YELLOW}The driver will not work until you reboot and enroll.${NC}"
    echo -e "${RED}===========================================${NC}"
    sudo mokutil --import MOK.der || true
  else
    echo -e "${GREEN}MOK key already enrolled. Module signed successfully.${NC}"
  fi
}

install_drivers() {
  echo -e "${YELLOW}Installing Linuwu-Sense drivers...${NC}"

  local driver_dir=""
  if [ -d "Linuwu-Sense" ]; then
    driver_dir="Linuwu-Sense"
  elif [ -d "../Linuwu-Sense" ]; then
    driver_dir="../Linuwu-Sense"
  fi

  if [ -z "$driver_dir" ]; then
    echo -e "${RED}Error: Linuwu-Sense directory not found!${NC}"
    return 1
  fi

  cd "$driver_dir"

  if ! install_kernel_build_dependencies; then
    cd -
    return 1
  fi

  # Apply patches (robustly)
  apply_linuwu_kernel_compat "."

  echo "Compiling drivers..."
  if make clean && make all; then
    handle_secure_boot "src/linuwu_sense.ko"
    
    echo "Installing drivers to system..."
    if make install; then
        echo -e "${GREEN}Linuwu-Sense drivers installed successfully!${NC}"
        cd -
        return 0
    else
        echo -e "${RED}Error: Failed to install Linuwu-Sense drivers (installation step).${NC}"
        cd -
        return 1
    fi
  else
    echo -e "${RED}Error: Failed to compile Linuwu-Sense drivers.${NC}"
    cd -
    return 1
  fi
}

install_daemon() {
  echo -e "${YELLOW}Installing DAMX-Daemon...${NC}"

  if [ ! -d "DAMX-Daemon" ]; then
    echo -e "${RED}Error: DAMX-Daemon directory not found!${NC}"
    echo "Please make sure the script is run from the same directory containing DAMX-Daemon folder."
    pause
    return 1
  fi

  # Create installation directory
  mkdir -p ${INSTALL_DIR}/daemon

  # Copy daemon binary
  cp -f DAMX-Daemon/DAMX-Daemon ${INSTALL_DIR}/daemon/
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

  if [ ! -d "DAMX-GUI" ]; then
    echo -e "${RED}Error: DAMX-GUI directory not found!${NC}"
    echo "Please make sure the script is run from the same directory containing DAMX-GUI folder."
    pause
    return 1
  fi

  # Create installation directory
  mkdir -p ${INSTALL_DIR}/gui

  # Copy GUI files
  cp -rf DAMX-GUI/* ${INSTALL_DIR}/gui/
  chmod +x ${INSTALL_DIR}/gui/DivAcerManagerMax

  # Create icon directory if it doesn't exist
  mkdir -p ${ICON_DIR}

  # Copy icon
  cp -f DAMX-GUI/icon.png ${ICON_DIR}/damx.png

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
  local skip_drivers=$1
  local is_update=$2

  # If this is an update/reinstall, perform cleanup first
  if [ "$is_update" = true ]; then
    echo -e "${BLUE}Performing cleanup before installation...${NC}"
    comprehensive_cleanup
    echo ""
  else
    # For fresh installs, still check for legacy installations
    cleanup_legacy_installation
    echo ""
  fi

  # Create main installation directory
  mkdir -p ${INSTALL_DIR}

  # Install components
  if [ "$skip_drivers" = false ]; then
    install_drivers
    DRIVER_RESULT=$?
  else
    echo -e "${YELLOW}Skipping driver installation as requested.${NC}"
    DRIVER_RESULT=0
  fi

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
    pause
    return 0
  else
    echo -e "${RED}Some components failed to install. Please check the errors above.${NC}"
    pause
    return 1
  fi
}

uninstall() {
  echo -e "${YELLOW}Uninstalling DAMX Suite...${NC}"
  comprehensive_cleanup
  echo -e "${GREEN}DAMX Suite uninstalled successfully!${NC}"
  pause
  return 0
}

# Function to check system compatibility
check_system() {
  echo -e "${BLUE}Checking system compatibility...${NC}"

  # Check if systemd is available
  if ! command -v systemctl &> /dev/null; then
    echo -e "${RED}Error: systemd is required but not found on this system.${NC}"
    return 1
  fi

  # Check if we're on a supported distribution
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "Detected OS: $PRETTY_NAME"
  fi

  echo -e "${GREEN}System compatibility check passed.${NC}"
  return 0
}

main_menu() {
  # Perform initial system check
  if ! check_system; then
    echo -e "${RED}System compatibility check failed. Exiting.${NC}"
    pause
    exit 1
  fi

  while true; do
    print_banner

    echo -e "Please select an option:"
    echo -e "  ${GREEN}1${NC}) Install DAMX Suite (complete)"
    echo -e "  ${GREEN}2${NC}) Install DAMX Suite (without drivers)"
    echo -e "  ${GREEN}3${NC}) Uninstall DAMX Suite"
    echo -e "  ${GREEN}4${NC}) Reinstall/Update DAMX Suite (recommended for upgrades)"
    echo -e "  ${GREEN}5${NC}) Check service status"
    echo -e "  ${GREEN}q${NC}) Quit"
    echo ""

    read -p "Enter your choice [1-5 or q]: " choice

    case $choice in
      1)
        print_banner
        echo -e "${BLUE}Starting complete installation...${NC}"
        perform_install false false
        ;;
      2)
        print_banner
        echo -e "${BLUE}Starting installation without drivers...${NC}"
        perform_install true false
        ;;
      3)
        print_banner
        echo -e "${BLUE}Starting uninstallation...${NC}"
        uninstall
        ;;
      4)
        print_banner
        echo -e "${BLUE}Starting reinstallation/update...${NC}"
        echo -e "${YELLOW}This will completely remove the existing installation before installing the new version.${NC}"
        perform_install false true
        ;;
      5)
        print_banner
        echo -e "${BLUE}Checking DAMX service status...${NC}"
        echo ""
        if systemctl list-unit-files | grep -q ${DAEMON_SERVICE_NAME}; then
          systemctl status ${DAEMON_SERVICE_NAME} --no-pager -l
        else
          echo -e "${YELLOW}DAMX service not found. The suite may not be installed.${NC}"
        fi
        echo ""
        pause
        ;;
      q|Q)
        echo -e "${BLUE}Exiting installer. Goodbye!${NC}"
        exit 0
        ;;
      *)
        echo -e "${RED}Invalid option. Please try again.${NC}"
        sleep 2
        ;;
    esac
  done
}

# Check and elevate privileges if needed
check_root "$@"

# Start the installer
main_menu
exit 0
