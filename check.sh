#!/bin/bash
set -ex
for file in *.sh; do
	docker run -v "$PWD":/mnt mvdan/shfmt -w "/mnt/$file"
	docker run -e SHELLCHECK_OPTS="" -v "$PWD":/mnt koalaman/shellcheck:stable -x "$file"
	sudo chown "$USER" "$file"
done
