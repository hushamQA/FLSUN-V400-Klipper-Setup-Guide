#!/bin/bash
# FLSUN V400 Klipper Auto-Setup Script
# Run this on a fresh Speeder Pad after SSH access.
#
# Usage:
#   scp -r config/ pi@<printer-ip>:~/conf
#   ssh pi@<printer-ip> "TIMEZONE='Region/City' bash ~/conf/setup.sh"
#
# All machine-specific values are read from environment variables so no
# personal data (IP, WiFi, timezone) is stored in this script.
# Unset variables fall back to safe interactive prompts below.

set -e

TIMEZONE="${TIMEZONE:-}"
WIFI_SSID="${WIFI_SSID:-}"
WIFI_PASS="${WIFI_PASS:-}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err() { echo -e "${RED}[-]${NC} $1"; }

if [ "$(whoami)" != "pi" ]; then
    err "Run this as the pi user: ssh pi@<printer-ip>"
    exit 1
fi

echo "=========================================="
echo "  FLSUN V400 Klipper Auto-Setup"
echo "=========================================="

if [ -z "$TIMEZONE" ]; then
    read -rp "Timezone (e.g. Europe/Berlin): " TIMEZONE
fi

#==========================================
# Stage 0: System Preparation
#==========================================
log "Stage 0: System Preparation"

sudo apt update && sudo apt upgrade -y
sudo apt install -y git build-essential python3-dev python3-pip python3-venv \
    libffi-dev libncurses-dev nginx cifs-utils

sudo timedatectl set-timezone "$TIMEZONE"
sudo timedatectl set-ntp true

sudo nmcli radio wifi on
if [ -n "$WIFI_SSID" ] && [ -n "$WIFI_PASS" ]; then
    sudo nmcli device wifi connect "$WIFI_SSID" password "$WIFI_PASS" || true
else
    warn "WIFI_SSID/WIFI_PASS not set — skipping automatic WiFi connect. Connect manually if needed."
fi

#==========================================
# Stage 1: Install Klipper
#==========================================
log "Stage 1: Installing Klipper"

cd ~
if [ ! -d "klipper" ]; then
    git clone https://github.com/Klipper3d/klipper.git
fi
cd klipper
./scripts/install-octopi.sh

#==========================================
# Stage 2: Install Moonraker
#==========================================
log "Stage 2: Installing Moonraker"

cd ~
if [ ! -d "moonraker" ]; then
    git clone https://github.com/Arksine/moonraker.git
fi
cd moonraker
./scripts/install-moonraker.sh

#==========================================
# Stage 3: Install Mainsail
#==========================================
log "Stage 3: Installing Mainsail"

cd ~
if [ ! -d "mainsail" ]; then
    git clone https://github.com/mainsail-crew/mainsail.git
fi

sudo rm -f /etc/nginx/sites-enabled/default
sudo cp ~/conf/system/mainsail-nginx.conf /etc/nginx/sites-enabled/mainsail
sudo nginx -t && sudo systemctl restart nginx

#==========================================
# Stage 4: Install KlipperScreen
#==========================================
log "Stage 4: Installing KlipperScreen"

cd ~
if [ ! -d "KlipperScreen" ]; then
    git clone https://github.com/Guilouz/KlipperScreen-Flsun-Speeder-Pad.git KlipperScreen
fi
cd KlipperScreen
./scripts/KlipperScreen-install.sh

log "Applying sdbus patch for Ubuntu 20.04"
sudo cp ~/conf/system/patch-ks-sdbus.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/patch-ks-sdbus.sh
sudo cp ~/conf/systemd/patch-ks-sdbus.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable patch-ks-sdbus

cp ~/conf/system/ks-post-merge-hook.sh ~/KlipperScreen/.git/hooks/post-merge
chmod +x ~/KlipperScreen/.git/hooks/post-merge

/usr/local/bin/patch-ks-sdbus.sh

#==========================================
# Stage 5: Deploy Config Files
#==========================================
log "Stage 5: Deploying Config Files"

mkdir -p ~/printer_data/config ~/printer_data/gcodes ~/printer_data/logs ~/printer_data/comms

cp ~/conf/printer.cfg ~/printer_data/config/
cp ~/conf/macros.cfg ~/printer_data/config/
cp ~/conf/moonraker.conf ~/printer_data/config/
cp ~/conf/variables.cfg ~/printer_data/config/
cp ~/conf/KlipperScreen.conf ~/printer_data/config/
cp ~/conf/neopixels.cfg ~/printer_data/config/
cp ~/conf/moonraker.asvc ~/printer_data/

warn "printer.cfg contains EXAMPLE calibration values from a different printer."
warn "Run the full calibration sequence (wiki page 4) before printing anything."

#==========================================
# Stage 6: Extensions
#==========================================
log "Stage 6: Installing Extensions"

if [ ! -d ~/klipper_tmc_autotune ]; then
    cd ~
    git clone https://github.com/andrewmcgr/klipper_tmc_autotune.git
fi
ln -sf ~/klipper_tmc_autotune/tmc_autotune.py ~/klipper/klippy/extras/tmc_autotune.py

if [ ! -d ~/moonraker-timelapse ]; then
    cd ~
    git clone https://github.com/mainsail-crew/moonraker-timelapse.git
fi
ln -sf ~/moonraker-timelapse/component/timelapse.py ~/moonraker/moonraker/components/timelapse.py
ln -sf ~/conf/timelapse.cfg ~/printer_data/config/timelapse.cfg

#==========================================
# Stage 7: PolicyKit & Permissions
#==========================================
log "Stage 7: PolicyKit & Permissions"

sudo groupadd -f moonraker-admin
sudo usermod -aG moonraker-admin pi
sudo mkdir -p /etc/polkit-1/localauthority/50-local.d
sudo cp ~/conf/system/10-moonraker.pkla /etc/polkit-1/localauthority/50-local.d/

#==========================================
# Stage 8: MCU Firmware
#==========================================
log "Stage 8: MCU Firmware build config"

mkdir -p ~/klipper
cp ~/conf/klipper-build.config ~/klipper/.config
warn "Firmware is NOT auto-compiled or auto-flashed by this script."
warn "Verify your mainboard/MCU matches klipper-build.config, then run:"
warn "  cd ~/klipper && make clean && make"
warn "  ./scripts/update_mks_robin.py out/klipper.bin out/Robin_nano35.bin   # GD32F303 clone boards only"
warn "Copy the resulting .bin to a FAT32 SD card and power-cycle the printer to flash."

#==========================================
# Stage 9: Restart Services
#==========================================
log "Stage 9: Restarting Services"

sudo systemctl restart nginx
sudo systemctl restart klipper
sudo systemctl restart moonraker
sudo systemctl restart KlipperScreen

echo ""
echo "=========================================="
echo "  Base Installation Complete"
echo "=========================================="
echo ""
log "Klipper: $(systemctl is-active klipper)"
log "Moonraker: $(systemctl is-active moonraker)"
log "KlipperScreen: $(systemctl is-active KlipperScreen)"
echo ""
warn "NEXT STEPS:"
warn "1. Compile and flash firmware (Stage 8 above)"
warn "2. Open Mainsail at http://<printer-ip>"
warn "3. Edit moonraker.conf: set sudo_password to your own device password"
warn "4. Run the calibration sequence in order (wiki page 4):"
warn "   ENDSTOPS_CALIBRATION -> DELTA_CALIBRATION -> BED_LEVELING ->"
warn "   Z_OFFSET_CALIBRATION -> PID_BED_65 -> PID_HOTEND_220"
echo ""
