# Yocto

## 1. 필수 패키지 설치 및 yocto 설치

### 1) 필수 피캐지 설치
```bash
$ sudo apt update && sudo apt install -y \
  gawk wget git diffstat unzip texinfo gcc-multilib build-essential chrpath socat cpio \
  python3 python3-pip python3-pexpect xz-utils debianutils iputils-ping \
  python3-git python3-jinja2 libegl1-mesa libsdl1.2-dev \
  xterm make xsltproc docbook-utils fop dblatex xmlto tree pylint liblz4-tool
```

### 2) Yocto Project 소스 받기 (poky)
```bash
# 폴더 생싱 및 이동
$ mkdir Yocto ; cd Yocto

# poky 다운로드
$ git clone -b kirkstone https://git.yoctoproject.org/poky.git

# 필요한 레이어 받기
# meta-raspberrypi
$ git clone -b kirkstone https://git.openembedded.org/meta-openembedded
$ git clone -b kirkstone https://github.com/agherzan/meta-raspberrypi.git
```

```bash
$ cd poky
# build 환경 적용
$ source oe-init-build-env  # 자동으로 poky/build로 들어감

# 38 라인에
$ vi conf/local.conf
#MACHINE ??= "qemux86-64" 
MACHINE ??= "raspberrypi4"
```

```bash
# 레이어 추가
$ bitbake-layers add-layer ../../meta-openembedded/meta-oe
$ bitbake-layers add-layer ../../meta-openembedded/meta-python
$ bitbake-layers add-layer ../../meta-raspberrypi

# 현재 등록된 레이어 확인
$ bitbake-layers show-layers

# 레이어 제거(필요시)
$ bitbake-layers remove-layer ../../meta-raspberrypi

# 빌드
$ bitbake core-image-minimal
```

## 2. 