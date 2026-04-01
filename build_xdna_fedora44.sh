#!/bin/bash
# Скрипт для збірки XRT та XDNA plugin на Fedora 44 (GCC 16+)
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

# 2. Встановлення залежностей
log_info "Встановлення системних залежностей через DNF..."
sudo dnf install -y --allowerasing \
    boost-devel boost-static cmake gcc-c++ libdrm-devel vulkan-devel \
    rapidjson-devel python3-devel python3-pip pybind11-devel \
    python3-pybind11 elfutils-devel json-glib-devel ncurses-devel \
    ocl-icd-devel opencl-headers protobuf-compiler protobuf-devel \
    systemd-devel wget jq git make

log_info "Запуск amdxdna_deps.sh..."
sudo ./tools/amdxdna_deps.sh || log_warn "amdxdna_deps.sh завершився з попередженням (можливо, через специфіку Fedora 44)"

# 3. Патчинг memory_order для GCC 16 (C++20+)
log_info "Застосування патча memory_order_seq_cst для GCC 16..."
FILES_TO_PATCH=("src/shim/umq/hwq.cpp" "src/shim/umq/dbg_hwq.cpp")

for FILE in "${FILES_TO_PATCH[@]}"; do
    if [ -f "$FILE" ]; then
        log_info "Патчинг $FILE..."
        sed -i 's/std::memory_order::memory_order_seq_cst/std::memory_order::seq_cst/g' "$FILE"
        sed -i 's/std::memory_order_seq_cst/std::memory_order::seq_cst/g' "$FILE"
    else
        log_err "Файл $FILE не знайдено!"
    fi
done

# 4. Збірка XRT
log_info "Перехід до збірки XRT (Xilinx Runtime)..."
cd xrt/build

# Спроба збірки з -npu
log_info "Спроба збірки з параметром -npu..."
if ! ./build.sh -npu -opt -j$(nproc); then
    log_warn "Параметр -npu не підтримується або виникла помилка. Спроба fallback: -opt..."
    ./build.sh -opt -j$(nproc)
fi

# Встановлення XRT
if [ -d "Release" ]; then
    cd Release
    log_info "Встановлення зібраного XRT..."
    # Спробуємо знайти RPM, якщо ні - make install
    if ls *.rpm 1> /dev/null 2>&1; then
        sudo rpm -i --force --nodeps *.rpm || sudo dnf install -y ./*.rpm
    else
        log_warn "RPM пакети не знайдено в Release, виконуємо sudo make install..."
        sudo make install
    fi
    cd ../../..
else
    log_err "Папку xrt/build/Release не знайдено. Збірка XRT не вдалася!"
    exit 1
fi

# 5. Збірка XDNA Plugin
log_info "Перехід до збірки XDNA Plugin (shim)..."
cd build # Це папка xdna-driver/build/

log_info "Запуск збірки плагіна з -release -nokmod..."
./build.sh -release -nokmod

# Встановлення XDNA Plugin
if [ -d "Release" ]; then
    cd Release
    log_info "Встановлення XDNA Plugin..."
    sudo make install
    cd ../..
else
    log_err "Папку build/Release не знайдено. Збірка плагіна не вдалася!"
    exit 1
fi

# 6. Фінальні інструкції
echo -e "${GREEN}================================================================${NC}"
echo -e "${GREEN} Збірка та встановлення завершені успішно! ${NC}"
echo -e "${GREEN}================================================================${NC}"
echo -e "${YELLOW}Для активації змін виконайте наступні кроки:${NC}"
echo -e "1. ${YELLOW}sudo reboot${NC} (обов'язково для оновлення лімітів пам'яті)"
echo -e "2. Перевірте статус NPU:${NC}"
echo -e "   ${GREEN}ls -l /sys/class/accel/accel0${NC}"
echo -e "   ${GREEN}xrt-smi examine${NC}"
echo -e "3. Для Lemonade використовуйте:${NC}"
echo -e "   ${GREEN}--backend flm_npu${NC}"
echo -e "${YELLOW}================================================================${NC}"
