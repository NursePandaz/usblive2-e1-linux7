# Hauppauge E1 runtime results

Installed em28xx-dkms/1.0 on 7.0.0-38-generic. Kernel logs identify USB
2040:c220, model 122020, revision E1, EM2828X. Interface 0 binds to em28xx;
em28xx_v4l is loaded. Installed module resolves to updates/dkms.

Video node: /dev/video4, with /dev/vbi0 and /dev/media2.
Stable video link: /dev/v4l/by-id/usb-HCW_USB-Live2_Audio_0014465645-video-index0.
NVIDIA and uvcvideo remain loaded. No webcam/NVIDIA/boot configuration changes.

## Video tests without an input source

- NTSC-M accepted; YUYV 720x480 interlaced; 30000/1001 fps reported.
- Composite: initial 150-frame test passed, followed by a 300-frame test
  returning exit 0 and approximately 29.97 fps.
- S-Video: 150 frames, exit 0, approximately 30 fps.
- Switching inputs and capture restart completed without a queue deadlock.
- Restored composite input. Last frame dimensions remain 720x480/YUYV.
- No source playing; lock_status=0. Picture quality, actual input signal,
  deinterlacing field order, sync and long capture stability are unverified.
- Separate G_STD calls returned all standard bits despite S_STD accepting
  NTSC-M and reporting NTSC cadence while configuring. Select NTSC explicitly
  in OBS and verify with a source; automatic standard detection is unvalidated.

## Audio: unresolved

snd-usb-audio still owns the audio function. PipeWire exposes
USB-Live2 Audio Analog Stereo at s16le, stereo, 48000 Hz, Line In, unmuted.
Direct ALSA capture from hw:CARD=Audio,DEV=0 opened, but returned I/O error
without PCM samples. Repeated both with video stopped and video streaming.
Recorded WAV outputs contained only headers, so they are not usable recordings.
The relevant kernel log did not explain this error. Enumeration alone is not
proof of working audio. Retest with a playing source and red/white audio leads;
if the error persists, investigate the USB audio stream/clock and E1 hardware
initialization rather than treating the driver as complete.

## OBS settings to test with a source

Add Video Capture Device (V4L2), choose Hauppauge USB Live2 (/dev/video4),
input Composite (0) or S-Video (1) matching the cable, standard NTSC-M,
YUYV, 720x480, 29.97 fps. For interlaced material try Yadif 2x and verify
field order with motion; use 59.94 output if preserving field cadence.
Use Rec.601/limited range where selectable and check against a known image.

Add Audio Input Capture (PulseAudio), choose USB-Live2 Audio Analog Stereo,
with OBS at 48 kHz. Avoid duplicating this audio through a second source.
Audio capture is not yet validated and may fail until the underlying issue
is resolved. S-Video carries no audio; connect separate red/white audio leads.

OBS documentation: https://obsproject.com/kb/video-capture-sources

## Rollback

Original registered source backup:
/usr/src/em28xx-e1-backup.0pa0NAfT/registered-source

Uninstall only this package/kernel if rollback is needed:

    sudo dkms uninstall -m em28xx-dkms -v 1.0 -k 7.0.0-38-generic

Close capture applications before unloading only the em28xx modules. Restore
source from the backup if reverting source changes; do not unload shared USB
audio or webcam drivers or change NVIDIA. See LINUX-7.0.md for details.
