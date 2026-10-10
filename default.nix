{ pkgs ? import <nixpkgs> {} }:

pkgs.stdenv.mkDerivation rec {
  pname = "poisk";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = with pkgs; [
    meson
    ninja
    vala
    pkg-config
    wrapGAppsHook4
  ];

  buildInputs = with pkgs; [
    gtk4
    libadwaita
    pantheon.granite7
    json-glib
    sqlite
    libx11
  ];

  meta = with pkgs.lib; {
    description = "Fast native launcher and productivity palette for Pantheon and Linux";
    homepage = "https://github.com/mrlogiousbanana/poisk";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
  };
}
