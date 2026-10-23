# Hauppauge USB-Live2 E1 — Linux DKMS driver

**Version 1.2** adds Linux 7.0 compatibility and full-height analog video capture for the **Hauppauge USB-Live2 Revision E1**, USB ID **2040:c220** (part number 122020 LF).

Verified on Linux Mint 22.3 with kernel `7.0.0-38-generic`: device binding, Composite and S-Video streaming, and OBS picture with player audio. Version 1.2 fixes the green band and bottom green scanline. A five-minute OBS recording decoded without errors or reported encoder/rendering lag.

## Download and install

Download **usblive2-e1-linux7-1.2.tar.gz** from the [v1.2 release](https://github.com/NursePandaz/usblive2-e1-linux7/releases/tag/v1.2). It contains the source, patches and installer; no prebuilt kernel modules are included.

On Linux Mint/Ubuntu, install dependencies:

```bash
sudo apt update
sudo apt install dkms build-essential gcc-13 linux-headers-$(uname -r) v4l-utils
```

Extract the archive and install:

```bash
tar -xzf usblive2-e1-linux7-1.2.tar.gz
cd usblive2-e1-linux7-1.2
sudo bash install.sh
```

The installer builds for the running kernel, installs only `em28xx-dkms/1.2`, and preserves earlier registered versions. It does not unload drivers, reboot, or change boot settings. Existing version 1.2 source is preserved rather than overwritten. Close capture applications before changing drivers.

### Activate

If no em28xx driver is already loaded:

```bash
sudo modprobe em28xx
sudo modprobe em28xx-v4l
v4l2-ctl --list-devices
```

Reconnect the Hauppauge if it was connected before installation. Installing a module does not replace a previously loaded copy: if em28xx was already loaded, activate the new copy through a planned reload of only unused em28xx modules or a normal reboot. Do not unload shared USB audio, webcam or NVIDIA drivers.

Select **Hauppauge USB Live2** by name or its `/dev/v4l/by-id/` link; video numbers can change. Audio uses the existing `snd-usb-audio` driver. The verified system used Secure Boot disabled; systems enforcing module signatures require their normal DKMS signing/enrollment setup.

## OBS setup

Add a **Video Capture Device (V4L2)** source and select the Hauppauge.

| Setting | US NTSC source |
| --- | --- |
| Input | Composite (yellow RCA) or S-Video, matching the connected cable |
| Video standard | **NTSC-M** — select explicitly |
| Pixel format | YUYV |
| Resolution | 720 × 480 |
| Frame rate | 30000/1001 (29.97 fps) |
| Color space/range | Rec.601 / limited, where available |

For interlaced tapes, Yadif 2x deinterlacing with 59.94 fps OBS output can preserve field motion. Use a 4:3 display aspect for standard 4:3 material.

Add **Audio Input Capture (PulseAudio)** and choose **USB-Live2 Audio Analog Stereo**, at **48 kHz stereo**. Connect the red/white audio leads for either video input, and use one recording audio path to avoid echo. Audio was verified through OBS/PulseAudio; this release changes the video driver, not the native USB audio driver.

Black-and-white video or a repeated picture can indicate the wrong input or television standard. Select the actual standard explicitly; PAL material needs its corresponding PAL standard and 720×576/25 fps. The tested capture workflow uses NTSC-M.

## What changed

- Removed obsolete videobuf2 wait callbacks from the E1 patch, preserving queue mutex locking and E1 hardware support.
- Corrected the DKMS patch preparation sequence and a compiler format warning.
- Fixed unsupported standard querying and rejected mixed NTSC/PAL standard masks.
- Disabled raw VBI only on the E1 board to eliminate the bottom scanline defect. Raw VBI/closed-caption capture is unavailable for this board with this fix.

Patches apply in order to clean source during DKMS preparation. **Do not preapply patches in this repository or `/usr/src`.** A direct `make` on clean source does not include the E1 hardware changes. The Makefile uses GCC 13; override `CC` when targeting headers that require a different compiler. `AUTOINSTALL="no"`: after a kernel upgrade, explicitly build/install for that kernel.

## Uninstall and rollback

Close capture applications, then run from the extracted directory:

```bash
sudo bash install.sh --uninstall
```

Or use DKMS directly:

```bash
sudo dkms uninstall -m em28xx-dkms -v 1.2 -k "$(uname -r)"
```

This retains source and loaded modules. To restore a previously registered driver version, install that version for the same kernel with DKMS, then activate it through a planned em28xx-only reload or normal reboot. Keep other hardware drivers intact. The stock driver may leave this E1 revision's video interface unbound.

## Source and licensing

Based on [kakotek/usblive2_e1-driver-dkms](https://github.com/kakotek/usblive2_e1-driver-dkms), whose source derives from Linux 6.16 and Hauppauge mediatree E1 changes. Original copyright notices and per-file license identifiers are retained. Driver sources remain GPL v2; see `COPYING`.

The historical build review and investigation are in `LINUX-7.0.md`, `CAPTURE-TEST-RESULTS.md` and `RUNTIME-FIX.md`. They document the development process; this README describes the version 1.2 release.
