#!/usr/bin/env bash
# Install only em28xx-dkms/1.2 for the running kernel. Never unload shared drivers.
set -euo pipefail
if [[ ${1:-} == --help ]]; then
    echo 'Usage: sudo bash install.sh [--uninstall]'
    echo 'Installs the driver for the running kernel, without rebooting or unloading modules.'
    exit 0
fi
[[ $# -eq 0 || ( $# -eq 1 && $1 == --uninstall ) ]] || { echo 'Unknown argument; use --help.' >&2; exit 1; }
[[ $EUID -eq 0 ]] || { echo 'Run with sudo: sudo bash install.sh' >&2; exit 1; }
command -v dkms >/dev/null || { echo 'Install DKMS first; see README.md.' >&2; exit 1; }
package=em28xx-dkms
version=1.2
kernel=$(uname -r)
if [[ ${1:-} == --uninstall ]]; then
    dkms uninstall -m "$package" -v "$version" -k "$kernel"
    echo 'Uninstalled for the running kernel. Loaded modules and source were retained.'
    exit 0
fi
here=$(cd -- "$(dirname -- "$0")" && pwd)
[[ -f /lib/modules/$kernel/build/Makefile ]] || { echo "Missing headers for $kernel; see README.md." >&2; exit 1; }
command -v x86_64-linux-gnu-gcc-13 >/dev/null || { echo 'Install gcc-13 first; see README.md.' >&2; exit 1; }
for item in Makefile dkms.conf em28xx/em28xx-video.c patches/USBLive2_Empia.patch patches/0002-e1-standard-query.patch patches/0003-e1-disable-raw-vbi.patch; do
    [[ -f $here/$item ]] || { echo "Missing source: $item" >&2; exit 1; }
done
status=$(dkms status -m "$package" -v "$version")
if [[ -n $status ]]; then
    echo "$status"
    echo 'Version 1.2 is already registered. Existing source was preserved.'
    echo "To build/install it for this kernel, run:"
    echo "sudo dkms build -m $package -v $version -k $kernel"
    echo "sudo dkms install -m $package -v $version -k $kernel"
    exit 0
fi
target=/usr/src/$package-$version
[[ ! -e $target ]] || { echo "$target already exists; preserved. Review it before registering." >&2; exit 1; }
echo 'Existing DKMS packages (retained):'
dkms status
mkdir "$target"
cp -a -- "$here/Makefile" "$here/dkms.conf" "$here/em28xx" "$here/patches" "$target/"
dkms add -m "$package" -v "$version"
dkms build -m "$package" -v "$version" -k "$kernel"
# Replace only this package's em28xx modules; retain earlier DKMS versions for rollback.
dkms install -m "$package" -v "$version" -k "$kernel" --force
printf '\nInstalled %s/%s for %s.\n' "$package" "$version" "$kernel"
echo 'No loaded modules, boot settings, webcam configuration or NVIDIA packages were changed.'
echo 'See README.md to activate the driver and select Composite or S-Video in OBS.'
