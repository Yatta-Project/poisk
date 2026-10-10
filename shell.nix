{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = with pkgs; [
    meson
    ninja
    vala
    pkg-config
    gtk4
    libadwaita
    pantheon.granite7
    json-glib
    sqlite
    libx11
  ];

  shellHook = ''
    echo "Poisk development shell ready."
    echo "To build: meson setup build && ninja -C build"
  '';
}
