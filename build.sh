#!/bin/bash
set -ex
BRANCH="eddsa" # main or eddsa
KEY_TYPE="ed25519" # rsa or ed25519
##############################
IDENTITY="pico openpgp<pico@openpgp.me>"
CERTIFY_PASS="test"
ADMIN_PASS="12345678"
VID_PID="NitroStart" # or "Gnuk"?
sudo apt install -y cmake gcc-arm-none-eabi libnewlib-arm-none-eabi libstdc++-arm-none-eabi-newlib  opensc gnupg
if [ "$BRANCH" == "eddsa" ]; then
	git clone https://github.com/raspberrypi/pico-sdk.git --branch 2.0.0 --recurse-submodules
	git clone https://github.com/polhenarejos/pico-openpgp.git --branch eddsa --recurse-submodules
else
	git clone https://github.com/raspberrypi/pico-sdk.git  --branch 2.1.0 --recurse-submodules
	git clone https://github.com/polhenarejos/pico-openpgp.git --recurse-submodules
fi
# Build
mkdir -p pico-build
cd pico-build
cmake -DPICO_BOARD=pimoroni_tiny2350 -DVIDPID="$VID_PID" -DPICO_SDK_PATH="../pico-sdk/" ../pico-openpgp
make -j"$(nproc)"
# Copy to board and wait a bit.
cp pico_openpgp.uf2 "/media/$USER/RP2350/"
sleep 10
# WARNING deletes actual gnupg installation.
rm -rf ~/.gnupg
gpg --card-status
# Create new keys
echo "$CERTIFY_PASS" | gpg --batch --passphrase-fd 0 --quick-generate-key "$IDENTITY" "$KEY_TYPE" cert never
export KEYFP=$(gpg -k --with-colons "$IDENTITY" | awk -F: '/^fpr:/ { print $10; exit }')
echo "$CERTIFY_PASS" | gpg --batch --pinentry-mode=loopback --passphrase-fd 0 --quick-add-key "$KEYFP" "$KEY_TYPE" sign 1y
gpg -K
# Put key on card
export KEYID=$(gpg -k --with-colons "$IDENTITY" | awk -F: '/^pub:/ { print $5; exit }')
gpg --command-fd=0 --pinentry-mode=loopback --edit-key $KEYID <<EOF
key 1
keytocard
1
$CERTIFY_PASS
$ADMIN_PASS
$ADMIN_PASS
EOF

