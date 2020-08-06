#!/bin/bash -e

run_job()
{
	export tbox_group=$2
	tj ../jobs/iperf-sparrow.yaml
	cd /c/crystal-ci/providers
	./my-qemu.sh
}

cd /c/cci/user-client/helper

dmidecode -s system-product-name | grep -iq "virtual" && exit
run_job vm-hi1620-2p8g
run_job vm-pxe-hi1620-2p8g
