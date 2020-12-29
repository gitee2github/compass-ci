#!/bin/bash
# SPDX-License-Identifier: MulanPSL-2.0+
# Copyright (c) 2020 Huawei Technologies Co., Ltd. All rights reserved.
# - nr_cpu
# - memory

: ${nr_cpu:=1}
: ${memory:=1G}

log_file=/srv/cci/serial/logs/${hostname}
if [ ! -f "$log_file" ]; then
	touch $log_file
	# fluentd refresh time is 1s
	# let fluentd to monitor this file first
	sleep 2
fi

qemu=qemu-system-aarch64
command -v $qemu >/dev/null || qemu=qemu-kvm

ipxe_script=ipxe_script
curl http://${SCHED_HOST:-172.17.0.1}:${SCHED_PORT:-3000}/boot.ipxe/mac/${mac} > $ipxe_script
cat $ipxe_script >> ${log_file}

append=
initrds=
while read a b c
do
	case "$a" in
		'#')
			;;
		initrd)
			file=$(basename "$b")
			wget --timestamping -a ${log_file} --progress=bar:force $b
			initrds+="$file "
			;;
		kernel)
			kernel=$(basename "$b")
			wget --timestamping -a ${log_file} --progress=bar:force $b
			append=$(echo "$c" | sed -r "s/ initrd=[^ ]+//g")
			;;
		*)
			;;
	esac
done < $ipxe_script

[ -s "$kernel" ] || {
	echo "can't get kernel or kernel size is 0"
	exit
}

[ -n "$initrds" ] || {
	exit
}

initrd=initrd
cat $initrds > $initrd

echo $SCHED_PORT
echo kernel: $kernel
echo initrds: $initrds
echo append: $append
echo less $log_file

sleep 5

kvm=(
	$qemu
	-machine virt-4.0,accel=kvm,gic-version=3
	-kernel $kernel
	-initrd $initrd
	-smp $nr_cpu
	-m $memory
	-cpu Kunpeng-920
	-bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd
	-nic tap,model=virtio-net-pci,helper=/usr/libexec/qemu-bridge-helper,br=br0,mac=${mac}
	-k en-us
	-no-reboot
	-nographic
	-serial file:${log_file}
	-monitor null
)

"${kvm[@]}" --append "${append}"
