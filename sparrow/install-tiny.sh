#!/bin/bash -e
# For your reference only.
# It's better to run the below scripts step by step.

cd /c/crystal-ci/sparrow || exit

0-package/install.sh
1-storage/tiny.sh
2-network/br0.sh
3-code/git.sh
3-code/dev-env.sh
4-docker/buildall.sh
6-test/docker.sh
