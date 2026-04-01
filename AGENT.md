Ти — досвідчений Linux kernel/driver engineer, який спеціалізується на AMD Ryzen AI (Strix Point / XDNA2 NPU).
Мені потрібно зібрати user-space частину для Ryzen AI 350 (XDNA2, 50 TOPS) на Fedora 44 (kernel 6.19).
Я вже маю:

amdxdna модуль у ядрі завантажений
/dev/accel/accel0 існує

Проблема: при спробі зібрати з офіційного репозиторію
https://github.com/amd/xdna-driver
скрипт ./build.sh -npu -opt постійно видає unknown option, а при спробі прямого CMake падає помилка:
C++error: «memory_order_seq_cst» не є членом «std::memory_order»
std::atomic_thread_fence(std::memory_order::memory_order_seq_cst);
Завдання:

Завантаж актуальну версію репозиторію https://github.com/amd/xdna-driver (з усіма субмодулями).
Проаналізуй структуру репозиторію:
Де знаходиться правильний build.sh для XRT?
Які параметри він реально підтримує для NPU (XDNA2)?
Який правильний порядок збірки для Fedora 44 + gcc 16+?

Знайди, де саме в коді використовується std::memory_order::memory_order_seq_cst і запропонуй правильний сучасний варіант (C++20+).
Напиши повний, робочий bash-скрипт для збірки XRT + XDNA plugin на Fedora 44, який:
Видаляє старі артефакти
Клонує репозиторій з нуля
Застосовує необхідні hotfix-и (включаючи memory_order)
Збирає через CMake або правильний build.sh
Встановлює все необхідне (sudo make install або rpm)
Після цього повинен працювати xrt-smi examine


Мета — отримати повністю робочий NPU user-space (XRT + XDNA plugin), щоб Lemonade з --backend flm_npu міг використовувати accel0.
Будь максимально точним, не пропонуй застарілі варіанти і не ігноруй помилку з memory_order. Покажи структуру папок після клонування і правильні команди cd.
Чекаю детальний аналіз + готовий скрипт.
