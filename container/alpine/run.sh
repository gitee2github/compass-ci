#!/bin/bash

cmd=(
	docker run
	-it
	-d
	-v alpine-home:/home
	-v alpine-root:/root
	-v /c:/c
	-v /srv/os:/srv/os
	-p 2200:2200
	--hostname alpine
	--security-opt seccomp=unconfined
	alpine:testbed
	/usr/sbin/sshd -D -p 2200
)

"${cmd[@]}"
