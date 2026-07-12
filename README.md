# FLSUN V400 — Config Files

Ready-to-copy configuration, service, and system files matching the [wiki guide](../../wiki). Use this folder for a faster setup instead of typing every file out by hand from the wiki pages.

> ⚠️ These files were captured from one specific FLSUN V400 build (GD32F303 clone mainboard, Ubuntu 20.04 Speeder Pad). Anything mechanically specific to that unit — calibration numbers in `printer.cfg`, the exact mainboard/MCU in `klipper-build.config` — is an **example, not a value to copy blindly**. See the warnings inside each file.

## Quick Start

```bash
# 1. Copy this folder to the printer
scp -r config/ pi@<printer-ip>:~/conf

# 2. Run the setup script (installs Klipper/Moonraker/Mainsail/KlipperScreen,
#    deploys these config files, applies the sdbus patch and PolicyKit rules)
ssh pi@<printer-ip> "TIMEZONE='Region/City' bash ~/conf/setup.sh"

# 3. Compile and flash firmware — NOT automated, see setup.sh output for the exact commands.
#    Verify your mainboard/MCU matches klipper-build.config before flashing.

# 4. Edit ~/printer_data/config/moonraker.conf and set your own sudo_password
```

For the full explanation of every step, see the [wiki](../../wiki) — this folder is the copy-paste companion to it, not a replacement.

## Files reference

### Config files (deployed to `~/printer_data/config/`)

| File | Description |
|------|-------------|
| `printer.cfg` | Main printer config. Calibration block at the bottom is an **example only** — run your own calibration (wiki page 4) |
| `macros.cfg` | All G-code macros (START_PRINT, PAUSE, RESUME, calibration shortcuts, etc.) |
| `moonraker.conf` | Moonraker API server config — set your own `sudo_password` before use |
| `KlipperScreen.conf` | KlipperScreen UI config (preheat presets, LED menu entries) |
| `neopixels.cfg` | NeoPixel LED macros and temperature/progress display templates |
| `timelapse.cfg` | Timelapse extension macros (upstream file from mainsail-crew, GPLv3) |
| `variables.cfg` | Saved variables — Z persistence intentionally disabled for safety |
| `moonraker.asvc` | Allowed services list for Moonraker |

### systemd/ (deployed to `/etc/systemd/system/`)

| File | Description |
|------|-------------|
| `klipper.service` | Klipper systemd unit |
| `moonraker.service` | Moonraker systemd unit |
| `KlipperScreen.service` | KlipperScreen systemd unit |
| `patch-ks-sdbus.service` | Runs the sdbus compatibility patch before KlipperScreen starts |

### system/

| File | Destination | Description |
|------|-------------|-------------|
| `mainsail-nginx.conf` | `/etc/nginx/sites-enabled/mainsail` | Nginx reverse proxy for Mainsail + Moonraker API |
| `10-moonraker.pkla` | `/etc/polkit-1/localauthority/50-local.d/` | PolicyKit rules for restart/shutdown from Mainsail |
| `patch-ks-sdbus.sh` | `/usr/local/bin/` | Patches KlipperScreen for libsystemd 245 (Ubuntu 20.04) compatibility |
| `ks-post-merge-hook.sh` | `~/KlipperScreen/.git/hooks/post-merge` | Re-applies the sdbus patch after every KlipperScreen update |

### Other

| File | Description |
|------|-------------|
| `klipper-build.config` | `make menuconfig` output for a GD32F303 clone board reporting as STM32F103. Copy to `~/klipper/.config` before `make` — **verify against your own mainboard first** |
| `setup.sh` | Automated install script — installs the full stack and deploys every file above |

## Not included here — on purpose

| Not included | Why |
|---|---|
| Precompiled firmware `.bin` | Firmware is tied to one exact mainboard/MCU revision and its encryption. Flashing the wrong binary onto a different board revision can brick it. Compile your own from `klipper-build.config` after verifying your board (see Installation §6 in the wiki) |
| WiFi/network export files | Contain a real SSID and connection UUID specific to one network — not portable or useful to another user |

## Calibration values shown in `printer.cfg`

The auto-generated `SAVE_CONFIG` block is kept as a reference for what a completed block looks like, not as a value to copy:

- Delta radius, arm lengths, tower angles, endstop positions — unique per-unit mechanical measurements
- Probe Z-offset — unique to your probe and nozzle
- Input shaper frequencies — unique to your frame/belt/mass characteristics
- Bed mesh — unique to your bed's physical surface

Run the full sequence in [4. Calibration](../../wiki/04-Calibration) to generate your own.
