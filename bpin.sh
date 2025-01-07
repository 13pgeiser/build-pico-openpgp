#!/bin/bash
set -ex
### Board options ###
BOARD="$1"
case "$BOARD" in
"pico")
	BOARD_FOLDER="RPI-RP2"
	;;
"pimoroni_tiny2350" | "pico2")
	BOARD_FOLDER="RP2350"
	;;
*)
	echo "Unsupported board: *$1*. Use either pico, pico2 or pimoroni_tiny2350"
	exit 1
	;;
esac
### Defaults ###
IDENTITY="pico openpgp<pico@openpgp.me>"
CERTIFY_PASS="test"
ADMIN_PASS="12345678"
PIN_PASS="123456"
### Remove pico-* folders, clone and build
function do_build {
	sudo apt install -y cmake gcc-arm-none-eabi libnewlib-arm-none-eabi libstdc++-arm-none-eabi-newlib opensc gnupg pcsc-tools
	rm -rf ./pico-*
	git clone https://github.com/raspberrypi/pico-sdk.git --branch 2.1.0 --recurse-submodules
	git clone https://github.com/polhenarejos/pico-openpgp.git --branch main --recurse-submodules
	mkdir -p pico-build
	cd pico-build
	cmake -DPICO_BOARD="$BOARD" -DVIDPID="Gnuk" -DPICO_SDK_PATH="../pico-sdk/" ../pico-openpgp
	make -j"$(nproc)"
	cd ..
}
### Wait for the card to reply correctly. ###
function wait_for_card_status {
	while ! gpg --card-status; do
		sleep 1
		echo "retry"
	done
}
### Erase memory first, then copy ###
function do_flash {
	if [ ! -e pico-build/flash_nuke.uf2 ]; then
		curl https://datasheets.raspberrypi.com/soft/flash_nuke.uf2 -o pico-build/flash_nuke.uf2
	fi
	cp pico-build/flash_nuke.uf2 "/media/$USER/$BOARD_FOLDER/"
	sleep 2
	while [ ! -e "/media/$USER/$BOARD_FOLDER/INFO_UF2.TXT" ]; do
		sleep 1
	done
	cp pico-build/pico_openpgp.uf2 "/media/$USER/$BOARD_FOLDER/"
	wait_for_card_status
}
### Create new keys, send them to the card, change pin and try to decrypt.
function do_test {
	# !!! WARNING deletes actual gnupg installation!!!
	rm -rf ~/.gnupg
	echo "$CERTIFY_PASS" | gpg --batch --passphrase-fd 0 --quick-generate-key "$IDENTITY" rsa cert never
	KEYFP=$(gpg -k --with-colons "$IDENTITY" | awk -F: '/^fpr:/ { print $10; exit }')
	echo "$CERTIFY_PASS" | gpg --batch --pinentry-mode=loopback --passphrase-fd 0 --quick-add-key "$KEYFP" rsa sign 1y
	echo "$CERTIFY_PASS" | gpg --batch --pinentry-mode=loopback --passphrase-fd 0 --quick-add-key "$KEYFP" rsa encr 1y
	echo "$CERTIFY_PASS" | gpg --batch --pinentry-mode=loopback --passphrase-fd 0 --quick-add-key "$KEYFP" rsa auth 1y
	gpg -K
	# Put key on card
	KEYID=$(gpg -k --with-colons "$IDENTITY" | awk -F: '/^pub:/ { print $5; exit }')
	wait_for_card_status
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
	wait_for_card_status
	gpg -K
	gpg --command-fd=0 --pinentry-mode=loopback --edit-card <<EOF
admin
passwd
1
$PIN_PASS
654321
654321
3
$ADMIN_PASS
87654321
87654321
q
q
EOF
	ADMIN_PASS="87654321"
	PIN_PASS="654321"
	wait_for_card_status
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
do_build
do_flash
do_test
