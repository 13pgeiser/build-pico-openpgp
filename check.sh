#!/bin/bash
set -ex
docker run -v "$PWD":/mnt mvdan/shfmt -w /mnt/build.sh
docker run -e SHELLCHECK_OPTS="" -v "$PWD":/mnt koalaman/shellcheck:stable -x build.sh
sudo chown $USER build.sh
