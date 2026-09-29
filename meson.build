project('vicinae-vala', ['c', 'vala'],
  version: '0.1.0',
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

# Vala flags
add_project_arguments(['--vapidir=' + meson.current_source_dir() + '/vapi'], language: 'vala')

sources = files(
  'src/main.vala',
  'src/core/item.vala',
  'src/core/provider.vala',
  'src/core/search_engine.vala',
  'src/core/database.vala',
  'src/bridges/desktop_bridge.vala',
  'src/bridges/gnome_bridge.vala',
  'src/bridges/pantheon_bridge.vala',
  'src/providers/app_provider.vala',
  'src/providers/window_provider.vala',
  'src/providers/clipboard_provider.vala',
  'src/providers/calc_provider.vala',
  'src/providers/script_provider.vala',
  'src/providers/dmenu_provider.vala',
  'src/ui/result_row.vala',
  'src/ui/preview_pane.vala',
  'src/ui/app_grid.vala',
  'src/ui/window.vala',
)

executable('vicinae',
  sources,
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
  ],
  install: true,
)

install_data(
  'data/org.vicinae.launcher.desktop',
  install_dir: get_option('datadir') / 'applications',
)
