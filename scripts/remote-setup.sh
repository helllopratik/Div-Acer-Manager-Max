#!/bin/bash

# Constants
SCRIPT_VERSION="0.7.10-1"
INSTALL_DIR="/opt/damx"
BIN_DIR="/usr/local/bin"
SYSTEMD_DIR="/etc/systemd/system"
DAEMON_SERVICE_NAME="damx-daemon.service"
DESKTOP_FILE_DIR="/usr/share/applications"
ICON_DIR="/usr/share/icons/hicolor/256x256/apps"
LINUWU_SENSE_REPO="0x7375646F/Linuwu-Sense"
DAMX_REPO="PXDiv/Div-Acer-Manager-Max"

# Legacy paths for cleanup (uppercase naming convention)
LEGACY_INSTALL_DIR="/opt/DAMX"
LEGACY_DAEMON_SERVICE_NAME="DAMX-Daemon.service"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

pause() {
  echo -e "${BLUE}Press any key to continue...${NC}"
  read -n 1 -s -r
}

check_root() {
  if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}This script requires root privileges.${NC}"
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
  echo -e "${BLUE}      DAMX Suite Installer v${SCRIPT_VERSION}        ${NC}"
  echo -e "${BLUE}   Acer Laptop WMI Controls for Linux     ${NC}"
  echo -e "${BLUE}==========================================${NC}"
  echo ""
}

cleanup_legacy_installation() {
  echo -e "${YELLOW}Checking for legacy installations...${NC}"
  local cleanup_performed=false

  if [ -f "${SYSTEMD_DIR}/${LEGACY_DAEMON_SERVICE_NAME}" ]; then
    echo -e "${BLUE}Found legacy service file: ${LEGACY_DAEMON_SERVICE_NAME}${NC}"
    if systemctl is-active --quiet ${LEGACY_DAEMON_SERVICE_NAME} 2>/dev/null; then
      echo "Stopping legacy service..."
      systemctl stop ${LEGACY_DAEMON_SERVICE_NAME}
    fi
    if systemctl is-enabled --quiet ${LEGACY_DAEMON_SERVICE_NAME} 2>/dev/null; then
      echo "Disabling legacy service..."
      systemctl disable ${LEGACY_DAEMON_SERVICE_NAME}
    fi
    echo "Removing legacy service file..."
    rm -f "${SYSTEMD_DIR}/${LEGACY_DAEMON_SERVICE_NAME}"
    cleanup_performed=true
  fi

  if [ -d "${LEGACY_INSTALL_DIR}" ]; then
    echo -e "${BLUE}Found legacy installation directory: ${LEGACY_INSTALL_DIR}${NC}"
    echo "Removing legacy installation directory..."
    rm -rf "${LEGACY_INSTALL_DIR}"
    cleanup_performed=true
  fi

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

  if [ "$cleanup_performed" = true ]; then
    echo "Reloading systemd daemon configuration..."
    systemctl daemon-reload
    echo -e "${GREEN}Legacy installation cleanup completed.${NC}"
  else
    echo -e "${GREEN}No legacy installations found.${NC}"
  fi

  return 0
}

comprehensive_cleanup() {
  echo -e "${YELLOW}Performing comprehensive cleanup...${NC}"

  if systemctl is-active --quiet ${DAEMON_SERVICE_NAME} 2>/dev/null; then
    echo "Stopping current DAMX-Daemon service..."
    systemctl stop ${DAEMON_SERVICE_NAME}
  fi

  if systemctl is-enabled --quiet ${DAEMON_SERVICE_NAME} 2>/dev/null; then
    echo "Disabling current DAMX-Daemon service..."
    systemctl disable ${DAEMON_SERVICE_NAME}
  fi

  if [ -f "${SYSTEMD_DIR}/${DAEMON_SERVICE_NAME}" ]; then
    echo "Removing current service file..."
    rm -f "${SYSTEMD_DIR}/${DAEMON_SERVICE_NAME}"
  fi

  cleanup_legacy_installation

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

  systemctl daemon-reload

  echo -e "${GREEN}Comprehensive cleanup completed.${NC}"
  return 0
}

download_latest_release() {
  echo -e "${YELLOW}Fetching latest DAMX release info from GitHub...${NC}" >&2
  local api_url="https://api.github.com/repos/${DAMX_REPO}/releases/latest"
  local release_json
  if command -v curl &> /dev/null; then
    release_json=$(curl -sSL "${api_url}")
  elif command -v wget &> /dev/null; then
    release_json=$(wget -qO- "${api_url}")
  else
    echo -e "${RED}curl or wget required to fetch release info.${NC}" >&2
    return 1
  fi

  local tar_url
  tar_url=$(echo "$release_json" | grep 'browser_download_url' | grep 'DAMX-.*\.tar\.xz' | head -n1 | cut -d '"' -f 4)
  if [ -z "$tar_url" ]; then
    echo -e "${RED}No DAMX-<tag>.tar.xz asset found in latest release!${NC}" >&2
    return 1
  fi

  local file_name
  file_name=$(basename "$tar_url")
  if [ -f "$file_name" ]; then
    echo "$file_name"
    return 0
  else
    if command -v curl &> /dev/null; then
      curl -Lf --retry 3 -o "$file_name" "$tar_url"
    else
      wget -qO "$file_name" "$tar_url"
    fi
    if [ $? -ne 0 ]; then
      echo -e "${RED}Failed to download $file_name${NC}" >&2
      return 1
    fi
    echo "$file_name"
    return 0
  fi
}

extract_release() {
  local tarball="$1"
  local target_dir="$2"
  echo -e "${YELLOW}Extracting $tarball...${NC}"
  tar -xJf "$tarball" -C "$target_dir"
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

clone_and_install_linuwu_sense() {
  echo -e "${YELLOW}Cloning and installing Linuwu-Sense drivers...${NC}"

  if ! command -v git &> /dev/null; then
    echo -e "${YELLOW}Installing git...${NC}"
    if command -v apt-get &> /dev/null; then
      apt-get update && apt-get install -y git
    elif command -v dnf &> /dev/null; then
      dnf install -y git
    elif command -v yum &> /dev/null; then
      yum install -y git
    elif command -v pacman &> /dev/null; then
      pacman -S --noconfirm --needed git
    elif command -v zypper &> /dev/null; then
      zypper install -y git
    else
      echo -e "${RED}Error: git is required to clone Linuwu-Sense.${NC}"
      pause
      return 1
    fi
  fi

  rm -rf Linuwu-Sense
  if ! git clone --depth=1 "https://github.com/${LINUWU_SENSE_REPO}.git"; then
    echo -e "${RED}Failed to clone Linuwu-Sense repo!${NC}"
    pause
    return 1
  fi

  cd Linuwu-Sense

  if ! install_kernel_build_dependencies; then
    cd ..
    pause
    return 1
  fi

  if ! apply_linuwu_kernel_compat "."; then
    cd ..
    pause
    return 1
  fi

  if make clean && make && make install; then
    cd ..
    echo -e "${GREEN}Linuwu-Sense drivers installed successfully!${NC}"
    return 0
  else
    cd ..
    echo -e "${RED}Error: Failed to install Linuwu-Sense drivers${NC}"
    pause
    return 1
  fi
}

install_daemon() {
  echo -e "${YELLOW}Installing DAMX-Daemon...${NC}"

  if [ ! -d "DAMX-Daemon" ]; then
    echo -e "${RED}Error: DAMX-Daemon directory not found!${NC}"
    pause
    return 1
  fi

  mkdir -p ${INSTALL_DIR}/daemon
  cp -f DAMX-Daemon/DAMX-Daemon ${INSTALL_DIR}/daemon/
  chmod +x ${INSTALL_DIR}/daemon/DAMX-Daemon

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

  systemctl daemon-reload
  systemctl enable ${DAEMON_SERVICE_NAME}
  systemctl start ${DAEMON_SERVICE_NAME}

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
    pause
    return 1
  fi

  mkdir -p ${INSTALL_DIR}/gui
  cp -rf DAMX-GUI/* ${INSTALL_DIR}/gui/
  chmod +x ${INSTALL_DIR}/gui/DivAcerManagerMax

  mkdir -p ${ICON_DIR}
  cp -f DAMX-GUI/icon.png ${ICON_DIR}/damx.png

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

  cat > ${BIN_DIR}/DAMX << EOL
#!/bin/bash
${INSTALL_DIR}/gui/DivAcerManagerMax "\$@"
EOL
  chmod +x ${BIN_DIR}/DAMX

  echo -e "${GREEN}DAMX-GUI installed successfully!${NC}"
  return 0
}

prepare_and_extract_release() {
  # Download latest release if not present
  local tarball=""
  for file in DAMX-*.tar.xz; do
    if [ -f "$file" ]; then
      tarball="$file"
      break
    fi
  done
  if [ -z "$tarball" ]; then
    tarball=$(download_latest_release 2>/dev/null)
    if [ -z "$tarball" ] || [ ! -f "$tarball" ]; then
      echo -e "${RED}Could not obtain DAMX release archive.${NC}"
      pause
      return 1
    fi
  fi

  # Extract to temp dir
  local temp_dir="damx_installer_temp"
  rm -rf "$temp_dir"
  mkdir -p "$temp_dir"
  extract_release "$tarball" "$temp_dir"
  rm -rf DAMX-GUI DAMX-Daemon
  mv "$temp_dir/DAMX-GUI" .
  mv "$temp_dir/DAMX-Daemon" .
  rm -rf "$temp_dir"
  echo -e "${GREEN}Release extracted and prepared.${NC}"
}

perform_install() {
  local skip_drivers=$1
  local is_update=$2

  if [ "$is_update" = true ]; then
    echo -e "${BLUE}Performing cleanup before installation...${NC}"
    comprehensive_cleanup
    echo ""
  else
    cleanup_legacy_installation
    echo ""
  fi

  mkdir -p ${INSTALL_DIR}

  prepare_and_extract_release || return 1

  # Install components
  if [ "$skip_drivers" = false ]; then
    clone_and_install_linuwu_sense
    DRIVER_RESULT=$?
  else
    echo -e "${YELLOW}Skipping driver installation as requested.${NC}"
    DRIVER_RESULT=0
  fi

  install_daemon
  DAEMON_RESULT=$?

  install_gui
  GUI_RESULT=$?

  if [ $DRIVER_RESULT -eq 0 ] && [ $DAEMON_RESULT -eq 0 ] && [ $GUI_RESULT -eq 0 ]; then
    echo -e "${GREEN}DAMX Suite installation completed successfully!${NC}"
    echo -e "You can now run the GUI using the ${BLUE}DAMX${NC} command or from your application launcher."
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

check_system() {
  echo -e "${BLUE}Checking system compatibility...${NC}"

  if ! command -v systemctl &> /dev/null; then
    echo -e "${RED}Error: systemd is required but not found on this system.${NC}"
    return 1
  fi

  if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "Detected OS: $PRETTY_NAME"
  fi

  echo -e "${GREEN}System compatibility check passed.${NC}"
  return 0
}

main_menu() {
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

check_root "$@"
main_menu
exit 0
