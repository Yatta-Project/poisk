#include "x11_utils.h"

#ifdef GDK_WINDOWING_X11
#include <gdk/x11/gdkx.h>
#include <X11/Xatom.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>

void vicinae_window_set_skip_taskbar(GtkWindow *window) {
    if (!window) return;
    
    GdkSurface *surface = gtk_native_get_surface(GTK_NATIVE(window));
    if (!surface || !GDK_IS_X11_SURFACE(surface)) return;

    Window xid = gdk_x11_surface_get_xid(surface);
    Display *xdisplay = gdk_x11_display_get_xdisplay(gdk_surface_get_display(surface));
    Window root = DefaultRootWindow(xdisplay);

    Atom state_atom = XInternAtom(xdisplay, "_NET_WM_STATE", False);
    Atom skip_taskbar = XInternAtom(xdisplay, "_NET_WM_STATE_SKIP_TASKBAR", False);
    Atom skip_pager = XInternAtom(xdisplay, "_NET_WM_STATE_SKIP_PAGER", False);

    XClientMessageEvent ev = {0};
    ev.type = ClientMessage;
    ev.window = xid;
    ev.message_type = state_atom;
    ev.format = 32;
    ev.data.l[0] = 1; // _NET_WM_STATE_ADD
    ev.data.l[1] = skip_taskbar;
    ev.data.l[2] = skip_pager;
    ev.data.l[3] = 1; // normal source indication

    Atom opaque_region = XInternAtom(xdisplay, "_NET_WM_OPAQUE_REGION", False);
    XDeleteProperty(xdisplay, xid, opaque_region);

    XSendEvent(xdisplay, root, False, SubstructureRedirectMask | SubstructureNotifyMask, (XEvent *)&ev);
    XFlush(xdisplay);
}

void vicinae_window_resize_and_center(GtkWindow *window, int width, int height) {
    if (!window) return;
    gtk_window_set_default_size(window, width, height);
    
    GdkSurface *surface = gtk_native_get_surface(GTK_NATIVE(window));
    if (!surface || !GDK_IS_X11_SURFACE(surface)) return;

    Window xid = gdk_x11_surface_get_xid(surface);
    Display *xdisplay = gdk_x11_display_get_xdisplay(gdk_surface_get_display(surface));

    Atom opaque_region = XInternAtom(xdisplay, "_NET_WM_OPAQUE_REGION", False);
    XDeleteProperty(xdisplay, xid, opaque_region);

    int scale = gdk_surface_get_scale_factor(surface);
    if (scale <= 0) scale = 1;

    int screen = DefaultScreen(xdisplay);
    int screen_w = DisplayWidth(xdisplay, screen);
    int screen_h = DisplayHeight(xdisplay, screen);

    int phys_w = width * scale;
    int phys_h = height * scale;

    int x = (screen_w - phys_w) / 2;
    int y = (screen_h - 284 * scale) / 3 - 28 * scale;
    if (y < 40 * scale) y = 40 * scale;

    XSizeHints hints = {0};
    hints.flags = USPosition | PPosition | PMinSize;
    hints.x = x;
    hints.y = y;
    hints.min_width = 200 * scale;
    hints.min_height = 40 * scale;
    XSetWMNormalHints(xdisplay, xid, &hints);

    XMoveResizeWindow(xdisplay, xid, x, y, (unsigned int)phys_w, (unsigned int)phys_h);
    XFlush(xdisplay);
}

void vicinae_window_position_layout(GtkWindow *bubble_win, GtkWindow *main_win, int main_width, int main_height) {
    if (bubble_win) gtk_window_set_default_size(bubble_win, 56, 56);
    if (main_win) gtk_window_set_default_size(main_win, main_width, main_height);

    GdkSurface *main_surface = main_win ? gtk_native_get_surface(GTK_NATIVE(main_win)) : NULL;
    GdkSurface *bubble_surface = bubble_win ? gtk_native_get_surface(GTK_NATIVE(bubble_win)) : NULL;

    GdkSurface *ref_surface = main_surface ? main_surface : bubble_surface;
    if (!ref_surface || !GDK_IS_X11_SURFACE(ref_surface)) return;

    Display *xdisplay = gdk_x11_display_get_xdisplay(gdk_surface_get_display(ref_surface));
    int scale = gdk_surface_get_scale_factor(ref_surface);
    if (scale <= 0) scale = 1;

    int screen = DefaultScreen(xdisplay);
    int screen_w = DisplayWidth(xdisplay, screen);
    int screen_h = DisplayHeight(xdisplay, screen);

    int gap = 12;
    int total_w = (56 + gap + main_width) * scale;
    int start_x = (screen_w - total_w) / 2;
    int start_y = (screen_h - 284 * scale) / 3 - 28 * scale;
    if (start_y < 40 * scale) start_y = 40 * scale;

    int bubble_x = start_x;
    int main_x = start_x + (56 + gap) * scale;
    int main_phys_w = main_width * scale;
    int main_phys_h = main_height * scale;

    Window main_xid = None;
    if (main_surface && GDK_IS_X11_SURFACE(main_surface)) {
        main_xid = gdk_x11_surface_get_xid(main_surface);
        Atom opaque_region = XInternAtom(xdisplay, "_NET_WM_OPAQUE_REGION", False);
        XDeleteProperty(xdisplay, main_xid, opaque_region);

        XSizeHints m_hints = {0};
        m_hints.flags = USPosition | PPosition | PMinSize;
        m_hints.x = main_x;
        m_hints.y = start_y;
        m_hints.min_width = 200 * scale;
        m_hints.min_height = 40 * scale;
        XSetWMNormalHints(xdisplay, main_xid, &m_hints);

        XMoveResizeWindow(xdisplay, main_xid, main_x, start_y, (unsigned int)main_phys_w, (unsigned int)main_phys_h);
    }

    if (bubble_surface && GDK_IS_X11_SURFACE(bubble_surface)) {
        Window bubble_xid = gdk_x11_surface_get_xid(bubble_surface);
        Atom opaque_region = XInternAtom(xdisplay, "_NET_WM_OPAQUE_REGION", False);
        XDeleteProperty(xdisplay, bubble_xid, opaque_region);

        XSizeHints b_hints = {0};
        b_hints.flags = USPosition | PPosition | PMinSize | PMaxSize;
        b_hints.x = bubble_x;
        b_hints.y = start_y;
        b_hints.min_width = 56 * scale;
        b_hints.min_height = 56 * scale;
        b_hints.max_width = 56 * scale;
        b_hints.max_height = 56 * scale;
        XSetWMNormalHints(xdisplay, bubble_xid, &b_hints);

        if (main_xid != None) {
            XSetTransientForHint(xdisplay, bubble_xid, main_xid);
        }

        XMoveResizeWindow(xdisplay, bubble_xid, bubble_x, start_y, (unsigned int)(56 * scale), (unsigned int)(56 * scale));
    }

    XFlush(xdisplay);
}
#else
void vicinae_window_set_skip_taskbar(GtkWindow *window) {
    (void)window;
}
void vicinae_window_resize_and_center(GtkWindow *window, int width, int height) {
    if (window) {
        gtk_window_set_default_size(window, width, height);
    }
}
void vicinae_window_position_layout(GtkWindow *bubble_win, GtkWindow *main_win, int main_width, int main_height) {
    if (bubble_win) gtk_window_set_default_size(bubble_win, 56, 56);
    if (main_win) gtk_window_set_default_size(main_win, main_width, main_height);
}
#endif
