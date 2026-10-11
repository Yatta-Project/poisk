{ pkgs ? import <nixpkgs> {} }:

let
  customDesktopPlug = import ./desktop-plug.nix { inherit pkgs; };
  filteredPlugs = map (p: if p.pname == "switchboard-plug-pantheon-shell" then customDesktopPlug else p) pkgs.pantheon.switchboardPlugs;
in
pkgs.pantheon.switchboard-with-plugs.override {
  useDefaultPlugs = false;
  plugs = filteredPlugs;
}
