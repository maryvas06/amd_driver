#!/bin/bash
# Оновлений скрипт для збірки XRT та XDNA plugin на Fedora 44 (GCC 16+)
# Для Ryzen AI 350 (XDNA2, 50 TOPS)
# Автор: Jules (AI Assistant)

set -e

# Кольори для виводу
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO] $1${NC}"; }
log_warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
log_err()  { echo -e "${RED}[ERROR] $1${NC}"; }

echo -e "${YELLOW}================================================================${NC}"
echo -e "${YELLOW} Початок збірки XDNA Driver User-space для Fedora 44 (GCC 16+) ${NC}"
echo -e "${YELLOW}================================================================${NC}"

# 1. Очищення та клонування
log_info "Очищення старої папки xdna-driver..."
rm -rf xdna-driver

log_info "Клонування xdna-driver (depth 1)..."
git clone --recursive --depth 1 https://github.com/amd/xdna-driver.git
cd xdna-driver

log_info "Оновлення субмодулів..."
git submodule update --init --recursive

# 2. Встановлення МІНІМАЛЬНИХ залежностей
log_info "Встановлення мінімальних залежностей через DNF..."
sudo dnf install -y --allowerasing \
    boost-devel cmake gcc-c++ libdrm-devel \
    python3-devel python3-pip elfutils-devel json-glib-devel \
    ncurses-devel ocl-icd-devel opencl-headers \
    systemd-devel wget jq git make

log_info "Запуск amdxdna_deps.sh (мінімізовано)..."
sudo ./tools/amdxdna_deps.sh || log_warn "Попередження при встановленні залежностей"

# 3. Надійний hotfix для GCC 16 (C++20+)
log_info "Застосування hotfix для всіх .cpp у src/shim/umq/..."
UMQ_SRC_DIR="src/shim/umq"
if [ -d "$UMQ_SRC_DIR" ]; then
    find "$UMQ_SRC_DIR" -type f -name "*.cpp" -exec sed -i 's/std::memory_order::memory_order_seq_cst/std::memory_order::seq_cst/g' {} +
    find "$UMQ_SRC_DIR" -type f -name "*.cpp" -exec sed -i 's/std::memory_order_seq_cst/std::memory_order::seq_cst/g' {} +
    log_info "Hotfix успішно застосовано до всіх файлів у $UMQ_SRC_DIR"
else
    log_err "Папку $UMQ_SRC_DIR не знайдено!"
    exit 1
fi

# 4. Збірка XRT
log_info "Збірка XRT (Xilinx Runtime)..."
cd xrt/build

# Спроба збірки з -npu
log_info "Спроба збірки з параметром -npu..."
if ! ./build.sh -npu -opt -j$(nproc); then
    log_warn "Спроба fallback з параметром -opt..."
    ./build.sh -opt -j$(nproc)
fi

# Встановлення XRT
if [ -d "Release" ]; then
    cd Release
    log_info "Встановлення зібраного XRT..."
    if ls *.rpm 1> /dev/null 2>&1; then
        sudo rpm -i --force --nodeps *.rpm || sudo dnf install -y ./*.rpm
    else
        sudo make install
    fi
    sudo ldconfig

    # Перевірка xrt-smi
    if command -v xrt-smi >/dev/null 2>&1; then
        log_info "xrt-smi знайдено"
    else
        log_warn "xrt-smi не знайдено після встановлення (можливо, не в PATH)"
    fi
    cd ../../..
else
    log_err "Збірка XRT не вдалася!"
    exit 1
fi

# 5. Збірка XDNA Plugin
log_info "Збірка XDNA Plugin..."
cd build

log_info "Запуск збірки плагіна (-release -nokmod)..."
./build.sh -release -nokmod

# Встановлення XDNA Plugin
if [ -d "Release" ]; then
    cd Release
    log_info "Встановлення XDNA Plugin..."
    sudo make install
    sudo ldconfig
    cd ../..
else
    log_err "Збірка плагіна не вдалася!"
    exit 1
fi

# 6. Фінальні перевірки та інструкції
log_info "Фінальна перевірка системи:"
ls -l /dev/accel/accel0 2>/dev/null && log_info "accel0 знайдено" || log_err "accel0 не знайдено (перевірте модуль ядра)"
xrt-smi examine 2>/dev/null && log_info "xrt-smi працює коректно" || log_err "xrt-smi не працює"

echo -e "${GREEN}================================================================${NC}"
echo -e "${GREEN} Збірка успішно завершена! ${NC}"
echo -e "${GREEN}================================================================${NC}"
echo -e "${YELLOW}Для активації змін виконайте:${NC}"
echo -e "1. ${YELLOW}sudo reboot${NC}"
echo -e "2. Перевірте статус:${NC}"
echo -e "   ${GREEN}xrt-smi examine${NC}"
echo -e "   ${GREEN}ls -l /sys/class/accel/${NC}"
echo -e "${YELLOW}================================================================${NC}"
