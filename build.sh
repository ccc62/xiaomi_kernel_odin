#!/bin/bash
#
# Enhanced compile script for Xiaomi_kernel_odin (Automated & Interactive)
# Copyright (C) 2023-2025 Ruoqing

# 字体颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 脚本说明
if [ "$NON_INTERACTIVE" != "1" ]; then
    echo -e "${YELLOW}==================================================${NC}"
    echo -e "${YELLOW}                脚本说明              ${NC}"
    echo -e "${YELLOW}             作者: 情若相惜             ${NC}"
    echo -e "${YELLOW}             QQ群：290495721          ${NC}"
    echo -e "${YELLOW}            Ubuntu版本：20.04+         ${NC}"
    echo -e "${YELLOW}==================================================${NC}"
fi

# 全局变量（关键：CURRENT_DIR 改为 GITHUB_WORKSPACE 根目录）
CURRENT_DIR="$GITHUB_WORKSPACE"  # 改为根目录，避免 mv same file
KERNEL_DIR="${CURRENT_DIR}/xiaomi_kernel_odin"
CLANG_DIR="${KERNEL_DIR}/scripts/tools/clang-r383902b1"
GCC64_DIR="${KERNEL_DIR}/scripts/tools/aarch64-linux-android-4.9"
GCC_DIR="${KERNEL_DIR}/scripts/tools/arm-linux-androideabi-4.9"
ANYKERNEL_DIR="${KERNEL_DIR}/scripts/tools/AnyKernel3"
IMAGE_DIR="${KERNEL_DIR}/out/arch/arm64/boot/Image"
MODULES_DIR="${ANYKERNEL_DIR}/modules/vendor/lib/modules"
ROOT_DIR="${KERNEL_DIR}/drivers/kernelsu"
KSU_DIR="${KERNEL_DIR}/scripts/tools/root/Kernelsu"
KSU_NEXT_DIR="${KERNEL_DIR}/scripts/tools/root/Kernelsu-next"
SUKISU_DIR="${KERNEL_DIR}/scripts/tools/root/SukiSU-Ultra"
MKSU_DIR="${KERNEL_DIR}/scripts/tools/root/MKSU"

DEFCONFIG="odin_defconfig"

# 参数解析
NON_INTERACTIVE=0
while getopts "n" o; do
    case $o in n) NON_INTERACTIVE=1 ;; *) echo "Usage: $0 [-n]"; exit 1 ;; esac
done

# ZIP 名称
if [ -d "${KERNEL_DIR}/.git" ]; then
    GIT_COMMIT_HASH=$(git -C "${KERNEL_DIR}" rev-parse --short=7 HEAD)
    ZIP_NAME="MIX4-5.4.289-g${GIT_COMMIT_HASH}.zip"
else
    CURRENT_TIME=$(date '+%Y%m%d%H%M')
    ZIP_NAME="MIX4-5.4.289-${CURRENT_TIME}.zip"
fi

# 安装依赖
install() {
    dependencies=(git ccache automake flex lzop bison gperf build-essential zip curl zlib1g-dev zlib1g-dev:i386 g++-multilib python3-networkx libxml2-utils bzip2 libbz2-dev squashfs-tools pngcrush schedtool dpkg-dev liblz4-tool make optipng maven libssl-dev pwgen libswitch-perl policycoreutils minicom libxml-sax-base-perl libxml-simple-perl bc libc6-dev-i386 lib32ncurses5-dev x11proto-core-dev libx11-dev lib32z1-dev libgl1-mesa-dev xsltproc unzip openjdk-17-jdk)
    if [ "$NON_INTERACTIVE" = "1" ]; then
        sudo apt update -y && sudo apt install -y "${dependencies[@]}"
    else
        missing=0
        for pkg in "${dependencies[@]}"; do
            if ! dpkg -s "$pkg" >/dev/null 2>&1; then missing=1; fi
        done
        [ "$missing" = '1' ] && sudo apt update -y && sudo apt install -y "${dependencies[@]}"
    fi
}

email() {
    git config --global user.name "ruoqing501"
    git config --global user.email "liangxiaobo501@gmail.com"
}

path() {
    export KBUILD_BUILD_USER="18201329"
    export KBUILD_BUILD_HOST="qq.com"
    export PATH="${CLANG_DIR}/bin:${GCC64_DIR}/bin:${GCC_DIR}/bin:$PATH"
    export BUILD_ARGS="-j$(nproc) O=out CC=clang ARCH=arm64 SUBARCH=arm64 LD=ld.lld AR=llvm-ar NM=llvm-nm STRIP=llvm-strip OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump READELF=llvm-readelf HOSTCC=clang HOSTCXX=clang++ HOSTAR=llvm-ar HOSTLD=ld.lld CLANG_TRIPLE=aarch64-linux-gnu- CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_COMPAT=arm-linux-gnueabi- LLVM=1 LLVM_IAS=1"
}

root() {
    choice="${ROOT_CHOICE:-1}"
    if [ "$NON_INTERACTIVE" != "1" ]; then
        echo -e "${YELLOW}请选择 ROOT 方式：1-4${NC}"
        read -p "输入（默认1）：" choice
        choice="${choice:-1}"
    fi

    rm -rf "${ROOT_DIR}" "${KERNEL_DIR}/ksuversion"
    KPM=0
    case $choice in
        1) cp -r "${KSU_NEXT_DIR}/kernelsu" "${ROOT_DIR}"; name="Kernelsu-next+susfs" ;;
        2) cp -r "${KSU_DIR}/kernelsu" "${ROOT_DIR}"; cp -r "${KSU_DIR}/ksuversion" "${KERNEL_DIR}/ksuversion"; name="Kernelsu Stable+susfs" ;;
        3) cp -r "${SUKISU_DIR}/kernelsu" "${ROOT_DIR}"; name="SukiSU Ultra+susfs"; KPM=1 ;;
        4) cp -r "${MKSU_DIR}/kernelsu" "${ROOT_DIR}"; name="MKSU Root+susfs" ;;
        *) echo -e "${RED}无效选项！${NC}"; exit 1 ;;
    esac
    [ "$NON_INTERACTIVE" != "1" ] && echo -e "${GREEN}启用：$name${NC}"
    export KPM_FLAG=$KPM
}

build() {
    cd "${KERNEL_DIR}"
    echo -e "${YELLOW}生成配置...${NC}"
    make ${BUILD_ARGS} ${DEFCONFIG}
    make ${BUILD_ARGS} savedefconfig
    cp out/defconfig arch/arm64/configs/${DEFCONFIG}

    echo -e "${YELLOW}开始编译...${NC}"
    START_TIME=$(date +%s)
    if ! make ${BUILD_ARGS} 2>&1 | tee "${CURRENT_DIR}/kernel.log"; then
        echo -e "${RED}编译失败！${NC}"; exit 1
    fi
    END_TIME=$(date +%s)
    echo -e "${GREEN}编译耗时：$((END_TIME - START_TIME)) 秒${NC}"
}

package() {
    cd "${KERNEL_DIR}"
    if grep -q '=m' "out/.config"; then
        make ${BUILD_ARGS} INSTALL_MOD_PATH=modules INSTALL_MOD_STRIP=1 modules_install
        cd "${ANYKERNEL_DIR}"
        cp $(find "../out/modules/lib/modules/5.4*" -name '*.ko') "${MODULES_DIR}"
        cp "../out/modules/lib/modules/5.4"/modules.{alias,dep,softdep} "${MODULES_DIR}"
        cp "../out/modules/lib/modules/5.4"/modules.order "${MODULES_DIR}/modules.load"
        sed -i 's/.*\///g' "${MODULES_DIR}/modules.load"
        sed -i 's/do.modules=0/do.modules=1/g' anykernel.sh
    fi

    echo -e "${YELLOW}打包 ZIP...${NC}"
    cd "${ANYKERNEL_DIR}"
    cp "${IMAGE_DIR}" "Image"

    if [ "$KPM_FLAG" = "1" ]; then
        cp "../root/SukiSU-Ultra/patch_linux" .
        ./patch_linux
        mv -f oImage Image
        rm -f patch_linux
    fi

    # ZIP 输出到根目录
    zip -r9 "${CURRENT_DIR}/${ZIP_NAME}" * -x "out/*" "*/out/*"
    echo -e "${GREEN}ZIP 已生成：${CURRENT_DIR}/${ZIP_NAME}${NC}"
}

clean() {
    rm -rf "${ANYKERNEL_DIR}/Image"
    rm -rf "${MODULES_DIR}/*"
    rm -rf "${KERNEL_DIR}/ksuversion"
}

main() {
    echo -e "${YELLOW}清理 out 目录...${NC}"
    rm -rf "${KERNEL_DIR}/out"

    install
    email
    path
    root
    build
    package
    clean
}

main