#!/bin/bash

set -aeu

do_help() {
cat <<EOF

Usage:

    <image file> <mount point> - mounts image from <image file> at /media/<mount point>

        $0 /data/imgs/image.img mp - this will mount file /data/imgs/image.img at
                                     mount point /media/mp

    -u|--umount <dev|mnt-point> - unmount image by loop device or mount name, e.g.:

        $0 -u loop0 - this will unmount all partitions mounted from /dev/loop0
        $0 -u mntpt - this will unmount all partitions mounted in /media/mntpt

    -h|--help - show this help

EOF
}

do_umount() {
	local what=${1:?ENTITY NAME REQUIRED}
	local loopdev=
	if losetup -a | cut -f1 -d: | grep -F '/dev/'"$what" ; then
		loopdev="/dev/$what"
	elif mount -l | grep -E '^/dev/loop[0-9]+p[0-9]+ on /media/' | grep -qF '/media/'"$what"'/p' ; then
		loopdev=$(mount -l | grep -F '/media/'"$what"'/p' | cut -f1 -d' ' | grep -Eo '/dev/loop[0-9]+' | head -n 1)
	fi
	if [ -z "$loopdev" ] ; then
		echo -e "\nNo matching entities found. Aborting.\n" >&2
		exit 1
	fi
	echo "Will unmount $loopdev (based on: $what)"
	for x in $(mount -l | gawk -vm="$loopdev" '$0~m{print $3}') ; do
		umount "$x"
	done
	losetup -d "$loopdev"
}

cmd=${1:-'--help'}
case "$cmd" in
	-u|--umount) shift ; do_umount "$@" ; exit ;;
	-h|--help) do_help ; exit ;;
esac

I=${1:?IMAGE NAME REQUIRED}
N=${2:?MOUNT NAME REQUIRED}
M=/media/$N

if [ ! -f "$I" ] ; then
	echo "Image $I not found." >&2 && exit 1
fi

L=$(losetup --partscan --find --show "$I")

if [ -z "$L" ] ; then
	echo "Couldn't mount image as loop device" >&2 && exit 1
fi

echo "Image $I setup as loop-device $L. Mounting as $M"

if [ -d "$M" ] ; then
	echo "Requested directory /media/$N already exists" >&2 && exit 1
fi

mkdir "$M" || { echo "Can't create directory $M" >&2 && exit 1; }

for x in $(seq 1 10) ; do
	LP="${L}p${x}"
	if [ -b "$LP" ] ; then
		mkdir "$M/p$x"
		mount -t auto "$LP" "$M/p$x"
	fi
done

