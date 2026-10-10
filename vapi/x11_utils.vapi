[CCode (cheader_filename = "src/ui/x11_utils.h")]
namespace Poisk.UI {
    [CCode (cname = "vicinae_window_set_skip_taskbar")]
    public void set_skip_taskbar (Gtk.Window window);

    [CCode (cname = "vicinae_window_resize_and_center")]
    public void resize_and_center_window (Gtk.Window window, int width, int height);

    [CCode (cname = "vicinae_window_position_layout")]
    public void position_layout_windows (Gtk.Window? bubble_win, Gtk.Window main_win, int main_width, int main_height);
}
