# Поиск (Poisk)

**Поиск (Poisk)** — быстрый нативный лаунчер и командная палитра для Linux с первоклассной интеграцией в **Pantheon (elementary OS)** и поддержкой **GNOME**.

Полностью написан на **Vala**, **GTK4**, **Libadwaita** и **Granite 7**.

> Проект вдохновлён концепциями [Vicinae](https://github.com/vicinaehq/vicinae) и полностью переосмыслен как легковесный системный инструмент поиска для экосистемы elementary OS / Pantheon.

---

## ⚡ Особенности

* **Эстетика дока Pantheon:**
  * Полупрозрачный фон с мягким размытием и контурной подсветкой в стиле системного дока (`io.elementary.dock`).
  * Полная адаптация под системную тему: автоматическое переключение светлой/тёмной темы и реакция на системный режим «Уменьшить прозрачность» (`.reduce-transparency`).
* **Только чистый Поиск:**
  * 🚀 **Приложения:** мгновенный запуск, поиск по `.desktop`-файлам, ранжирование по частоте запусков.
  * 🪟 **Открытые окна:** нативное переключение между окнами в Pantheon (Wayland) через D-Bus композитора **Gala** (`org.pantheon.gala.DesktopIntegration`).
  * 🔢 **Калькулятор:** быстрый расчёт математических выражений (`2 + 2 * 5`, `sqrt(144)`, `sin(pi/2)`, `2^10`).
  * 📱 **Сетка приложений (`:apps` / `:menu`):** режим обзора всех установленных программ.
* **Мгновенный вызов по клавише Super:**
  * Демон **`poisk-superd`** на C перехватывает одиночный тап `Super` через подсистему ядра Linux `evdev` (`/dev/input/event*`), не ломая хоткеи (`Super+Tab`, `Super+Space`) и системные жесты.
* **Нулевая задержка открытия (<5 мс):**
  * Процесс лаунчера удерживается в памяти как фоновый демон `poisk`. Окно предзагружено, поэтому при вызове оно отображается моментально.

---

## 🚀 Управление

* `↵ Enter` — запустить выбранное приложение / переключиться на окно / скопировать результат калькулятора.
* `⎋ Escape` — очистить строку поиска / скрыть окно.
* `↑ / ↓` — навигация по списку результатов.
* Клик вне окна — автоматическое скрытие.

---

## 🛠 Сборка и установка

### 1. Стандартные дистрибутивы (elementary OS, Fedora, Ubuntu, Arch)

#### Зависимости:
* `vala >= 0.56`
* `meson >= 0.60`, `ninja`
* `gtk4 >= 4.12`
* `libadwaita-1 >= 1.5`
* `granite-7 >= 7.0`
* `json-glib-1.0`
* `sqlite3`
* `libX11`

#### Сборка:
```bash
meson setup build
ninja -C build
```

#### Установка:
```bash
sudo ninja -C build install
```

#### Запуск:
```bash
poisk --toggle
```

---

### 2. Сборка в NixOS (Опционально)

Сборка через предоставленный `shell.nix`:
```bash
nix-shell --run "meson setup build && ninja -C build"
```

Или сборка пакета:
```bash
nix-build
```

---

## ⌨️ Настройка автозапуска

Шаблоны пользовательских сервисов systemd находятся в каталоге `data/systemd/`:
```bash
mkdir -p ~/.config/systemd/user
cp data/systemd/poisk.service ~/.config/systemd/user/
cp data/systemd/poisk-superd.service ~/.config/systemd/user/

systemctl --user daemon-reload
systemctl --user enable --now poisk.service poisk-superd.service
```

---

## 🔗 Ссылки и благодарности

* **Репозиторий проекта:** [https://github.com/mrlogiousbanana/poisk](https://github.com/mrlogiousbanana/poisk)
* **Оригинальный проект Vicinae:** [https://github.com/vicinaehq/vicinae](https://github.com/vicinaehq/vicinae)

---

## Лицензия

GPL-3.0-or-later.
