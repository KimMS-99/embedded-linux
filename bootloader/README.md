# 부트로더
[부트로더 설명](../notes/부트로더.md)<br>
[장치 커널 설명](../notes/장치%20트리%20소개.md)
## U-Boot
U-Boot은 많은 수의 프로세서 아키텍처와 다수의 보드 및 장치를 지원한다.

U-Boot는 임베디드 파워PC 보드용 오픈소스 부트로더로 삶을 시작했다. 그 다음에 ARM 기반 보드로 이식됐고, 이후 MIPS, SH, x86등 다른 아키텍처로 이식됐다.

## U-Boot 빌드하기

```bash
# 의존패키지
$ sudo apt-get update
$ sudo apt- install -y device-tree-compiler bison flex libssl-dev python3 build-essential

# U-Boot 소스 준비
$ git clone git://git.denx.de/u-boot.git
$ cd u-boot
$ git checkout v2021.01

# 1) defconfig 적용 (ARCH 지정 안 함, 또는 ARCH=arm 로 명시)
$ make CROSS_COMPILE="$HOME/x-tools/aarch64-unknown-linux-gnu/bin/aarch64-unknown-linux-gnu-" \
     O=build-qemu64 qemu_arm64_defconfig

# 2) 빌드
$ make CROSS_COMPILE="$HOME/x-tools/aarch64-unknown-linux-gnu/bin/aarch64-unknown-linux-gnu-" \
     O=build-qemu64 -j"$(nproc)"

# 바이너리 확인
$ file build-qemu64/u-boot   # → ARM aarch64 여야 함

# QEMU로 u-boot 실행
$ qemu-system-aarch64 -M virt -cpu cortex-a72 -m 1024 -nographic \
  -bios build-qemu64/u-boot.bin
# 종료: Ctrl+A, X

# 스크립트로 실행하게 만들기
$ vi run-uboot-qemu.sh
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

$ chmod u+x run-uboot-qemu.sh
```

### U-Boot 사용

- `help` → 모든 명령어 목록 확인
- `printenv` → 현재 환경변수(bootcmd, bootargs, ipaddr 등) 확인
- `bdinfo` → 보드/메모리 등 기본 보드 정보 출력
- `versio` → U-Boot 버전 확인

환경 변수<br>
U-Boot는 환경 변수를 광범위하게 사용해서 함수 사이에 정보를 저장라고 전달하며, 심지어 스크립트를 만들기도 한다. 환경변수는 간단한 name=value 쌍으로, 메모리 영역에 저장된다.

U-Boot 명령줄에서 setenv를 통해 변수를 만들고 변경할 수 있다.

A) 상태 점검<br>
```bash
=> printenv                 # 전체 목록
=> printenv bootcmd         # 특정 변수
=> env grep boot            # 키워드로 필터
=> bdinfo                   # 유용한 주소 변수들 확인(예: loadaddr 등)
=> help env                 # env 관련 하위명령 요약
```
저장소 유무 확인(가능하면)
```bash
=> env info
```

B) 값 읽기·쓰기·삭제<br>
쓰기(설정 / 생성)
```bash
=> setenv mymsg "hello u-boot"   # 공백/= 포함 시에는 항상 따옴표!
# 또는 새 구문
=> env set mymsg "hello u-boot"
```
읽기(확장)
```bash
=> echo $mymsg
=> echo ${mymsg}                 # 중괄호 버릇들이기(안전)
```
삭제
```bash
=> setenv mymsg                  # 값 없이 set → 삭제
# 또는
=> env delete mymsg
```
기본값으로 초기화
```bash
=> env default -a                # 모든 변수 런타임을 "컴파일된 기본값"으로 되돌림
# (주의) 진짜로 다 초기화되니 중요한 값 있으면 export로 백업
```

C) 영구 저장(있으면)과 주의
```bash
=> env save                      # 또는 saveenv
```
- 저장 성공: “Saving Environment to …” 같은 메시지가 뜸.
- 실패 흔한 이유: QEMU 보드 설정이 ENV 저장소 미구성. 이 경우엔 세션 안에서만 실습하면 됨.

D) 가져오기/내보내기(백업·이동용)
바이너리(export/import)
```bash
=> env export -b ${loadaddr} ${filesize}  # -b: 바이너리 포맷(ROM 저장용)
=> env import -b ${loadaddr}              # 반대로 불러오기
```
텍스트(export/import) – 사람이 읽기 좋은 포맷
```bash
=> env export -t ${loadaddr} ${filesize}  # -t: key=value\n 텍스트
=> md.b ${loadaddr} 64                    # 메모리 덤프로 확인
=> env import -t ${loadaddr}              # 텍스트를 env로 반영
```

E) 스크립팅과 실행 흐름
run: 변수 안의 “명령 문자열” 실행
```bash
=> setenv hello 'echo hi; sleep 1; echo done'
=> run hello
```

조건/수치 계산(작은 로직 가능)
```bash
=> setenv i 0
=> while test $i -lt 3; do echo $i; setexpr i $i + 1; done
```
- setenv i 0
    - 환경변수 i를 문자열 "0"으로 설정. (U-Boot env는 숫자형이 아니라 문자열이지만, test/setexpr가 숫자로 해석해줌)
- while test $i -lt 3; do ...; done
    - while은 조건 명령의 반환 코드가 0(성공) 이면 반복.
    - test $i -lt 3
        - $i가 변수 확장되어 현재 값이 들어감. 처음엔 0.
        - -lt는 정수 비교(less than). 즉 “0 < 3 ?”
        - test가 참이면 종료코드 0 → 루프 진입.
- 루프 본문: echo $i; setexpr i $i + 1
    - echo $i → 현재 카운터 출력(처음엔 0).
    - setexpr i $i + 1 → $i + 1을 계산해서 결과를 변수 i에 저장.
        - 공백이 연산자 주변에 반드시 있어야 함: i $i + 1
        - setexpr는 정수 산술/비트연산(+, -, *, /, %, &, |, ^, <<, >> 등)을 지원.
- 다음 반복에서 조건 재평가
    - 이제 i=1 → test 1 -lt 3 참 → 본문 실행(1 출력, i=2)
    - i=2 → 참 → 본문 실행(2 출력, i=3)
    - i=3 → test 3 -lt 3 거짓 → 반환 코드 비0 → 루프 종료

```bash
=> if test "${board_name}" = "virt"; then echo VIRT; else echo OTHER; fi
```
- test "${board_name}" = "virt"
    - ${board_name}가 문자열 비교 대상.
    - 따옴표로 감싼 이유: 변수 값이 비어도 test "" = "virt"처럼 안전하게 인자 개수가 맞춰짐.
    - 값이 정확히 "virt"이면 test가 성공(반환 0), 아니면 실패(비0).
- if ...; then ...; else ...; fi
    - test의 반환 코드가 0 → then 블록(echo VIRT) 실행
    - 아니면 else 블록(echo OTHER) 실행

- `test`(문자열: `=`, `z`/`-n`), 정수 비교: `-eq/-ne/-lt/-le/-gt/-ge`
- `setexpr`로 `+ - & | ^ << >>` 같은 연산 가능

명령 구분자
- 보편적으로 ; 사용. (대부분의 구성에서 &&/||도 동작하지만, 세미콜론을 기본으로 익혀두면 안전)

F) “자주 쓰는 핵심 변수” 지도
- 부팅 흐름
    - `bootdelay` : 자동부팅 카운트다운(초)
    - `bootcmd` : 자동 실행될 명령(부트 시퀀스)
    - `bootargs` : 커널 커맨드라인(콘솔, 루트, 디버깅 옵션 등)
- 네트워크
    - `ipaddr`, `serverip`, `gatewayi`, `netmask`, `ethadd`(MAC)
    - `bootfile`(TFTP 기본 파일명), `autoload` 등
- 로드 주소(ARM64 기준 흔함)
    - `kernel_addr_` : 커널 Image 올려둘 RAM 주소
    - `fdt_addr_r` : DTB 올려둘 RAM 주소
    - `ramdisk_addr_r`: initramfs 올려둘 RAM 주소
    - (레거시) `loadaddr` : 범용 로드 주소(자주 쓰이지만 아키/구성 따라 의미가 조금 다름)
주소 변수는 `bdinfo` / `printenv`로 확인. 잘못 겹치면 다음 단계에서 로드/부팅이 꼬일 수 있음.

G) 실습 레시피(바로 써먹는 예시)

안전한 부팅 지연/메시지 넣기
```bash
=> setenv bootdelay 3
=> setenv bootcmd 'echo [auto] starting...; sleep 1; echo done'
=> run bootcmd
```

bootargs 편집 – 커널 콘솔/디버깅 옵션
```bash
# 공백 많으니 항상 따옴표!
=> setenv bootargs "console=ttyAMA0,115200 earlycon"
=> printenv bootargs
```
- 나중에 커널을 진짜 부팅할 때 root=/rootwait 같은 옵션을 여기에 더해 줌:
    - 예: root=/dev/vda1 rootwait rw loglevel=7

### U-Boot 실습 로드맵
A) 공통 주소 세팅<br>
U-Boot 프롬프트가 뜨면 로드 주소를 먼저 잡아두자(겹치지 않게):
```bash
=> setenv kernel_addr_r  0x40200000
=> setenv fdt_addr_r     0x4F000000
=> setenv ramdisk_addr_r 0x4E000000
=> printenv kernel_addr_r fdt_addr_r ramdisk_addr_r
```

B) 워밍업: 기본 명령/정보 파악<br>
목표: U-Boot가 무엇을 알고 있는지 확인.
```bash
=> version
=> help
=> bdinfo
=> printenv |  # (파이프는 안됨) 대신:
=> printenv
```
- `bdinfo`로 DRAM 시작/크기, 현재 FDT 주소, 이더넷 상태 등을 확인.
- `env info`가 있다면 영구 환경 저장소 유무도 확인 가능(없어도 실습 OK).

C) 환경변수 다루기 (세션 내 변경)<br>
목표: setenv/env set, 삭제, 기본값 복원, 스크립팅 기초.
```bash
=> echo ${bootcmd}
=> setenv mymsg "hello u-boot"
=> echo ${mymsg}
=> setenv mymsg                   # 삭제
=> env default -a                 # 컴파일 기본값으로 복원(주의!)
```

D) 메모리 만지작(기초 디버깅 감각)<br>
목표: RAM에 쓰고/읽고/복사/비교 연습.
```bash
=> echo ${loadaddr}              # 범용 로드 주소(있으면)
=> mw.b ${loadaddr} 0xAA 16
=> md.b ${loadaddr} 16
=> cp.b ${loadaddr} ${loadaddr}+0x10 16
=> cmp.b ${loadaddr} ${loadaddr}+0x10 16

=> setexpr tmp ${loadaddr} + 0x100
=> md.l ${tmp} 4
```

E) 디바이스 트리(FDT) 탐색/수정<br>
목표: 컨트롤 FDT를 붙잡아 읽고 수정.

1. 컨트롤 FDT 주소 확인 → 지정
```bash
=> bdinfo                      # fdt_blob/new_fdt 확인
=> fdt addr 0x7edf3df0         # ← 너의 출력 기준(다르면 bdinfo 값으로)
=> fdt header
```
2. 구조 탐색 & 콘솔 노드 확인
```bash
=> fdt print /chosen
=> fdt get value _UART /chosen stdout-path
=> echo ${_UART}                # 예: /pl011@9000000
=> fdt print ${_UART}           # compatible, reg, interrupts 확인
```
3. 수정 연습
```bash
=> fdt resize 0x4000
=> fdt set /chosen bootargs "console=ttyAMA0,115200 earlycon=pl011,0x9000000"
=> fdt mknode / test-node
=> fdt set /test-node my-u32 <0x12345678>
=> fdt set /test-node my-u64 <0x12345678 0x9abcdef0>   # 64비트=셀 2개
=> fdt rm /test-node
=> fdt print /chosen   # bootargs가 들어갔는지 최종 확인
```

F) 스토리지 붙이고 파일시스템 다루기 (블록 디스크(virtio-blk) 위의 ext4 파일시스템)<br>
- **virtio-blk** 디스크: QEMU가 게스트(U-Boot)에게 보여주는 가상 블록 디스크. U-Boot에서는 virtio 0:1처럼 장치 0번, 파티션 1번을 가리킴.
- **ext4** 파일: ext4로 포맷된 파티션 내부의 일반 파일(예: /boot/note.txt). U-Boot는 ext4ls, ext4load로 읽음.

**목표: 디스크 이미지에서 파일 나열/읽기.** 

1. 호스트에서 디스크 준비
```bash
# 작업 폴더(이미 만들어둔 위치 사용)
$ mkdir -p /home/ubuntu03/embedded_linux/bootloader/disk_image
$ cd /home/ubuntu03/embedded_linux/bootloader/disk_image

# 1) raw 디스크 파일 256MiB 생성
$ truncate -s 256M disk.img

# 2) GPT 파티션 테이블 + ext4 파티션 1개(전체)
$ parted -s disk.img mklabel gpt
$ parted -s disk.img mkpart primary ext4 1MiB 100%

# 3) loop 디바이스에 연결(-Pf: 파티션 노드 자동 생성)
$ LOOP=$(sudo losetup --find --show -Pf disk.img); echo "$LOOP"
# 출력 예: /dev/loop4  → 파티션 노드는 /dev/loop4p1

# 4) 파티션에 ext4 파일시스템 생성
$ sudo mkfs.ext4 -F ${LOOP}p1

# 5) 마운트해서 /boot 만들고 테스트 파일 복사
$ mkdir -p mnt
$ sudo mount ${LOOP}p1 mnt
$ sudo mkdir -p mnt/boot
$ echo "from ext4" | sudo tee mnt/boot/note.txt >/dev/null

# (옵션) 커널/DTB가 준비돼 있으면 지금 넣어두기
# sudo cp /path/to/arch/arm64/boot/Image           mnt/boot/
# sudo cp /path/to/arch/arm64/boot/dts/arm/virt.dtb mnt/boot/

# 6) 마운트 해제 + loop 해제
$ sudo umount mnt
$ sudo losetup -d ${LOOP}
```

2. QEMU에 디스크 붙여서 U-Boot 실행
```bash
# 절대경로 변수 설정
$ export DISK=/home/ubuntu03/embedded_linux/bootloader/disk_image/disk.img
$ export UBOOT=/home/ubuntu03/embedded_linux/bootloader/u-boot/build-qemu64/u-boot.bin

# QEMU 실행
$ qemu-system-aarch64 \
  -M virt -cpu cortex-a72 -m 1024 -nographic \
  -bios "$UBOOT" \
  -drive if=none,file="$DISK",format=raw,id=hd0 \
  -device virtio-blk-device,drive=hd0
```

3. U-Boot에서 파일시스템 탐색/읽기<br>
파티션/디렉터리 확인
```bash
=> part list virtio 0
=> ls virtio 0:1 /  # virtio 0번 디스크의 1번 파티션(ext4) 루트 디렉토리를 나열.
=> ext4ls virtio 0:1 /boot  # /boot 디렉토리의 파일 목록을 ext4 드라이버로 확인(note.txt 존재 체크).
```
파일 로드 + 덤프 + CRC<br>
주의: ext4load 직후 ${filesize}는 “방금 로드한 크기”로 갱신됨. 전체 CRC는 처음 전체 로드 직후 계산해 두자.
```bash
=> setenv loadaddr 0x42000000   # 파일을 로드해 둘 RAM 시작 주소를 지정.
=> ext4load virtio 0:1 ${loadaddr} /boot/note.txt   # note.txt를 loadaddr로 통째로 로드하고 ${filesize}(16진수 문자열)를 설정.
=> md.b ${loadaddr} 16  # 메모리 덤프(바이트 단위)로 처음 16바이트를 눈으로 확인.

# 전체 크기를 10진수 TOTAL로 저장
=> setenv TOTAL_HEX 0x${filesize}   # filesize 앞에 0x를 붙여 산술 가능한 형태로 보관(예: a → 0xa).
=> setexpr TOTAL ${TOTAL_HEX} + 0   # TOTAL에 10진수 길이 저장(여기선 10).

# 전체 CRC(예: f27ec73d)
=> crc32 ${loadaddr} ${TOTAL}   # 방금 로드한 전체 버퍼의 CRC32를 계산(기준값 확보: f27ec73d).
```
부분 읽기(오프셋/주소 계산 포함)
```bash
# 처음 8바이트
=> ext4load virtio 0:1 ${loadaddr} /boot/note.txt 8 0   # 처음 8바이트만 0(offset)에서 읽어서 loadaddr에 씀.
=> md.b ${loadaddr} 8   # 그 8바이트를 덤프.

# 다음 8바이트를 loadaddr+0x8 위치로
=> setexpr dst ${loadaddr} + 0x8    # 목적지 주소를 loadaddr+8로 계산.
=> ext4load virtio 0:1 ${dst} /boot/note.txt 8 8    # 다음 8바이트를 offset=8에서 읽어 loadaddr+8에 저장(실제로는 2바이트만 존재하지만 나머지는 무시됨).
=> md.b ${loadaddr} 16         # 앞 8B + 이어붙은 8B 확인, 이어 붙여진 16바이트 내용을 확인.
```
변수로 경로/장치 고정
```bash
=> setenv BOOTDEV 'virtio 0:1'  # 디스크와 파티션 식별을 변수로 고정.
=> setenv FILE    '/boot/note.txt'  # 대상 파일 경로를 변수로 고정.
=> setenv loadaddr 0x42000000   # 다시 로드 주소를 명시(가독성/재현성).
=> ext4load ${BOOTDEV} ${loadaddr} ${FILE}  # 변수로 통째 로드.
=> md.b ${loadaddr} 16  # 확인용 덤프.
```
파일을 CHUNK 단위로 끝까지 읽는 안전 루프(연속 버퍼)
```bash
=> setenv TOTAL ${filesize} # 번엔 TOTAL에 그냥 16진수 문자열(예: a) 그대로 보관(루프에서 0x 접두로 처리).

# CHUNK 기반 이어붙이기 (addr = loadaddr + off)
=> setenv CHUNK 8   # 청크 크기를 8바이트로.
=> setenv off 0  # 현재 오프셋(진행 위치)을 0으로 초기화.
=> setenv ok 1  # 진행 중 실패 여부 플래그(1=성공 가정).
=> while test 0x$off -lt 0x$TOTAL; do setexpr rem 0x$TOTAL - 0x$off; setenv sz $CHUNK; if test 0x$rem -lt 0x$CHUNK; then setenv sz $rem; fi; setexpr dst $loadaddr + 0x$off; if ext4load ${BOOTDEV} ${dst} ${FILE} 0x$sz 0x$off; then echo "chunk @$off len=$sz -> dst=$dst"; md.b ${dst} 0x$sz; else setenv ok 0; echo "read fail @$off"; fi; setexpr off 0x$off + 0x$sz; done
=> echo "result: $ok"   # 루프 전체 성공 여부(모든 청크 성공이면 1).
=> echo "off(hex)=$off, total(hex)=0x$TOTAL"    # 최종 오프셋과 전체 길이를 같은 16진 표기로 출력(둘이 같아야 정상).
```
- `while test 0x$off -lt 0x$TOTAL; do ... done` — 종료 조건: `off < total` (양쪽에 0x 접두로 16진 안전 비교).
    - `setexpr rem 0x$TOTAL - 0x$off` — 남은 길이 계산.
    - `setenv sz $CHUNK; if test 0x$rem -lt 0x$CHUNK; then setenv sz $rem; fi;` — 마지막 조각은 남은 길이만큼으로 축소.
    - `setexpr dst $loadaddr + 0x$off` — 이번 청크를 쓸 목적지 주소 = 시작주소 + 현재 오프셋. (중요: `$loadaddr` 앞에 추가 0x를 붙이지 않기 — `0x0x...`가 되어 0으로 계산되는 실수를 방지)
    - `if ext4load ${BOOTDEV} ${dst} ${FILE} 0x$sz 0x$off; then ... else ... fi` — `offset`에서 `sz`바이트 읽어 `dst`에 배치. 실패 시 `ok=0`.
    - `md.b ${dst} 0x$sz` — 이번 청크 덤프(디버깅 가독성용).
    - `setexpr off 0x$off + 0x$sz` — 오프셋 갱신.<br>

검증(동등성 + CRC)
```bash
=> if test 0x$off -eq 0x$TOTAL; then echo "EQUAL"; else echo "DIFF"; fi # 실제 숫자 비교로 끝까지 읽었는지 확인(EQUAL이면 OK).

=> echo "off=0x$off, total=0x$TOTAL"    # 보기 좋게 0x 접두사 붙여서 동일성 재확인.

=> crc32 ${loadaddr} 0x$TOTAL   # 청크로 이어붙여 완성된 메모리 버퍼의 CRC32 계산 → 초기 기준 CRC와 일치하면 완벽.
```