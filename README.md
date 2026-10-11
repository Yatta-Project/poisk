# Поиск (Poisk)

<p align="center">
  <b>GTK-ориентированный лёгкий аналог Spotlight для Linux (Pantheon, GNOME, Cinnamon)</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-1.1.0-blue.svg" alt="Version 1.1.0" />
  <img src="https://img.shields.io/badge/license-GPL--3.0--or--later-green.svg" alt="License" />
  <img src="https://img.shields.io/badge/platform-Wayland%20%7C%20X11-orange.svg" alt="Platform Wayland / X11" />
  <img src="https://img.shields.io/badge/GTK-4.12+-purple.svg" alt="GTK4" />
  <img src="https://img.shields.io/badge/elementary%20OS-7%20%7C%208-teal.svg" alt="Pantheon" />
</p>

---

## ⚡ О проекте

**Поиск (Poisk)** — легковесный, моментальный GTK-ориентированный системный лаунчер (аналог macOS Spotlight), созданный на **Vala**, **GTK4**, **Libadwaita** и **Granite 7**. Разработан специально для комфортной работы в современных окружениях Linux: нативно интегрируется в **elementary OS (Pantheon)**, **GNOME Shell** и **Cinnamon**, предлагая эстетику системного дока, аппаратное размытие (frosted glass), плавную кинетическую прокрутку и скорость отклика менее 5 миллисекунд.

---

## 🌟 Ключевые возможности

### 🎨 Два стиля компоновки (Aesthetics)
* **Монолитная капсула (Monolithic Capsule):**
  - Единая выверенная капсула поиска с встроенным системным логотипом.
  - **Pixel-Perfect геометрия:** строгий шаг в 16px между всеми элементами:
    $$\text{Внешний край} \xrightarrow{16\text{ px}} [\text{Иконка ОС 24px}] \xrightarrow{16\text{ px}} [\text{Сепаратор 1px}] \xrightarrow{16\text{ px}} [\text{Текст ввода}]$$
* **Островной режим (Island Mode):**
  - Раздельная компоновка: поисковая капсула и парящий спутник-логотип (Satellite Button) с мягким объёмным свечением.

### 🔮 Эффект матового стекла (Frosted Glass)
* Аппаратный шейдерный блюр на стороне композитора (в GNOME — через расширение, в Pantheon — через протокол Wayland).
* Плавная регулировка прозрачности (50%–100%) и радиуса размытия (4–64px).
* Реакция на общесистемный режим *«Уменьшить прозрачность»* (`.reduce-transparency`).

### ⌨️ Умное управление горячими клавишами
* **Вызов по одиночному нажатию `Super`:** чистый перехват на уровне композитора без помех системным комбинациям (`Super+Tab`, `Super+Space`).
* **Произвольные сочетания клавиш:** возможность назначить любую комбинацию (например, `Ctrl+Space`) или отдельную клавишу прямо в графических параметрах с живой записью хоткея.

### 🔍 Фокус на поиске и продуктивности
* 🚀 **Приложения:** мгновенный поиск по desktop-файлам, умное ранжирование по частоте запусков.
* 🪟 **Открытые окна:** переключение между активными окнами без задержек.
* 🔢 **Встроенный калькулятор:** моментальный подсчёт математических выражений (`2 + 2 * 5`, `sqrt(144)`, `sin(pi/2)`).

### ⚙️ Нативная системная интеграция
* **elementary OS (Switchboard):** встроенный модуль настроек (`libpoisk.so`) в категории **«Личные»** системных параметров elementary OS.
* **GNOME Shell:** комплектное расширение с поддержкой GNOME 45–48 и нативной страницей настроек `Adw.PreferencesPage`.
* **Фоновый демон:** запуск через пользовательский `systemd.service` — окно предзагружено в памяти и появляется мгновенно (<5 мс).

---

## 📦 Установка и пакеты

Готовые бинарные пакеты доступны на странице [Releases](https://github.com/Yatta-Project/poisk/releases):

### Fedora / RHEL / openSUSE (RPM)
```bash
sudo dnf install ./poisk-1.1.0-1.x86_64.rpm
```

### Ubuntu / Debian / elementary OS (DEB)
```bash
sudo dpkg -i ./poisk_1.1.0_amd64.deb
sudo apt-get install -f
```

### Arch Linux (AUR / PKGBUILD)
```bash
git clone https://github.com/Yatta-Project/poisk.git
cd poisk/packaging
makepkg -si
```

### Nix / NixOS
```bash
nix-shell
# или сборка деривации:
nix-build
```

---

## 🛠 Сборка из исходников

### Зависимости:
* `vala >= 0.56`
* `meson >= 0.60`, `ninja-build`
* `gtk4 >= 4.12`
* `libadwaita-1 >= 1.5`
* `granite-7 >= 7.0`
* `json-glib-1.0`, `sqlite3`, `wayland-client`

### Компиляция:
```bash
git clone https://github.com/Yatta-Project/poisk.git
cd poisk
meson setup build
ninja -C build
sudo ninja -C build install
```

---

## 🚀 Настройка автозапуска (systemd)

Для мгновенного отклика лаунчер работает в фоновом режиме через пользовательскую службу `systemd`:

```bash
systemctl --user daemon-reload
systemctl --user enable --now poisk.service
```

Проверить статус:
```bash
systemctl --user status poisk.service
```

Вызов лаунчера вручную или из скрипта:
```bash
poisk --toggle
```

Параметры лаунчера:
```bash
poisk --preferences
```

---

## 🧩 Расширение GNOME Shell

Для работы эффекта размытия фона и перехвата клавиши в GNOME Shell используйте входящее в состав расширение:
* Папка расширения: `data/gnome-shell-extension`
* UUID: `poisk-blur@mrlogiousbanana.github.io`
* Установка вручную:
  ```bash
  mkdir -p ~/.local/share/gnome-shell/extensions/poisk-blur@mrlogiousbanana.github.io
  cp -r data/gnome-shell-extension/* ~/.local/share/gnome-shell/extensions/poisk-blur@mrlogiousbanana.github.io/
  gnome-extensions enable poisk-blur@mrlogiousbanana.github.io
  ```

---

## 📜 Лицензия

Проект распространяется под свободной лицензией **GNU General Public License v3.0 (GPL-3.0-or-later)**. Подробности в файле [LICENSE](LICENSE).

---

## 🤝 Организация

Разрабатывается в рамках [Yatta-Project](https://github.com/Yatta-Project).
