#!/bin/bash
set -e
docker rm -f pico_opengpg || true
cat ./scripts/Dockerfile.bookworm | docker build -t pico_opengpg -
docker run -d --name pico_opengpg pico_opengpg sleep 86400 # 24 hours...
docker cp ./build.sh pico_opengpg:/build.sh
docker exec -t pico_opengpg bash /build.sh pico checkout
docker exec -t pico_opengpg bash /build.sh pico archive_sources
docker exec -t pico_opengpg bash /build.sh pico build_release
docker exec -t pico_opengpg bash /build.sh pico2 build_release
docker exec -t pico_opengpg bash /build.sh pimoroni_tiny2350 build_release
docker cp pico_opengpg:/release ./
docker rm -f pico_opengpg || true
docker system prune -f -a
exit 0
