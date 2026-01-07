#!/usr/bin/env bash

set -e

echo "=== DAMX / Linuwu Sense Secure Boot Fix ==="

# -------- BASIC CHECKS --------
if [[ $EUID -ne 0 ]]; then
  echo "Please run with sudo:"
  echo "sudo $0"
  exit 1
fi

USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
KEYDIR="$USER_HOME/module-signing"

echo "[+] User home: $USER_HOME"

# -------- CHECK SECURE BOOT --------
SB_STATE=$(mokutil --sb-state 2>/dev/null || true)
echo "[+] Secure Boot status:"
echo "$SB_STATE"

# -------- CREATE KEY IF MISSING --------
mkdir -p "$KEYDIR"
cd "$KEYDIR"

if [[ ! -f MOK.priv || ! -f MOK.pem ]]; then
  echo "[+] Creating MOK key pair..."
  openssl req -new -x509 -newkey rsa:2048 \
    -keyout MOK.priv \
    -out MOK.pem \
    -nodes -days 36500 \
    -subj "/CN=Linuwu Sense Module Signing/"
else
  echo "[=] MOK key already exists"
fi

# -------- CONVERT TO DER --------
if [[ ! -f MOK.der ]]; then
  echo "[+] Converting PEM to DER..."
  openssl x509 -in MOK.pem -outform DER -out MOK.der
fi

# -------- ENROLL KEY IF NOT ENROLLED --------
if ! mokutil --list-enrolled | grep -q "Linuwu Sense Module Signing"; then
  echo "[!] MOK key not enrolled"
  echo "[!] Importing key (YOU MUST REBOOT AND ENROLL)"
  mokutil --import MOK.der
  echo
  echo "==========================================="
  echo "REBOOT REQUIRED"
  echo "On reboot:"
  echo "  → Enroll MOK"
  echo "  → Enter password"
  echo "  → Boot normally"
  echo "Then re-run this script once more."
  echo "==========================================="
  exit 0
else
  echo "[=] MOK key already enrolled"
fi

# -------- FIND REAL MODULE --------
echo "[+] Locating installed linuwu_sense module..."
MODULE_PATH=$(modinfo linuwu_sense 2>/dev/null | awk '/filename:/ {print $2}')

if [[ -z "$MODULE_PATH" || ! -f "$MODULE_PATH" ]]; then
  echo "[!] linuwu_sense module not found"
  exit 1
fi

echo "[+] Module path: $MODULE_PATH"

# -------- SIGN MODULE --------
KDIR="/lib/modules/$(uname -r)/build"
SIGNFILE="$KDIR/scripts/sign-file"

if [[ ! -x "$SIGNFILE" ]]; then
  echo "[!] sign-file script not found"
  exit 1
fi

echo "[+] Signing module..."
"$SIGNFILE" sha256 "$KEYDIR/MOK.priv" "$KEYDIR/MOK.pem" "$MODULE_PATH"

# -------- REFRESH + LOAD --------
echo "[+] Updating module dependencies..."
depmod -a

echo "[+] Loading module..."
modprobe linuwu_sense

# -------- DAMX DAEMON --------
echo "[+] Restarting DAMX daemon (if present)..."
systemctl restart damx-daemon 2>/dev/null || true
systemctl enable damx-daemon 2>/dev/null || true

# -------- VERIFICATION --------
echo
echo "=== Verification ==="
modinfo linuwu_sense | grep signer || true
lsmod | grep linuwu || true
dmesg | tail -n 10

echo
echo "=== DONE ==="
echo "If no errors above, DAMX should work correctly."

