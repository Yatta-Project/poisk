Name:           poisk
Version:        1.1.0
Release:        1%{?dist}
Summary:        Fast native application launcher and command palette for Pantheon and Linux

License:        GPL-3.0-or-later
URL:            https://github.com/Yatta-Project/poisk
Source0:        https://github.com/Yatta-Project/poisk/releases/download/v%{version}/%{name}-%{version}.tar.xz

BuildRequires:  meson >= 0.60.0
BuildRequires:  ninja-build
BuildRequires:  gcc
BuildRequires:  vala >= 0.56.0
BuildRequires:  pkgconfig
BuildRequires:  pkgconfig(glib-2.0) >= 2.76
BuildRequires:  pkgconfig(gobject-2.0)
BuildRequires:  pkgconfig(gio-2.0)
BuildRequires:  pkgconfig(gio-unix-2.0)
BuildRequires:  pkgconfig(gtk4) >= 4.12
BuildRequires:  pkgconfig(libadwaita-1) >= 1.5
BuildRequires:  pkgconfig(granite-7) >= 7.0
BuildRequires:  pkgconfig(json-glib-1.0)
BuildRequires:  pkgconfig(sqlite3)
BuildRequires:  pkgconfig(wayland-client)
BuildRequires:  pkgconfig(gtk4-wayland)
BuildRequires:  systemd-rpm-macros

Requires:       glib2 >= 2.76
Requires:       gtk4 >= 4.12
Requires:       libadwaita-1 >= 1.5
Requires:       granite-7 >= 7.0
Requires:       hicolor-icon-theme

%description
Poisk is a fast, keyboard-centric application launcher and productivity palette
for Linux with first-class elementary OS (Pantheon) and GNOME Shell support.
Crafted natively with Vala, GTK4, Libadwaita, and Granite 7.

Features:
- Pure Wayland architecture with GPU frosted glass blur
- Dual aesthetics: Monolithic capsule with pixel-perfect alignment and Island mode
- Instant Super key tap or custom shortcut invocation
- Elementary OS Switchboard integration plug
- GNOME Shell extension integration
- Sub-5ms launch latency with persistent background daemon

%prep
%autosetup -n %{name}-%{version}

%build
%meson
%meson_build

%install
%meson_install

%post
%systemd_user_post poisk.service

%preun
%systemd_user_preun poisk.service

%postun
%systemd_user_postun_with_restart poisk.service

%files
%license LICENSE
%doc README.md
%{_bindir}/poisk
%{_datadir}/applications/io.github.mrlogiousbanana.poisk*.desktop
%{_datadir}/glib-2.0/schemas/io.github.mrlogiousbanana.poisk.gschema.xml
%{_userunitdir}/poisk.service
%dir %{_datadir}/gnome-shell/extensions/poisk-blur@mrlogiousbanana.github.io
%{_datadir}/gnome-shell/extensions/poisk-blur@mrlogiousbanana.github.io/*

%changelog
* Sun Oct 11 2026 MrLogiousBanana <mrlogiousbanana@gmail.com> - 1.1.0-1
- App group manager with custom emojis and hidden apps
- Kinetic smooth scrolling and GSK linear gradient dissolution
- Native window control bridges for GNOME and Cinnamon
- Cinnamon Settings preferences desktop entry and autostart integration

* Sun Oct 11 2026 MrLogiousBanana <mrlogiousbanana@gmail.com> - 1.0.0-1
- Initial release of Poisk 1.0.0 for Fedora/RHEL
