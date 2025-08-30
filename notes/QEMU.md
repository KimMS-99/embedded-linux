# QEMU
QEMU는 에뮬레이터로 

## QEMU Install
```bash
$ sudo apt update
$ sudo apt install -y qemu-system qemu-utils
$ sudo apt install -y qemu-user qemu-user-static binfmt-support

# AArch64(ARM64) VM 만들기
$ sudo apt install -y qemu-efi-aarch64 cloud-image-utils qemu-system-aarch64 curl
```

```bash
# 설치 후 확인
$ qemu-system-x86_64 --version
$ qemu-aarch64 --version
$ qemu-arm --version
$ update-binfmts --display | grep -E 'qemu-(arm|aarch64)'
```

## QEMU GUI Install
Ubuntu ARM64 이미지 받기 + 검증 + 부팅 (QEMU GUI 예시)

1. 베이스 준비(최초 1회만)
```bash
# 폴더
$ mkdir -p ~/arm64-vm && cd ~/arm64-vm

# 1) Ubuntu 24.04 LTS (noble) ARM64 이미지 & 체크섬
$ curl -LO https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-arm64.img
$ curl -LO https://cloud-images.ubuntu.com/noble/current/SHA256SUMS

# 2) 무결성 확인
$ sha256sum -c SHA256SUMS | grep noble-server-cloudimg-arm64.img

# 3) 오버레이 디스크(내 변경사항 저장용)
$ qemu-img create -f qcow2 -F qcow2 -b noble-server-cloudimg-arm64.img os.qcow2

# 4) cloud-init seed.iso (계정/SSH 설정: 최초 부팅에만 사용)
$ mkdir -p seed && cd seed
$ cat > user-data <<'EOF'
#cloud-config
users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
    # 비번 대신 SSH 키를 쓰려면 아래 주석 풀고 authorized_keys 넣으세요
    # ssh_authorized_keys:
    #   - ssh-rsa AAAA...
ssh_pwauth: True
chpasswd:
  list: |
    ubuntu:ubuntu
  expire: False
EOF

$ cat > meta-data <<'EOF'
instance-id: iid-001
local-hostname: arm64vm
EOF

$ cloud-localds ../seed.iso user-data meta-data
$ ls -l ../ssed.iso # 생성 확인
$ cd ..
```

2. 최초 부팅(초기 설정) — seed.iso 포함 (1회)
```bash
$ cd ~/arm64-vm
qemu-system-aarch64 \
  -M virt -cpu cortex-a72 -smp 4 -m 4096 -accel tcg,thread=multi \
  -display gtk -device virtio-gpu-pci \
  -device usb-kbd -device usb-mouse \
  -bios /usr/share/AAVMF/AAVMF_CODE.fd \
  -drive file=os.qcow2,if=virtio,format=qcow2 \
  -drive file=seed.iso,if=virtio,format=raw \
  -netdev user,id=n0,hostfwd=tcp::2222-:22 \
  -device virtio-net-pci,netdev=n0
```
- GUI 창 부팅 후 ubuntu/ubuntu 로 로그인(위 cloud-init 설정 기준).
- 한 번 부팅하면 사용자/설정이 os.qcow2에 저장됩니다.
- 종료: sudo poweroff.<br>
다음부턴 seed.iso 필요 없음.

3. 반복 실행용 스크립트 (GUI/CLI 두 가지)

3-1. GUI 실행 스크립트
```bash
$ cat > ~/arm64-vm/run-vm-gui.sh << 'EOF'
#!/usr/bin/env bash
exec qemu-system-aarch64 \
  -M virt -cpu cortex-a72 -smp 4 -m 4096 -accel tcg,thread=multi \
  -display gtk -device virtio-gpu-pci \
  -device virtio-keyboard-pci \
  -device virtio-tablet-pci \
  -bios /usr/share/AAVMF/AAVMF_CODE.fd \
  -drive file=$HOME/arm64-vm/os.qcow2,if=virtio,format=qcow2 \
  -netdev user,id=n0,hostfwd=tcp::2222-:22 \
  -device virtio-net-pci,netdev=n0
EOF
chmod +x ~/arm64-vm/run-vm-gui.sh
```

3-2. CLI(헤드리스) 실행 스크립트
```bash
$ cat > ~/arm64-vm/run-vm-cli.sh << 'EOF'
#!/usr/bin/env bash
exec qemu-system-aarch64 \
  -M virt -cpu cortex-a72 -smp 2 -m 2048 -accel tcg,thread=multi \
  -nographic -serial mon:stdio \
  -bios /usr/share/AAVMF/AAVMF_CODE.fd \
  -drive file=$HOME/arm64-vm/os.qcow2,if=virtio,format=qcow2 \
  -netdev user,id=n0,hostfwd=tcp::2222-:22 \
  -device virtio-net-pci,netdev=n0
EOF
chmod +x ~/arm64-vm/run-vm-cli.sh
```

이후 실행:
```bash
# GUI로
$ ~/arm64-vm/run-vm-gui.sh

# 또는 CLI로
$ ~/arm64-vm/run-vm-cli.sh
```