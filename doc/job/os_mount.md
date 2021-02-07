# Summary
=========

`os_mount` defines the mount method of testbox's root partition.

It has the following optional values:
  - nfs
  - cifs
  - initramfs
  - container
  - local

Usage example:
  - submit iperf.yaml testbox=vm-2p8g os_mount=nfs
  - submit iperf.yaml testbox=vm-2p8g os_mount=cifs
  - submit iperf.yaml testbox=vm-2p8g os_mount=initramfs
  - submit iperf.yaml testbox=dc-8g os_mount=container
  - submit iperf.yaml testbox=vm-2p8g os_mount=local

# Optional Values
=================

## Work flow when os_mount=local

1. user submit job with os_mount: local
  - optional {kernel_append_root}:
    - save_root_partition: give an iconic string, then the root partition data used by this job will be retained.
                           and you can use the root partition data of this job in the futher job by {use_root_partition}.
    - use_root_partition : give an iconic string, then the root partition data generated by the
                           pervious job which has the {save_root_partition} field will be used.
    - root_partition_size: specify the size of root partition, *default is 10G*.

    - tips:
      - value of {save_root_partition} and {use_root_partition} need to be iconic enough, uuid is recommended.
      - value of {save_root_partition} and {use_root_partition} will be the suffix of logical volume.

2. scheduler return the ipxe_str to testbox
  ```
  dhcp
  initrd http://${http_server_ip}:${http_server_port}/os/openeuler/aarch64/20.03-iso-snapshots/{timestamp}/initrd.lkp
  initrd http://${http_server_ip}:${http_server_port}/os/openeuler/aarch64/20.03-iso-snapshots/{timestamp}/boot/vmlinuz
  imgargs vmlinux root=/dev/mapper/os-openeuler_aarch64_20.03 rootfs_src={nfs_server_ip}:os/openeuler/aarch64/20.03-iso-snapshots/{timestamp} initrd=initrd.lkp {kernel_append_root}
  boot
  ```

3. dracut step of boot
  ```
  if have {use_root_partition}; then
	base_lv_name=openeuler_aarch64_20.03_{value_of_use_root_partition}
	lvdisplay /dev/mappaer/os-{base_lv_name} > /dev/null || exit 1

	if have {save_root_partition}; then
		boot_lv_name=openeuler_aarch64_20.03_{value_of_save_root_partition}

		if {save_root_partition} == {use_root_partition}; then
			boot from /dev/mappaer/os-{boot_lv_name}
		fi

		lvremove -f /dev/mappaer/os-{boot_lv_name}
		lvcreate /dev/mappaer/os-{boot_lv_name} from /dev/mappaer/os-{base_lv_name} || exit 1
		boot from /dev/mappaer/os-{boot_lv_name}
	else
		boot_lv_name=openeuler_aarch64_20.03_{value_of_use_root_partition}
		boot from /dev/mappaer/os-{boot_lv_name}
	fi

  else:
	base_lv_name=openeuler_aarch64_20.03_{timestamp}
	lvdisplay /dev/mappaer/os-{base_lv_name} > /dev/null || {
		# create logical volume
		lvcreate -L {root_partition_size} -n {base_lv_name} os || exit 1

		# rsync nfsroot to lvm:/dev/mapper/os-{base_lv_name}
		mount -t nfs {nfs_server_ip}:os/openeuler/aarch64/20.03-iso-snapshots/{timestamp} /mnt
		mkdir /mnt1 && mount /dev/mapper/os-{base_lv_name} /mnt1
		cp -a /mnt/. /mnt1/
		umount /mnt /mnt1

		# change premission of lvm:/dev/mapper/os-{base_lv_name} to readonly
		lvchange -p r /dev/mapper/os-{base_lv_name}
	}

	boot_lv_name=openeuler_aarch64_20.03
	if have {save_root_partition}; then
		boot_lv_name=openeuler_aarch64_20.03_{value_of_save_root_partition}
	fi

	lvremove -f /dev/mappaer/os-{boot_lv_name}
	lvcreate /dev/mappaer/os-{boot_lv_name} from /dev/mappaer/os-{base_lv_name} || exit 1
	boot from /dev/mappaer/os-{boot_lv_name}
  fi
  ```

4. execute the job