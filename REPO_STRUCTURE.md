# Аналіз структури репозиторію xdna-driver (квітень 2026)

Цей аналіз проведено для збірки XRT та XDNA plugin на Fedora 44 (GCC 16+).

## 1. Дерево каталогів (основні папки)

```text
xdna-driver/
├── build/                 # Інструменти збірки XDNA плагіна (НЕ самого XRT)
│   ├── build.sh           # Скрипт збірки плагіна та драйвера (підтримує -release, -nokmod)
│   └── build_ve2.sh
├── drivers/               # Модуль ядра amdxdna (в Fedora 44 вже є в ядрі 6.19)
├── include/               # Заголовні файли
├── src/                   # Код плагіна (shim)
│   └── shim/
│       └── umq/           # Місцезнаходження hwq.cpp та dbg_hwq.cpp (memory_order error)
├── test/                  # Юніт-тести
├── tools/                 # Скрипти залежностей (amdxdna_deps.sh)
├── xrt/                   # Субмодуль Xilinx Runtime (XRT)
│   ├── build/
│   │   └── build.sh       # Скрипт збірки XRT (підтримує -npu, -opt)
│   ├── src/               # Код XRT
│   └── CMakeLists.txt
├── CMakeLists.txt
└── README.md
```

## 2. Аналіз скриптів `build.sh`

### A. XRT Build Script: `xrt/build/build.sh`
Цей скрипт збирає ядро рантайму.
*   **Локація:** `xdna-driver/xrt/build/build.sh`
*   **Ключові параметри:**
    *   `-npu`: Збірка ТІЛЬКИ для NPU (XDNA2).
    *   `-opt`: Оптимізована збірка (Release).
    *   `-install_prefix <path>`: Шлях встановлення (рекомендовано `/usr` для Fedora).

### B. XDNA Plugin Build Script: `build/build.sh`
Цей скрипт збирає "міст" (shim) між XRT та драйвером ядра.
*   **Локація:** `xdna-driver/build/build.sh`
*   **Ключові параметри:**
    *   `-release`: Збірка Release версії плагіна.
    *   `-nokmod`: **НЕ збирати** модуль ядра (оскільки він уже є в ядрі Fedora 44).

## 3. Файли з помилкою `memory_order_seq_cst`

Помилка виникає у вихідному коді плагіна через використання застарілих констант `std::memory_order::memory_order_seq_cst`.
**Точні шляхи:**
1.  `xdna-driver/src/shim/umq/hwq.cpp`
2.  `xdna-driver/src/shim/umq/dbg_hwq.cpp`

**Рішення для GCC 16 (C++20+):** заміна на `std::memory_order::seq_cst` або `std::memory_order_seq_cst`.

## 4. Порядок збірки для Fedora 44

1.  **Патчинг:** Заміна `memory_order` у папці `src/shim/umq/`.
2.  **XRT:** Збірка через `xrt/build/build.sh -npu -opt` з префіксом `/usr`.
3.  **XDNA Plugin:** Збірка через `build/build.sh -release -nokmod`.
