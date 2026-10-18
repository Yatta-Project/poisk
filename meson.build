project('poisk', ['c', 'vala'],
  version: '1.1.0',
  license: 'GPL-3.0-or-later',
  meson_version: '>= 0.60.0',
  default_options: [
    'warning_level=2',
    'werror=false',
  ],
)

gnome = import('gnome')

# Dependencies
cc = meson.get_compiler('c')
m_dep = cc.find_library('m', required: false)
glib_dep = dependency('glib-2.0', version: '>= 2.76')
gobject_dep = dependency('gobject-2.0')
gio_dep = dependency('gio-2.0')
gio_unix_dep = dependency('gio-unix-2.0')
gtk_dep = dependency('gtk4', version: '>= 4.12')
adw_dep = dependency('libadwaita-1', version: '>= 1.5')
granite_dep = dependency('granite-7', version: '>= 7.0')
json_glib_dep = dependency('json-glib-1.0')
sqlite_dep = dependency('sqlite3')
posix_dep = meson.get_compiler('vala').find_library('posix')

# Wayland dependencies
wayland_client_dep = dependency('wayland-client', required: false)
gtk4_wayland_dep = dependency('gtk4-wayland', required: false)
poisk_extra_sources = []
poisk_extra_deps = []

if wayland_client_dep.found() and gtk4_wayland_dep.found()
  add_project_arguments([
    '--vapidir=' + meson.current_source_dir() + '/protocol',
    '--pkg=pantheon-desktop-shell',
    '--pkg=gtk4-wayland',
    '-D', 'HAVE_PANTHEON_SHELL',
  ], language: 'vala')
  poisk_extra_sources += files('protocol/pantheon-desktop-shell-protocol.c')
  poisk_extra_deps += [wayland_client_dep, gtk4_wayland_dep]
endif

sources = files(
  'src/main.vala',
  'src/core/item.vala',
  'src/core/provider.vala',
  'src/core/search_engine.vala',
  'src/core/database.vala',
  'src/core/app_group_manager.vala',
  'src/bridges/desktop_bridge.vala',
  'src/bridges/gnome_bridge.vala',
  'src/bridges/pantheon_bridge.vala',
  'src/bridges/cinnamon_bridge.vala',
  'src/providers/app_provider.vala',
  'src/providers/window_provider.vala',
  'src/providers/calc_provider.vala',
  'src/ui/satellite_button.vala',
  'src/ui/system_bubble.vala',
  'src/ui/frosted_box.vala',
  'src/ui/fading_box.vala',
  'src/ui/pill_header.vala',
  'src/ui/glance_pill.vala',
  'src/ui/result_row.vala',
  'src/ui/preview_pane.vala',
  'src/ui/app_grid.vala',
  'src/ui/settings_view.vala',
  'src/ui/group_manager_dialog.vala',
  'src/ui/preferences_window.vala',
  'src/ui/pantheon_blur.vala',
  'src/ui/window.vala',
)

executable('poisk',
  sources + poisk_extra_sources,
  include_directories: [
    include_directories('.'),
    include_directories('protocol'),
  ],
  dependencies: [
    glib_dep,
    gobject_dep,
    gio_dep,
    gio_unix_dep,
    gtk_dep,
    adw_dep,
    granite_dep,
    json_glib_dep,
    sqlite_dep,
    posix_dep,
    m_dep,
  ] + poisk_extra_deps,
  install: true,
)


switchboard_dep = dependency('switchboard-3', required: false)
gee_dep = dependency('gee-0.8', required: false)

if switchboard_dep.found() and gee_dep.found()
  switchboard_plugsdir = get_option('libdir') / 'switchboard-3'

  shared_module('poisk',
    files(
      'src/switchboard/plug.vala',
      'src/ui/settings_view.vala',
    ),
    dependencies: [
      glib_dep,
      gobject_dep,
      gio_dep,
      gtk_dep,
      adw_dep,
      granite_dep,
      gee_dep,
      switchboard_dep,
    ],
    install: true,
    install_dir: switchboard_plugsdir / 'personal',
  )
endif

install_data(
  'data/io.github.mrlogiousbanana.poisk.desktop',
  'data/io.github.mrlogiousbanana.poisk.preferences.desktop',
  install_dir: get_option('datadir') / 'applications',
)

install_data(
  'data/io.github.mrlogiousbanana.poisk.gschema.xml',
  install_dir: get_option('datadir') / 'glib-2.0' / 'schemas',
)

systemd_dep = dependency('systemd', required: false)
if systemd_dep.found()
  systemd_user_unit_dir = systemd_dep.get_variable('systemduserunitdir', default_value: get_option('prefix') / 'lib' / 'systemd' / 'user')
else
  systemd_user_unit_dir = get_option('prefix') / 'lib' / 'systemd' / 'user'
endif

install_data(
  'data/systemd/poisk.service',
  install_dir: systemd_user_unit_dir,
)

install_data(
  'data/gnome-shell-extension/metadata.json',
  'data/gnome-shell-extension/extension.js',
  'data/gnome-shell-extension/prefs.js',
  install_dir: get_option('datadir') / 'gnome-shell' / 'extensions' / 'poisk-blur@mrlogiousbanana.github.io',
)

gnome.post_install(
  glib_compile_schemas: true,
)
