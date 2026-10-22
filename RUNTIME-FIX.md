# E1 capture investigation, October 22, 2026

## Confirmed video cause

A direct ioctl trace proves v4l2-ctl calls VIDIOC_QUERYSTD before streaming.
The E1 patch has no decoder subdevice implementing querystd, but the inherited
handler returns success without modifying the caller's V4L2_STD_ALL value.
v4l2-ctl then calls VIDIOC_S_STD with 0xffffff. norm_maxh sees the PAL bits
and assumes 576 lines, while the E1 decoder setup sees NTSC bits and selects
525/60. A 480-line output is consequently scaled to about 400 delivered lines.

With explicit NTSC-M, format set afterwards and --stream-no-query, 150 frames
were captured and the broad green band disappeared. Tested frames had one
remaining empty bottom scanline; that edge behavior is not yet resolved.
This is not a crop or fabricated fill operation.

PATCH[1], applied after the existing E1 hardware patch, makes built-in decoder
QUERYSTD return ENOTTY until actual signal-standard detection is implemented.
It also rejects masks that mix 525/60 and 625/50 families. External decoder
boards keep their existing behavior. Explicit PAL/NTSC selection is required.

Direct and isolated DKMS builds for kernel 7.0.0-38-generic succeeded.
The isolated build attempted to sign with the host's root-only key and could
not access it; compilation and MODPOST passed. A root DKMS installation will
use the existing key as before. No key/boot settings changed.

## Audio evidence

Direct ALSA capture still returns EIO with correct NTSC video already running.
A root read-only register snapshot reported AUDIO_SRC (0x0e)=0x00 and
XCLK (0x0f)=0x07. The standard em28xx definitions identify Line In as 0x80 in
AUDIO_SRC bits 7:6 and audio-unmute as XCLK bit 7. The E1 patch classifies
EM2828X as having no bridge audio and bypasses normal audio setup. A reversible
probe is needed to establish whether routing/unmute explains capture failure
before committing an audio change. Shared snd-usb-audio and webcam drivers
must not be unloaded.

## Rollback after a future 1.1 installation

Keep the installed 1.0 DKMS build. Close capture applications, uninstall 1.1
for this exact kernel, reinstall 1.0 using DKMS, and reload only the unused
em28xx-v4l extension. Core code is unchanged by the video-only patch.
Never force-remove a module with active users. Do not reboot or alter NVIDIA,
webcam, snd-usb-audio or boot settings.

## Installed verification

Version 1.1 was installed and the video extension reloaded. The loaded and
installed extension srcversion match. Ordinary v4l2-ctl capture (without
--stream-no-query) delivered 150 frames, retained NTSC-M (0x1000), and held
signal lock. The large band is gone; only scanline 479 remained entirely zero
in inspected frames. QUERYSTD returns ENOTTY and a mixed 0xffffff S_STD returns
EINVAL, as intended. DKMS reports 1.1 installed and 1.0 built for rollback;
NVIDIA remains installed and the webcam retains its nodes.

The temporary audio routing test did not change the readback of 0x0e/0x0f and
produced no samples. Therefore the legacy register interpretation is not a
validated E1 audio diagnosis, and no speculative audio patch was applied.
USB monitoring shows successful isochronous audio completions with zero-length
payloads on endpoint 0x83; ALSA receives no data and eventually returns EIO.
An initial reset-isolation attempt automatically rebound em28xx, so it cannot
establish that the failure is independent of video initialization. Its first
video-open restoration check was too early, but video binding returned and
S-Video/NTSC settings were restored. The corrected test checks isolation and
waits for the asynchronously registered video node before restoring settings.

The corrected isolation test kept interface 0 unauthorized/unbound during
capture, and audio still returned EIO with zero PCM bytes. Reauthorization
alone did not rebind this USB interface; an explicit bind restored it, and
S-Video/NTSC-M signal lock was verified afterwards. That restoration issue
is corrected in the diagnostic. A USB reset is not a physical power cycle,
so this result does not exclude persistent device firmware state.

Root DKMS 1.1 installation successfully signed the modules with the existing
key. No key or Secure Boot changes were required.

Rollback commands (close Hauppauge capture applications first):

    sudo dkms uninstall -m em28xx-dkms -v 1.1 -k 7.0.0-38-generic
    sudo dkms install -m em28xx-dkms -v 1.0 -k 7.0.0-38-generic --force
    sudo rmmod em28xx_v4l
    sudo modprobe em28xx-v4l

Use rmmod for this single extension rather than recursively removing its
shared module dependencies. Version 1.0 restores the prior green-band behavior.

The exclusive USB Audio Class probe released only the Hauppauge audio
interfaces, explicitly claimed interface 2, and tested GET_CUR/SET_CUR at
48000 Hz. All requests returned EPIPE, consistent with the advertised absence
of sample-rate control. The original nonexclusive attempt returned EBUSY and
was not evidence about device support. The audio driver was restored and
capture again produced zero bytes. No rate-control quirk was added.

## Version 1.2: final-scanline fix

A controlled A/B capture compared disable_vbi=0 and disable_vbi=1 on the same
S-Video/NTSC source, with OBS closed. Both delivered 60 frames. Frames 10, 30,
and 50 had row 479 entirely zero with raw VBI enabled; with raw VBI disabled,
none of the 480 rows was entirely zero and the visible green edge disappeared.
The test restored the original module parameter afterwards.

PATCH[2] disables raw VBI only for EM2828X_BOARD_HAUPPAUGE_USB_LIVE2. This avoids
the generic VSTART=2 video offset and raw-VBI stream path on this E1 board.
Raw VBI/closed-caption data capture and /dev/vbi0 are deliberately unavailable
for E1 with this fix; other em28xx boards retain their prior support. The VBI
queue is not initialized when there is no VBI device/queue mutex. The video
queue mutex and completed-buffer spinlock are unchanged. No image data is
cropped, synthesized or recolored to hide the defect.

The user confirmed audio works in OBS after their adjustments. A recording
from that same PulseAudio/PipeWire source completed successfully for 8.0204
seconds at stereo 48000 Hz with varying audio in every measured second.
No audio driver change was committed: direct ALSA startup and restart
reliability remain separate limitations to validate. OBS settings were not
edited by the driver investigation.

To revert version 1.2 (close capture applications first), uninstall only 1.2
for kernel 7.0.0-38-generic, reinstall retained 1.1 with --force, then rmmod
em28xx_v4l and modprobe em28xx-v4l. This restores the previous one-line edge
and E1 VBI behavior. No reboot or shared driver removal is required.

## Installed version 1.2 verification

Root DKMS build/sign/install passed for 7.0.0-38-generic. The loaded extension's
srcversion matches the installed module (32453594F8A0D8FEA5509F4). The global
disable_vbi parameter is still 0, confirming that this is an E1 board quirk.
The E1 now registers /dev/video4 and /dev/media2 without a raw VBI node.
An ordinary 150-frame NTSC/S-Video capture returned exit 0. Every scanline in
all 145 frames checked after five startup frames contained data; no empty
bottom row was found. This is full 720x480 YUYV data, not an OBS crop.
Version 1.0 and 1.1 DKMS builds remain available for rollback. NVIDIA remains
installed and the Lenovo webcam keeps /dev/video0 through /dev/video3.

Final user verification: after reopening OBS, the user confirmed “Line gone;
audio works.” Their OBS tweaks were preserved. No additional audio kernel
patch was applied. Standalone ALSA initialization remains outside the
verified OBS workflow.
