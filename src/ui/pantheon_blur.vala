namespace Poisk.UI {

    public class MultiBlurManager : GLib.Object {
#if HAVE_PANTHEON_SHELL
        private Pantheon.Desktop.Shell? desktop_shell = null;
        private Pantheon.Desktop.Panel? panel = null;
        private static Wl.RegistryListener registry_listener;
        private unowned Gtk.Window window;
        private DBusConnection? session_bus = null;

        public MultiBlurManager (Gtk.Window window) {
            this.window = window;
            init_shell ();
            init_dbus.begin ();
        }

        private async void init_dbus () {
            try {
                session_bus = yield Bus.get (BusType.SESSION);
            } catch (Error e) {
                debug ("Poisk: failed to connect to session bus: %s", e.message);
            }
        }

        private void registry_handle_global (Wl.Registry wl_registry, uint32 name, string @interface, uint32 version) {
            if (@interface == "io_elementary_pantheon_shell_v1") {
                desktop_shell = wl_registry.bind<Pantheon.Desktop.Shell> (name, ref Pantheon.Desktop.Shell.iface, uint32.min (version, 1));
            }
        }

        private void init_shell () {
            unowned var display = Gdk.Display.get_default ();
            if (display is Gdk.Wayland.Display) {
                registry_listener.global = registry_handle_global;
                unowned var wl_display = ((Gdk.Wayland.Display) display).get_wl_display ();
                var wl_registry = wl_display.get_registry ();
                wl_registry.add_listener (registry_listener, this);
                wl_display.roundtrip ();
            }
        }

        public void attach_blur (uint left, uint right, uint top, uint bottom, uint border_radius,
                                 bool is_island = false,
                                 int bubble_x = 0, int bubble_y = 0, int bubble_w = 0, int bubble_h = 0,
                                 int cap_x = 0, int cap_y = 0, int cap_w = 0, int cap_h = 0,
                                 double opacity = 0.84) {
            unowned var display = Gdk.Display.get_default ();
            if (display is Gdk.Wayland.Display) {
                // 1. Gala backend (Pantheon desktop shell)
                if (panel == null && desktop_shell != null) {
                    unowned var surface = window.get_surface ();
                    if (surface is Gdk.Wayland.Surface) {
                        unowned var wl_surface = ((Gdk.Wayland.Surface) surface).get_wl_surface ();
                        panel = desktop_shell.get_panel (wl_surface);
                    }
                }
                if (panel != null) {
                    if (is_island) {
                        panel.remove_blur ();
                    } else {
                        panel.add_blur (left, right, top, bottom, border_radius);
                    }
                }

                // 2. GNOME Shell Extension backend (PoiskBlur / Blur-my-shell style)
                notify_gnome_extension.begin (is_island, (int) border_radius, opacity,
                                              bubble_x, bubble_y, bubble_w, bubble_h,
                                              cap_x, cap_y, cap_w, cap_h);
            }
        }

        public void remove_blur () {
            unowned var display = Gdk.Display.get_default ();
            if (display is Gdk.Wayland.Display) {
                if (panel != null) {
                    panel.remove_blur ();
                }
                notify_gnome_extension_remove.begin ();
            }
        }

        public void request_focus () {
            if (panel != null) {
                panel.focus ();
            }
        }

        private async void notify_gnome_extension (bool is_island, int radius, double opacity,
                                                   int bx, int by, int bw, int bh,
                                                   int cx, int cy, int cw, int ch) {
            if (session_bus == null) return;
            try {
                var config_builder = new VariantBuilder (new VariantType ("(bid)"));
                config_builder.add ("b", is_island);
                config_builder.add ("i", radius);
                config_builder.add ("d", opacity);

                yield session_bus.call (
                    "org.gnome.Shell",
                    "/org/gnome/Shell/Extensions/PoiskBlur",
                    "org.gnome.Shell.Extensions.PoiskBlur",
                    "SetBlurConfig",
                    config_builder.end (),
                    null,
                    DBusCallFlags.NONE,
                    150
                );

                if (is_island) {
                    var geom_builder = new VariantBuilder (new VariantType ("(iiiiiiii)"));
                    geom_builder.add ("i", bx);
                    geom_builder.add ("i", by);
                    geom_builder.add ("i", bw);
                    geom_builder.add ("i", bh);
                    geom_builder.add ("i", cx);
                    geom_builder.add ("i", cy);
                    geom_builder.add ("i", cw);
                    geom_builder.add ("i", ch);

                    yield session_bus.call (
                        "org.gnome.Shell",
                        "/org/gnome/Shell/Extensions/PoiskBlur",
                        "org.gnome.Shell.Extensions.PoiskBlur",
                        "SetPillGeometry",
                        geom_builder.end (),
                        null,
                        DBusCallFlags.NONE,
                        150
                    );
                }
            } catch (Error e) {
                // Extension might not be running on Pantheon, which is expected
            }
        }

        private async void notify_gnome_extension_remove () {
            if (session_bus == null) return;
            try {
                yield session_bus.call (
                    "org.gnome.Shell",
                    "/org/gnome/Shell/Extensions/PoiskBlur",
                    "org.gnome.Shell.Extensions.PoiskBlur",
                    "RemoveBlur",
                    null,
                    null,
                    DBusCallFlags.NONE,
                    150
                );
            } catch (Error e) {
            }
        }
#else
        public MultiBlurManager (Gtk.Window window) {}
        public void attach_blur (uint left, uint right, uint top, uint bottom, uint border_radius,
                                 bool is_island = false,
                                 int bubble_x = 0, int bubble_y = 0, int bubble_w = 0, int bubble_h = 0,
                                 int cap_x = 0, int cap_y = 0, int cap_w = 0, int cap_h = 0,
                                 double opacity = 0.84) {}
        public void remove_blur () {}
        public void request_focus () {}
#endif
    }
}
