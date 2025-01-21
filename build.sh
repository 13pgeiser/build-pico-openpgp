#!/bin/bash
#!/bin/bash
set -e
source bash-scripts/helpers.sh
if [ -z "$1" ]; then
	run_shfmt_and_shellcheck ./*.sh
fi
docker_configure
docker_setup "pistorm32_build"
dockerfile_create
cat >>"$DOCKERFILE" <<'EOF'
RUN set -ex \
    && apt-get update \
    && apt-get dist-upgrade -y \
    && apt-get install -y --no-install-recommends \
	cmake \
	gcc-arm-none-eabi \
	libnewlib-arm-none-eabi \
	libstdc++-arm-none-eabi-newlib \
	gnupg \
    && apt-get clean \
    && rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/*
