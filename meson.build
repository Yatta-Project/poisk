project('poisk', ['c', 'vala'],
  version: '1.0.0',
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

x11_dep = dependency('x11')
gtk4_x11_dep = dependency('gtk4-x11')

# Vala flags
add_project_arguments([
  '--vapidir=' + meson.current_source_dir() + '/vapi',
  '--pkg=x11_utils',
], language: 'vala')

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
  'src/providers/calc_provider.vala',
  'src/ui/satellite_button.vala',
  'src/ui/system_bubble.vala',
  'src/ui/frosted_box.vala',
  'src/ui/pill_header.vala',
  'src/ui/result_row.vala',
  'src/ui/preview_pane.vala',
  'src/ui/app_grid.vala',
  'src/ui/settings_view.vala',
  'src/ui/preferences_window.vala',
  'src/ui/window.vala',
  'src/ui/x11_utils.c',
)

executable('poisk',
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
    x11_dep,
    gtk4_x11_dep,
    m_dep,
  ],
  install: true,
)

executable('poisk-superd',
  files('src/daemon/superd.c'),
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
  'data/systemd/poisk-superd.service',
  install_dir: systemd_user_unit_dir,
)

gnome.post_install(
  glib_compile_schemas: true,
)
