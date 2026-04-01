#!/bin/bash
# Скрипт для збірки XRT та XDNA plugin на Fedora 44 (GCC 16+)
# Автор: Jules (AI Assistant)

set -e

echo "=========================================================="
echo " Початок збірки XDNA Driver User-space для Fedora 44"
echo "=========================================================="

# 1. Встановлення системних залежностей
echo "[1/6] Встановлення залежностей через DNF..."
sudo dnf install -y --allowerasing \
    boost-devel boost-static cmake gcc-c++ libdrm-devel vulkan-devel \
    rapidjson-devel python3-devel python3-pip pybind11-devel \
    python3-pybind11 elfutils-devel json-glib-devel ncurses-devel \
    ocl-icd-devel opencl-headers protobuf-compiler protobuf-devel \
    systemd-devel wget jq git make

# 2. Клонування репозиторію
if [ ! -d "xdna-driver" ]; then
    echo "[2/6] Клонування репозиторію xdna-driver..."
    git clone --recursive https://github.com/amd/xdna-driver.git
    cd xdna-driver
else
    echo "[2/6] Використання існуючої папки xdna-driver. Оновлення субмодулів..."
    cd xdna-driver
    git submodule update --init --recursive
fi

# 3. Виправлення помилки memory_order для GCC 16 (C++20+)
echo "[3/6] Застосування hotfix для std::memory_order..."
# Виправляємо як повний шлях, так і скорочений до стандарту C++20, ігноруючи .git
find . -type d -name ".git" -prune -o -type f \( -name "*.cpp" -o -name "*.h" \) -exec sed -i 's/std::memory_order::memory_order_seq_cst/std::memory_order::seq_cst/g' {} +
find . -type d -name ".git" -prune -o -type f \( -name "*.cpp" -o -name "*.h" \) -exec sed -i 's/std::memory_order_seq_cst/std::memory_order::seq_cst/g' {} +

# 4. Пряма збірка XRT (NPU-only mode) через CMake
echo "[4/6] Збірка XRT (NPU mode)..."
mkdir -p xrt/build_npu
cd xrt/build_npu
# Використовуємо прямий виклик CMake, оскільки оригінальний build.sh має проблеми з парсингом аргументів
cmake -DXRT_NPU=1 \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/usr \
      ..
make -j$(nproc)
echo "Встановлення XRT..."
sudo make install
cd ../..

# 5. Збірка XDNA Plugin
echo "[5/6] Збірка XDNA Plugin..."
# У репозиторії xdna-driver скрипт build.sh знаходиться в корені, а не в папці build/
# -release: створює папку Release/ з результатом збірки
# -nokmod: драйвер вже є в ядрі 6.19
./build.sh -release -nokmod

# 6. Встановлення XDNA Plugin
echo "[6/6] Встановлення XDNA Plugin в систему..."
cd Release
sudo make install

echo "=========================================================="
echo " Збірка успішно завершена!"
echo " Спробуйте запустити: xrt-smi examine"
echo "=========================================================="
