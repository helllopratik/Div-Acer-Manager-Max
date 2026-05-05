#!/bin/bash

# DAMX Remote Installer Script (DEB-based)
# This script downloads and installs the latest DAMX Suite for Acer laptops on Linux
# Usage: curl -sSL https://raw.githubusercontent.com/PXDiv/Div-Acer-Manager-Max/main/scripts/remoteSetup.sh | bash

# Constants
SCRIPT_VERSION="2.0.0"
GITHUB_REPO="PXDiv/Div-Acer-Manager-Max"
TEMP_DIR="/tmp/damx-install-$$"

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
  echo -e "${BLUE}    DAMX Remote Installer v${SCRIPT_VERSION}     ${NC}"
  echo -e "${BLUE}    Acer Laptop WMI Controls for Linux  ${NC}"
  echo -e "${BLUE}==========================================${NC}"
  echo ""
}

check_dependencies() {
  echo -e "${YELLOW}Checking dependencies...${NC}"
  local missing_deps=()
  for cmd in curl jq dpkg apt-get; do
    if ! command -v $cmd &> /dev/null; then
      missing_deps+=("$cmd")
    fi
  done

  if [ ${#missing_deps[@]} -gt 0 ]; then
    echo -e "${YELLOW}Installing missing dependencies: ${missing_deps[*]}${NC}"
    apt-get update && apt-get install -y "${missing_deps[@]}" || {
      echo -e "${RED}Error: Cannot install dependencies automatically.${NC}"
      exit 1
    }
  fi
  echo -e "${GREEN}Dependencies check completed.${NC}"
}

get_latest_release() {
  echo -e "${YELLOW}Fetching latest release information...${NC}"
  local api_url="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
  local release_info

  release_info=$(curl -s "$api_url")
  if [ $? -ne 0 ] || [ -z "$release_info" ]; then
    echo -e "${RED}Error: Failed to fetch release information from GitHub API${NC}"
    return 1
  fi

  RELEASE_NAME=$(echo "$release_info" | jq -r '.name')
  DEB_URL=$(echo "$release_info" | jq -r '.assets[] | select(.name | endswith(".deb")) | .browser_download_url' | head -n 1)

  if [ -z "$DEB_URL" ] || [ "$DEB_URL" = "null" ]; then
    echo -e "${RED}Error: No .deb package found in the latest release${NC}"
    return 1
  fi

  echo -e "${GREEN}Latest release found: $RELEASE_NAME${NC}"
  echo -e "Download URL: $DEB_URL"
  return 0
}

download_and_install_deb() {
  echo -e "${YELLOW}Downloading DAMX DEB package...${NC}"
  mkdir -p "$TEMP_DIR"
  cd "$TEMP_DIR"
  local deb_file="damx.deb"

  if ! curl -L -o "$deb_file" "$DEB_URL"; then
    echo -e "${RED}Error: Failed to download DEB package${NC}"
    return 1
  fi

  echo -e "${YELLOW}Installing DAMX DEB package...${NC}"
  # Install the package. dpkg might fail on missing dependencies, so we run apt-get install -f
  dpkg -i "$deb_file" || apt-get install -f -y

  echo -e "${GREEN}DAMX GUI and Daemon installed successfully!${NC}"
  return 0
}

install_kernel_build_dependencies() {
  echo -e "${YELLOW}Checking kernel build dependencies...${NC}"
  local kernel_release="$(uname -r)"
  apt-get update && apt-get install -y build-essential "linux-headers-${kernel_release}" python3 mokutil openssl
}

apply_linuwu_kernel_compat() {
  local driver_dir="$1"
  local source_file="${driver_dir}/src/linuwu_sense.c"
  if [ ! -f "$source_file" ]; then
    echo -e "${RED}Error: Linuwu-Sense source file not found at ${source_file}${NC}"
    return 1
  fi

  echo -e "${YELLOW}Applying Linuwu-Sense kernel compatibility patch to ${source_file}...${NC}"
  python3 - "$source_file" <<'PY'
from pathlib import Path
import re
import sys

source = Path(sys.argv[1])
text = source.read_text()
changed = False

def re_replace_once(pattern, replacement, description):
    global text, changed
    new_text, count = re.subn(pattern, replacement, text, count=1, flags=re.MULTILINE)
    if count == 0:
        return # Might have already been patched
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
  # Get the actual user home (even if running with sudo)
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
    echo -e "${RED}Could not sign module (missing sign-file or module: $module_to_sign).${NC}"
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
  
  local driver_src=""
  if [ -d "/opt/damx/src/Linuwu-Sense" ]; then
    driver_src="/opt/damx/src/Linuwu-Sense"
  elif [ -d "Linuwu-Sense" ]; then
    driver_src="$(pwd)/Linuwu-Sense"
  fi

  if [ -z "$driver_src" ]; then
    echo -e "${RED}Error: Driver source not found.${NC}"
    return 1
  fi

  install_kernel_build_dependencies
  # Note: The source is already hard-patched in the repo, but we keep this for robustness
  apply_linuwu_kernel_compat "$driver_src"

  cd "$driver_src"
  echo "Compiling drivers..."
  if make clean && make all; then
    echo -e "${GREEN}Linuwu-Sense drivers compiled successfully!${NC}"
    
    # Sign the module BEFORE installing if Secure Boot is on
    handle_secure_boot "$driver_src/src/linuwu_sense.ko"
    
    echo "Installing drivers to system..."
    if make install; then
        echo -e "${GREEN}Linuwu-Sense drivers installed successfully!${NC}"
        return 0
    else
        echo -e "${RED}Error: Failed to install drivers (installation step).${NC}"
        return 1
    fi
  else
    echo -e "${RED}Error: Failed to compile Linuwu-Sense drivers.${NC}"
    return 1
  fi
}

cleanup_temp() {
  if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
  fi
}

main() {
  trap cleanup_temp EXIT
  check_root "$@"
  print_banner

  echo -e "${BLUE}Starting DAMX Remote Installation (DEB mode)${NC}"
  
  check_dependencies
  if ! get_latest_release; then
    echo -e "${RED}Failed to find release. Exiting.${NC}"
    exit 1
  fi

  if ! download_and_install_deb; then
    echo -e "${RED}Failed to install DEB package. Exiting.${NC}"
    exit 1
  fi

  # Now compile the drivers bundled in the DEB
  if ! install_drivers; then
    echo -e "${RED}Driver installation failed.${NC}"
  fi

  echo ""
  echo -e "${GREEN}🎉 DAMX Suite installation process completed!${NC}"
  echo -e "You can now run the GUI using the ${BLUE}DAMX${NC} command or from your application launcher."
}

main "$@"
