# USB-Live2 E1: Linux 7.0 build review

Validated on PeterPC, kernel 7.0.0-38-generic, x86_64.

## Root cause and changes

DKMS 1.0 registration points to /usr/src/em28xx-dkms-1.0. Its build routine
removes the previous build directory, copies source afresh, then applies each
PATCH entry in dkms.conf with patch -p1. The E1 patch itself reintroduced
wait_prepare and wait_finish in both video and VBI vb2_ops. Thus editing those
callbacks out of the source did not survive source preparation.

Removed ONLY the callback-adding hunks from the E1 patch. USB ID 2040:c220,
EM2828X board/chip definitions, built-in decoder, mux, standard programming,
EEPROM transfer mode and other hardware changes remain. Fixed the patch's
64-bit v4l2_std_id diagnostic (%llX with explicit cast and newline). These
were the only API/compiler problems found compiling all three configured
modules against the installed kernel headers. Unbuilt DVB/IR code is not
validated or enabled.

Makefile now uses its own absolute directory for external-module builds and
uses the same compiler executable as this kernel. Override CC on the make
command line when targeting a kernel built with a different compiler.
Disabled AUTOINSTALL to honor manual installation approval. No boot settings,
webcam configuration, NVIDIA registration, installed modules, or loaded
modules were changed by validation.

## Buffer locking review

The installed include/media/videobuf2-core.h documents q->lock as the mutex
released while waiting for a buffer and reacquired afterwards. This replaces
the removed callbacks. The original source already omits those callbacks.

em28xx_v4l2_init initializes vb_queue_lock and vb_vbi_queue_lock and assigns
them to vb_vidq.lock and vb_vbiq.lock through the video_device queue pointers,
before em28xx_vb2_setup initializes the queues. Both assignments remain intact.
Queue ioctls use the vb2_ioctl helpers, file read/poll/mmap use vb2 helpers,
and completed-buffer lists retain dev->slock spinlock protection. No mutex
or spinlock was removed. This is a static review; blocking dequeue, streaming,
and unplug behavior still need hardware runtime testing after approval.

## Verification

Both a clean manual build and an isolated DKMS add/build passed. The latter
used separate workspace source/DKMS trees and did not change the live DKMS
registration. DKMS applied the corrected E1 patch and produced em28xx.ko,
em28xx-v4l.ko and em28xx-alsa.ko. MODPOST passed symbol/version checks against
the running kernel's Module.symvers. Module vermagic matches the running
kernel and em28xx contains the USB 2040:c220 alias.

No C compiler warnings remain. Missing pahole/version and missing vmlinux
notices mean optional BTF debug metadata could not be generated. They do not
indicate a kernel ABI mismatch. Modules are unsigned; Secure Boot is disabled
per the user. Building proves compatibility with these headers, not successful
hardware capture. No modules have been installed or loaded.

## Installation plan — only after explicit approval

Back up the existing /usr/src/em28xx-dkms-1.0 directory before replacing it
with this clean, unpatched source. Preserve the existing repository changes
with its exported patch and backup. Build only em28xx-dkms/1.0 for the named
kernel, then install that exact version/kernel. Do not run a global DKMS
update, modify NVIDIA, unload snd-usb-audio, or change webcam settings.

    sudo dkms build -m em28xx-dkms -v 1.0 -k 7.0.0-38-generic
    sudo dkms install -m em28xx-dkms -v 1.0 -k 7.0.0-38-generic

Inspect existing em28xx users before loading/reloading. Use depmod for this
kernel only if needed. Load em28xx and em28xx-v4l after approval; keep the
existing snd-usb-audio capture interface rather than forcing em28xx-alsa onto
it. Verify the installed path with modinfo, USB interface driver links under
/sys/bus/usb/devices, kernel logs, and v4l2-ctl --list-devices. Identify the
new node by hardware identity, never assume /dev/video0 or renumber webcams.

## Capture verification after approval

Use v4l2-ctl on the new Hauppauge node to list inputs, standards, formats,
frame sizes and controls. Test each connected input separately: index 0 is
Composite and index 1 S-Video in the E1 board definition. For US NTSC sources,
start with NTSC-M, YUYV, 720x480, 30000/1001 frames/s (interlaced source).
Confirm the enumerated capabilities and measured cadence before treating
these as validated settings. Stream at least 300 frames to /dev/null, then
exercise stop/start and blocking dequeue with a timeout. Check logs for USB,
URB, decoder or queue errors. Verify picture and audio with a real source.

OBS: add Video Capture Device (V4L2), select the Hauppauge device, choose the
connected input and NTSC standard, then the supported YUYV/720x480 mode.
Use Yadif 2x deinterlacing for 59.94-field/s material if suitable. Add the
USB-Live2 Audio ALSA/PulseAudio input once, avoiding duplicate audio paths.
/proc/asound/card3/stream0 currently advertises S16_LE, stereo, 48000 Hz;
use stable device names because card numbers may change. Match OBS audio
rate to 48 kHz and measure sync using a visible/audible event before applying
a sync offset. S-Video carries no audio; use the separate analog audio leads.

## Rollback after an approved installation

Close capture applications. Uninstall only this driver for this kernel:

    sudo dkms uninstall -m em28xx-dkms -v 1.0 -k 7.0.0-38-generic

After confirming no other em28xx devices are in use, unload only the newly
loaded em28xx extensions/core in dependency order, then restore the prior
source backup. If needed run depmod for 7.0.0-38-generic and load the stock
em28xx modules. Do not remove NVIDIA or unload shared USB audio/webcam drivers.
The stock driver may again leave E1 video unbound, which is the original state.
If source-only changes are being reverted before installation, restore the
repository backup or reverse the delivered source patch; the running system
needs no rollback.
