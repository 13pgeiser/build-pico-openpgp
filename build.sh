#!/bin/bash
set -ex
BRANCH="eddsa" # main or eddsa
if [ "$BRANCH" == "eddsa" ]; then
	KEY_TYPE="ed25519" # rsa or ed25519
else
	KEY_TYPE="rsa" # rsa or ed25519
fi
IDENTITY="pico openpgp<pico@openpgp.me>"
CERTIFY_PASS="test"
ADMIN_PASS="12345678"
PIN_PASS="123456"
VID_PID="NitroStart" # or "Gnuk"?
##############################################
function do_build {
	sudo apt install -y cmake gcc-arm-none-eabi libnewlib-arm-none-eabi libstdc++-arm-none-eabi-newlib opensc gnupg pcsc-tools
	if [ "$BRANCH" == "eddsa" ]; then
		git clone https://github.com/raspberrypi/pico-sdk.git --branch 2.0.0 --recurse-submodules
	else
		git clone https://github.com/raspberrypi/pico-sdk.git --branch 2.1.0 --recurse-submodules
	fi
	git clone https://github.com/polhenarejos/pico-openpgp.git --branch "$BRANCH" --recurse-submodules
	# Build
	mkdir -p pico-build
	cd pico-build
	cmake -DPICO_BOARD=pimoroni_tiny2350 -DVIDPID="$VID_PID" -DPICO_SDK_PATH="../pico-sdk/" ../pico-openpgp
	make -j"$(nproc)"
	cd ..
}
##############################################
function do_flash {
	# Copy to board and wait a bit.
	if [ ! -e pico-build/flash_nuke.uf2 ]; then
		curl https://datasheets.raspberrypi.com/soft/flash_nuke.uf2 -o pico-build/flash_nuke.uf2
	fi
	cp pico-build/flash_nuke.uf2 "/media/$USER/RP2350/"
	sleep 22
	cp pico-build/pico_openpgp.uf2 "/media/$USER/RP2350/"
	sleep 8
}
##############################################
function do_test {
	# WARNING deletes actual gnupg installation.
	rm -rf ~/.gnupg
	# Create new keys
	echo "$CERTIFY_PASS" | gpg --batch --passphrase-fd 0 --quick-generate-key "$IDENTITY" "$KEY_TYPE" cert never
	KEYFP=$(gpg -k --with-colons "$IDENTITY" | awk -F: '/^fpr:/ { print $10; exit }')
	echo "$CERTIFY_PASS" | gpg --batch --pinentry-mode=loopback --passphrase-fd 0 --quick-add-key "$KEYFP" "$KEY_TYPE" sign 1y
	echo "$CERTIFY_PASS" | gpg --batch --pinentry-mode=loopback --passphrase-fd 0 --quick-add-key "$KEYFP" "${KEY_TYPE//ed/cv}" encr 1y
	echo "$CERTIFY_PASS" | gpg --batch --pinentry-mode=loopback --passphrase-fd 0 --quick-add-key "$KEYFP" "$KEY_TYPE" auth 1y
	gpg -K
	# Put key on card
	KEYID=$(gpg -k --with-colons "$IDENTITY" | awk -F: '/^pub:/ { print $5; exit }')
	gpg --card-status
	gpg --command-fd=0 --pinentry-mode=loopback --edit-key "$KEYID" <<EOF
key 1
keytocard
1
$CERTIFY_PASS
$ADMIN_PASS
$ADMIN_PASS
key 1
key 2
keytocard
2
$CERTIFY_PASS
$ADMIN_PASS
key 2
key 3
keytocard
3
$CERTIFY_PASS
$ADMIN_PASS
save
EOF
	gpg -K
	gpg --export "$KEYFP" >public.gpg
	rm -rf ~/.gnupg
	echo "Gnupg folder deleted..."
	killall gpg-agent || true
	killall scdaemon || true
	gpg --list-key
	gpg -K
	gpg --import public.gpg
	rm -f public.gpg
	gpg --card-status || true
	sleep 90
	gpg --card-status
	echo -e "5\ny\n" | gpg --command-fd 0 --expert --edit-key "$KEYFP" trust
	gpg-connect-agent "scd serialno" "learn --force" /bye
	gpg -K
	rm -f ./hello.*
	echo "hello" >hello.txt
	gpg -r pico@openpgp.me -e hello.txt
	rm -f hello.txt
	echo "$PIN_PASS" | gpg --batch --pinentry-mode=loopback --passphrase-fd 0 -d -d hello.txt.gpg
	rm -f hello.txt.gpg
}
##############################################
do_build
do_flash
do_test
