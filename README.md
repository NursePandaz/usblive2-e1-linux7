# Hauppauge USB-Live2 E1 — Linux 7.0 DKMS driver

Linux 7.0 compatibility fixes for the **Hauppauge USB-Live2 Revision E1**
analog video capture device, based on
[kakotek/usblive2_e1-driver-dkms](https://github.com/kakotek/usblive2_e1-driver-dkms).

## Current status

**Video driver binding and buffer streaming work. Complete capture and OBS
operation are not yet validated. Live-source testing is in progress.**

| Check | Result |
| --- | --- |
| Build and DKMS installation | Passed on kernel `7.0.0-38-generic` |
| USB `2040:c220` binding | Bound to `em28xx` |
| V4L2 devices | `/dev/video4`, `/dev/vbi0`, `/dev/media2` on the test machine |
| Composite streaming | 300 frames at approximately 29.97 fps |
| S-Video streaming | 150 frames at approximately 30 fps |
| Stop/start and input switching | Passed brief tests |
| Live S-Video signal | Locked; large green band fixed in version 1.1; one bottom scanline still blank |
| USB audio | Enumerated, but capture returned I/O errors |
| OBS recording and audio/video sync | Pending |

Device numbers can change. Select the Hauppauge by name or its stable
`/dev/v4l/by-id/` link rather than assuming `/dev/video4`.

## Tested hardware and system

- Hauppauge USB-Live2, part number **122020 LF**, revision **E1**
- USB vendor/product ID **`2040:c220`**
- Linux Mint **22.3**, x86_64
- Running kernel **`7.0.0-38-generic`**
- Secure Boot disabled
- Video: `em28xx` and `em28xx-v4l`
- Audio: existing `snd-usb-audio` interface

This targets E1 hardware with an EM2828X built-in decoder. Other USB-Live2
revisions and kernels have not been validated by this work.

## Version 1.1: green-band fix

The inherited standard-query handler returned every supported standard when
the built-in decoder had no detection implementation. Capture programs then
selected that mixed mask, causing PAL scaling with NTSC decoder timing. The
second DKMS patch returns ENOTTY for unsupported detection and rejects mixed
525/625-line masks. Live capture now retains NTSC-M and the large green band
is gone. One bottom scanline remains blank. Audio is still under investigation.

## Why the original build failed

The E1 hardware patch added obsolete `vb2_ops.wait_prepare` and `wait_finish`
callbacks to the video and VBI queues. Kernel 7.0 no longer provides those
members or their helper functions.

DKMS copies clean source into a fresh build directory and then applies the
patch listed in `dkms.conf`. Editing callbacks out of `/usr/src` alone did
not work because the patch added them back during every build.

### Changes

- Removed the callback-adding hunks from the E1 patch while retaining its
  USB ID, board definitions, built-in decoder and input/standard changes.
- Preserved both video and VBI queue mutexes. Modern videobuf2 uses the
  queue's `lock` to release and reacquire the mutex while waiting for frames.
- Corrected a 64-bit video-standard diagnostic format warning.
- Made the Makefile resolve its own directory and use the compiler matching
  the tested kernel. Override `CC` when building for a different compiler.
- Set `AUTOINSTALL="no"` to keep future installation deliberate.

Only the configured core, video/VBI and ALSA modules were built. DVB and
remote-control code were not enabled or validated. See [the build and locking
review](LINUX-7.0.md), [initial runtime results](CAPTURE-TEST-RESULTS.md),
and [the version 1.1 investigation](RUNTIME-FIX.md).

## Build

Requires matching kernel headers, DKMS, build tools, and the appropriate compiler.
The tested compiler was `x86_64-linux-gnu-gcc-13`.

**Keep the repository and `/usr/src` source unpatched.** DKMS applies
`patches/USBLive2_Empia.patch`, then
`patches/0002-e1-standard-query.patch` during source preparation. A direct `make` on
unpatched source does not include E1 support.

To build through DKMS, first copy this source into
`/usr/src/em28xx-dkms-1.1`, backing up any existing directory. Include the
Makefile, `dkms.conf`, `em28xx/` and `patches/` directories.

For a fresh registration:

```bash
sudo dkms add -m em28xx-dkms -v 1.1
sudo dkms build -m em28xx-dkms -v 1.1 -k "$(uname -r)"
```

If `em28xx-dkms/1.1` is already registered, inspect `dkms status` and its source
link first; do not add it again or replace an installed build blindly.

Builds passed MODPOST against the running kernel's symbol versions. Missing
`pahole`/`vmlinux` notices only affected optional BTF debugging metadata.

## Install and load

These commands modify the installed driver. Review the build, back up the
previous source, and close capture applications first. Do not unload shared
USB audio, webcam or NVIDIA drivers.

```bash
sudo dkms install -m em28xx-dkms -v 1.1 -k "$(uname -r)"
modinfo -n em28xx
sudo modprobe em28xx
sudo modprobe em28xx-v4l
v4l2-ctl --list-devices
```

The installed path should resolve under `updates/dkms`. If another em28xx
module is already loaded, installation does not replace it in memory; review
its users before considering a targeted reload. No reboot or boot-setting
change was used for this validation. Secure Boot enrollment is outside the
tested setup.

The separate USB audio interface remains with `snd-usb-audio`; do not force
`em28xx-alsa` onto it merely because that module is included in the build.

## OBS settings to verify

Add **Video Capture Device (V4L2)** and choose **Hauppauge USB Live2**.

| Setting | Starting value for a US NTSC source |
| --- | --- |
| Input | Composite (0) or S-Video (1), matching the cable |
| Video standard | NTSC-M |
| Pixel format | YUYV |
| Resolution | 720 × 480 |
| Frame rate | 30000/1001, approximately 29.97 fps |
| Color space/range | Rec.601 / limited, where selectable |
| Deinterlacing | Try Yadif 2x for interlaced material; verify field order |

For audio, select **USB-Live2 Audio Analog Stereo** in an **Audio Input
Capture (PulseAudio)** source and use **48 kHz stereo**. Avoid duplicate audio
paths. S-Video needs separate red/white audio cables.

These are starting settings, not a claim of successful end-to-end capture.
Audio currently fails direct ALSA recording, including with video streaming.
It must be investigated with a playing source before OBS audio can be marked
working. Standard autodetection is deliberately unsupported by version 1.1;
select the actual NTSC/PAL standard explicitly.

[OBS video capture documentation](https://obsproject.com/kb/video-capture-sources)

## Next tests

1. Connect a known-good playing NTSC source with video and red/white audio.
2. Verify picture, signal lock and motion on each connected input.
3. Resolve the audio I/O error and confirm real stereo samples.
4. Record in OBS, verify field order, cadence and audio/video synchronization.
5. Test longer captures, stop/start and disconnect handling.

## Rollback

Close capture applications, then uninstall only this package for the target kernel:

```bash
sudo dkms uninstall -m em28xx-dkms -v 1.1 -k "$(uname -r)"
```

If necessary, unload only unused em28xx modules in dependency order and restore
the saved source. Do not unload shared webcam/audio drivers or modify NVIDIA.
The stock driver may leave E1 video unbound again, matching the original state.
Uninstalling the package does not by itself unload modules already in memory.

## Source and licensing

The upstream repository describes its source as copied from Linux 6.16, with
E1 support adapted from the Hauppauge mediatree PPA's
`linux_6.11.0-17250128.0+mediatree+hauppauge.diff.gz`.

- [Original DKMS project](https://github.com/kakotek/usblive2_e1-driver-dkms)
- [Hauppauge PPA source publication](https://launchpad.net/~b-rad/+archive/ubuntu/kernel+mediatree+hauppauge/+sourcepub/16956120/+listing-archive-extra)

Retain original copyright notices and per-file license identifiers. This work
does not relicense the Linux driver sources; the original project identifies
the driver as GPL v2.
