#!/bin/bash
#
# Enhanced compile script for Xiaomi_kernel_odin (Automated & Interactive)
# This script is based on Ubuntu 20.04+
# Copyright (C) 2023-2025 Ruoqing

# 字体颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 脚本说明（非交互式模式隐藏）
if [ "$NON_INTERACTIVE" != "1" ]; then
    echo -e "${YELLOW}==================================================${NC}"
    echo -e "${YELLOW}                脚本说明              ${NC}"
    echo -e "${YELLOW}                                      ${NC}"
    echo -e "${YELLOW}             作者: 情若相惜 ღ             ${NC}"
    echo -e "${YELLOW}             QQ群：290495721          ${NC}"
    echo -e "${YELLOW}            Ubuntu版本：20.04+         ${NC}"
    echo -e "${YELLOW}==================================================${NC}"
fi

# 全局变量（路径统一管理）
CURRENT_DIR=$(pwd)
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

# 内核配置（固定defconfig，移除交互式menuconfig）
DEFCONFIG="odin_defconfig"

# 解析命令行参数（-n 非交互式模式）
NON_INTERACTIVE=0
while getopts "n" opt; do
    case $opt in
        n) NON_INTERACTIVE=1 ;;
        *) echo "Usage: $0 [-n]"; exit 1 ;;
    esac
done

# 生成ZIP文件名（兼容Git环境和普通环境）
if [ -d "${KERNEL_DIR}/.git" ]; then
    GIT_COMMIT_HASH=$(git -C "${KERNEL_DIR}" rev-parse --short=7 HEAD)
    ZIP_NAME="MIX4-5.4.289-g${GIT_COMMIT_HASH}.zip"
else
    CURRENT_TIME=$(date '+%Y%m%d%H%M')
    ZIP_NAME="MIX4-5.4.289-${CURRENT_TIME}.zip"
fi

# 安装依赖（适配Ubuntu 20.04+，移除重复包）
install() {
    dependencies=(git ccache automake flex lzop bison gperf build-essential zip curl zlib1g-dev zlib1g-dev:i386 g++-multilib python3-networkx libxml2-utils bzip2 libbz2-dev squashfs-tools pngcrush schedtool dpkg-dev liblz4-tool make optipng maven libssl-dev pwgen libswitch-perl policycoreutils minicom libxml-sax-base-perl libxml-simple-perl bc libc6-dev-i386 lib32ncurses5-dev x11proto-core-dev libx11-dev lib32z1-dev libgl1-mesa-dev xsltproc unzip openjdk-17-jdk)
    if [ "$NON_INTERACTIVE" = "1" ]; then
        sudo apt update -y && sudo apt install -y "${dependencies[@]}"
    else
        missing=0
        for pkg in "${dependencies[@]}"; do
            if ! dpkg -s "$pkg" >/dev/null 2>&1; then
                missing=1
            fi
        done
        if [ "$missing" = '1' ]; then
            sudo apt update -y && sudo apt install -y "${dependencies[@]}"
        fi
    fi
}

# 配置Git用户信息（自动化场景无需交互）
email() {
    git config --global user.name "ruoqing501"
    git config --global user.email "liangxiaobo501@gmail.com"
}

# 环境变量（核心编译参数）
path() {
    export KBUILD_BUILD_USER="18201329"
    export KBUILD_BUILD_HOST="qq.com"
    export PATH="${CLANG_DIR}/bin:${GCC64_DIR}/bin:${GCC_DIR}/bin:$PATH"
    # 核心编译参数（与GitHub Actions同步）
    export BUILD_ARGS="-j$(nproc) O=out CC=clang ARCH=arm64 SUBARCH=arm64 LD=ld.lld AR=llvm-ar NM=llvm-nm STRIP=llvm-strip OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump READELF=llvm-readelf HOSTCC=clang HOSTCXX=clang++ HOSTAR=llvm-ar HOSTLD=ld.lld CLANG_TRIPLE=aarch64-linux-gnu- CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_COMPAT=arm-linux-gnueabi- LLVM=1 LLVM_IAS=1"
}

# ROOT方案选择（支持环境变量传入，非交互式模式优先）
root() {
    # 从环境变量获取用户选择（GitHub Actions传入）
    if [ "$NON_INTERACTIVE" = "1" ]; then
        choice="${ROOT_CHOICE:-1}"  # 默认选项1（Kernelsu-next）
    else
        echo -e "${YELLOW}--------------------------------------------------${NC}"
        echo "请选择启用哪种 ROOT 方式（非交互式模式请通过环境变量ROOT_CHOICE传入1-4）："
        echo -e "${YELLOW}1. Kernelsu-next+susfs${NC}"
        echo -e "${YELLOW}2. Kernelsu Stable+susfs${NC}"
        echo -e "${YELLOW}3. SukiSU Ultra+susfs${NC}"
        echo -e "${YELLOW}4. MKSU Root+susfs${NC}"
        echo -e "${YELLOW}--------------------------------------------------${NC}"
        read -p "请输入选项（1/2/3/4，默认1）：" choice
        choice="${choice:-1}"  # 默认选项1
    fi

    rm -rf "${ROOT_DIR}" "${KERNEL_DIR}/ksuversion"
    local KPM=0  # 控制SukiSU的patch

    case $choice in
        1)
            cp -r "${KSU_NEXT_DIR}/kernelsu" "${ROOT_DIR}"
            local name="Kernelsu-next+susfs"
            ;;
        2)
            cp -r "${KSU_DIR}/kernelsu" "${ROOT_DIR}"
            cp -r "${KSU_DIR}/ksuversion" "${KERNEL_DIR}/ksuversion"
            local name="Kernelsu Stable+susfs"
            ;;
        3)
            cp -r "${SUKISU_DIR}/kernelsu" "${ROOT_DIR}"
            local name="SukiSU Ultra+susfs"
            KPM=1
            ;;
        4)
            cp -r "${MKSU_DIR}/kernelsu" "${ROOT_DIR}"
            local name="MKSU Root+susfs"
            ;;
        *)
            echo -e "${RED}无效的选项，退出脚本...${NC}"
            exit 1
            ;;
    esac

    if [ "$NON_INTERACTIVE" != "1" ]; then
        echo -e "${YELLOW}--------------------------------------------------${NC}"
        echo -e "${GREEN}启用选项：$name ${NC}"
        echo -e "${YELLOW}--------------------------------------------------${NC}"
    fi
    export KPM_FLAG=$KPM  # 导出到环境变量供打包使用
}

# 编译内核（移除menuconfig，仅保留自动化配置）
build() {
    cd "${KERNEL_DIR}"
    echo -e "${YELLOW}开始生成内核配置...${NC}"
    make ${BUILD_ARGS} ${DEFCONFIG}
    make ${BUILD_ARGS} savedefconfig  # 保存配置，跳过menuconfig
    cp out/defconfig arch/arm64/configs/${DEFCONFIG}

    echo -e "${YELLOW}开始编译内核...${NC}"
    START_TIME=$(date +%s)
    if ! make ${BUILD_ARGS} 2>&1 | tee "${CURRENT_DIR}/kernel.log"; then
        echo -e "${RED}编译失败，请检查代码后重试...${NC}"
        exit 1
    fi
    END_TIME=$(date +%s)
    echo -e "${GREEN}编译耗时：$((END_TIME - START_TIME)) 秒${NC}"
}

# 打包内核（整合模块和镜像）
package() {
    cd "${KERNEL_DIR}"
    echo -e "${YELLOW}开始处理内核模块...${NC}"
    if grep -q '=m' "out/.config"; then
        make ${BUILD_ARGS} INSTALL_MOD_PATH=modules INSTALL_MOD_STRIP=1 modules_install
        cd "${ANYKERNEL_DIR}"
        # 复制模块文件
        cp $(find "../out/modules/lib/modules/5.4*" -name '*.ko') "${MODULES_DIR}"
        cp "../out/modules/lib/modules/5.4"/modules.{alias,dep,softdep} "${MODULES_DIR}"
        cp "../out/modules/lib/modules/5.4"/modules.order "${MODULES_DIR}/modules.load"
        # 修复模块路径（适配安卓系统目录）
        sed -i 's/.*\///g' "${MODULES_DIR}/modules.load"
        sed -i 's/do.modules=0/do.modules=1/g' anykernel.sh
    fi

    echo -e "${YELLOW}开始打包内核ZIP...${NC}"
    cd "${ANYKERNEL_DIR}"
    cp "${IMAGE_DIR}" "Image"  # 复制内核镜像

    # 处理SukiSU-Ultra的patch（仅选项3启用）
    if [ "$KPM_FLAG" = "1" ]; then
        cp "../root/SukiSU-Ultra/patch_linux" .
        ./patch_linux
        mv -f oImage Image
        rm -f patch_linux
    fi

    # 生成ZIP包（移动到仓库根目录）
    zip -r9 "${ZIP_NAME}" *
    mv "${ZIP_NAME}" "${CURRENT_DIR}"

    END_TIME=$(date +%s)
    COST_TIME=$((END_TIME - START_TIME))
    echo -e "${YELLOW}--------------------------------------------------${NC}"
    echo -e "${GREEN}编译完成...${NC}"
    echo -e "${YELLOW}总耗时：$((COST_TIME / 60)) 分 $((COST_TIME % 60)) 秒${NC}"
    echo -e "${YELLOW}内核文件：${CURRENT_DIR}/${ZIP_NAME}${NC}"
    echo -e "${YELLOW}--------------------------------------------------${NC}"
}

# 清理临时文件（保留编译日志）
clean() {
    rm -rf "${ANYKERNEL_DIR}/Image"
    rm -rf "${MODULES_DIR}/*"
    rm -rf "${KERNEL_DIR}/ksuversion"
    # 保留out目录（如需清理可取消注释）
    # rm -rf "${KERNEL_DIR}/out"
}

# 主程序（流程控制）
main() {
    install
    email
    path
    root
    build
    package
    clean
}

# 执行主函数
main
