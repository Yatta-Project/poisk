# Vicinae (Vala Native Edition)

**Vicinae-Vala** — это сверхбыстрый нативный лаунчер и командная палитра для Linux (с глубокой интеграцией в **GNOME** и **Pantheon / elementary OS**), полностью переписанный на **Vala**, **GTK4**, **Libadwaita** и **Granite 7**.

В отличие от оригинального Vicinae, здесь полностью устранены тяжёлые зависимости от Node.js, React и npm. Оставлена и расширена поддержка **Raycast Script Commands** (Bash, Python, Ruby и др.) и режим **dmenu**.

---

## ⚡ Особенности и преимущества

- **Мгновенный отклик и лёгкость**: холодный запуск за миллисекунды, потребление памяти ~25–35 МБ (вместо сотен мегабайт у JS/Electron решений).
- **Нативный дизайн**: использует Libadwaita и Granite 7, динамически адаптируется под системную тёмную тему и скругления окон.
- **Глубокая интеграция с GNOME Shell и Pantheon**:
  - Управление открытыми окнами (фокус, переключение) через D-Bus.
  - Буфер обмена GNOME Shell / локальная история SQLite.
- **Модульная архитектура провайдеров**:
  1. **Приложения**: индексация `.desktop`-файлов, умный нечёткий поиск (fuzzy match) и ранжирование по частоте запусков.
  2. **Окна**: переключение между активными окнами рабочего стола.
  3. **Буфер обмена**: сохранение истории скопированных фрагментов и быстрый поиск по ним.
  4. **Калькулятор**: мгновенный расчёт математических выражений (`2 + 2 * 5`, `sqrt(144)`, `sin(pi/2)`, `2^10` и т.д.) с копированием результата по Enter.
  5. **Raycast Script Commands**: полная совместимость с Raycast-скриптами на любом языке.
  6. **dmenu mode**: потоковый режим пайпинга (`echo -e "one\ntwo" | vicinae --dmenu`).

---

## 🚀 Управление и горячие клавиши

- `↵ Enter` — выполнить действие / запустить выбранный элемент.
- `⎋ Escape` — скрыть лаунчер.
- `↑ / ↓` — навигация по списку результатов.
- Превью-панель справа динамически отображает подробности, метаданные и подсказки.

### Назначение глобального хоткея (например, Super + Space)

В **GNOME Settings** -> **Keyboard** -> **Keyboard Shortcuts** -> **Custom Shortcuts**:
- **Название**: Vicinae
- **Команда**: `vicinae --toggle`
- **Комбинация клавиш**: `Super + Space` (или любое другое удобное сочетание)

При первом запуске процесс работает в фоновом режиме, а последующие вызовы `vicinae --toggle` мгновенно показывают или скрывают палитру без повторной инициализации.

---

## 📜 Raycast Script Commands

Все скрипты помещаются в каталог `~/.config/vicinae/scripts/` и должны иметь флаг исполняемости (`chmod +x script.sh`).

Поддерживаются стандартные метаданные Raycast в шапке скрипта:
```bash
#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Мой скрипт
# @raycast.mode compact
#
# Optional parameters:
# @raycast.icon preferences-system
# @raycast.packageName Утилиты
# @raycast.description Описание действия

echo "Результат работы"
```

Пример готового скрипта уже создан в:
`~/.config/vicinae/scripts/system_info.sh`

---

## 🛠 Сборка и установка

### Зависимости (Fedora):
```bash
sudo dnf install vala gtk4-devel libadwaita-devel granite-7-devel sqlite-devel json-glib-devel meson ninja-build
```

### Сборка:
```bash
meson setup build
ninja -C build
```

### Запуск и тестирование:
```bash
./build/vicinae --toggle
```

### Режим dmenu:
```bash
echo -e "Alpha\nBeta\nGamma" | vicinae --dmenu
```

---

## 📁 Структура проекта

```
vicinae-vala/
├── meson.build
├── data/
│   └── org.vicinae.launcher.desktop
└── src/
    ├── main.vala                     # Точка входа, GApplication, IPC, dmenu
    ├── core/
    │   ├── item.vala                 # Модель элемента SearchItem
    │   ├── provider.vala             # Интерфейс SearchProvider
    │   ├── database.vala             # Локальная база SQLite (история, частоты)
    │   └── search_engine.vala        # Нечёткий поиск (fuzzy score), сортировка
    ├── bridges/
    │   ├── desktop_bridge.vala       # Базовый мост окружения рабочего стола
    │   ├── gnome_bridge.vala         # D-Bus мост к GNOME Shell
    │   └── pantheon_bridge.vala      # D-Bus мост к Gala / Pantheon
    ├── providers/
    │   ├── app_provider.vala         # Поиск приложений через GAppInfo
    │   ├── window_provider.vala      # Управление окнами
    │   ├── clipboard_provider.vala   # История буфера обмена
    │   ├── calc_provider.vala        # Математический калькулятор
    │   ├── script_provider.vala      # Raycast Script Commands
    │   └── dmenu_provider.vala       # Потоковый выбор stdin -> stdout
    └── ui/
        ├── result_row.vala           # Виджет строки результата
        ├── preview_pane.vala         # Боковая панель предпросмотра
        └── window.vala               # Плавающее окно поиска AdwApplicationWindow
```
