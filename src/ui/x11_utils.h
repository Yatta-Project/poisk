#pragma once

#include <gtk/gtk.h>

G_BEGIN_DECLS

void vicinae_window_set_skip_taskbar(GtkWindow *window);
void vicinae_window_resize_and_center(GtkWindow *window, int width, int height);
void vicinae_window_position_layout(GtkWindow *bubble_win, GtkWindow *main_win, int main_width, int main_height);
void vicinae_window_position_bubble(GtkWindow *bubble_win);
void vicinae_window_position_main(GtkWindow *main_win, int width, int height);

G_END_DECLS
