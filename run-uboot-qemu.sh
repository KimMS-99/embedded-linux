set -euo pipefail

cd /home/ubuntu03/embedded_linux/bootloader/u-boot

# u-boot.bin 존재 확인
if [[ ! -f build-qemu64/u-boot.bin ]]; then
  echo "ERROR: build-qemu64/u-boot.bin 이 없습니다. 먼저 U-Boot를 빌드하세요." >&2
  exit 1
fi

exec qemu-system-aarch64 \
  -M virt -cpu cortex-a72 -m 1024 -nographic \
  -bios build-qemu64/u-boot.bin

