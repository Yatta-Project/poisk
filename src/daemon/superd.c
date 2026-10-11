#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <dirent.h>
#include <poll.h>
#include <signal.h>
#include <time.h>
#include <sys/time.h>
#include <linux/input.h>

#define MAX_DEVICES 64
#define TAP_TIMEOUT_MS 600

static volatile int running = 1;

static void handle_signal(int sig) {
    (void)sig;
    running = 0;
}

static uint64_t get_time_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000 + (uint64_t)ts.tv_nsec / 1000000;
}

static int is_keyboard_device(int fd) {
    unsigned long evbits[(EV_MAX + sizeof(long) * 8 - 1) / (sizeof(long) * 8)] = {0};
    if (ioctl(fd, EVIOCGBIT(0, sizeof(evbits)), evbits) < 0) return 0;
    if (!(evbits[EV_KEY / (sizeof(long) * 8)] & (1UL << (EV_KEY % (sizeof(long) * 8))))) return 0;

    unsigned long keybits[(KEY_MAX + sizeof(long) * 8 - 1) / (sizeof(long) * 8)] = {0};
    if (ioctl(fd, EVIOCGBIT(EV_KEY, sizeof(keybits)), keybits) < 0) return 0;

    int has_meta = (keybits[KEY_LEFTMETA / (sizeof(long) * 8)] & (1UL << (KEY_LEFTMETA % (sizeof(long) * 8)))) != 0;
    int has_a = (keybits[KEY_A / (sizeof(long) * 8)] & (1UL << (KEY_A % (sizeof(long) * 8)))) != 0;
    return has_meta || has_a;
}

typedef struct {
    int fd;
    char path[64];
} Device;

static Device devices[MAX_DEVICES];
static int num_devices = 0;

static void close_all_devices(void) {
    for (int i = 0; i < num_devices; i++) {
        if (devices[i].fd >= 0) {
            close(devices[i].fd);
            devices[i].fd = -1;
        }
    }
    num_devices = 0;
}

static void rescan_devices(void) {
    DIR *dir = opendir("/dev/input");
    if (!dir) return;

    // Mark active devices
    int kept[MAX_DEVICES] = {0};

    struct dirent *entry;
    while ((entry = readdir(dir)) != NULL) {
        if (strncmp(entry->d_name, "event", 5) != 0) continue;

        char path[64];
        snprintf(path, sizeof(path), "/dev/input/%s", entry->d_name);

        int exists = 0;
        for (int i = 0; i < num_devices; i++) {
            if (strcmp(devices[i].path, path) == 0) {
                exists = 1;
                kept[i] = 1;
                break;
            }
        }

        if (!exists && num_devices < MAX_DEVICES) {
            int fd = open(path, O_RDONLY | O_NONBLOCK);
            if (fd >= 0) {
                if (is_keyboard_device(fd)) {
                    devices[num_devices].fd = fd;
                    strncpy(devices[num_devices].path, path, sizeof(devices[num_devices].path) - 1);
                    kept[num_devices] = 1;
                    num_devices++;
                } else {
                    close(fd);
                }
            }
        }
    }
    closedir(dir);

    // Clean up dropped devices
    for (int i = 0; i < num_devices; i++) {
        if (!kept[i]) {
            if (devices[i].fd >= 0) close(devices[i].fd);
            devices[i] = devices[num_devices - 1];
            kept[i] = kept[num_devices - 1];
            num_devices--;
            i--;
        }
    }
}

static void trigger_poisk_toggle(void) {
    // Spawn toggle in background asynchronously
    pid_t pid = fork();
    if (pid == 0) {
        char poisk_path[512];
        const char *home = getenv("HOME");
        if (home) {
            snprintf(poisk_path, sizeof(poisk_path), "%s/.local/bin/poisk", home);
            execlp("systemd-run", "systemd-run", "--user", "-q", poisk_path, "--toggle", NULL);
            execl(poisk_path, "poisk", "--toggle", NULL);
        }
        execlp("systemd-run", "systemd-run", "--user", "-q", "poisk", "--toggle", NULL);
        execlp("poisk", "poisk", "--toggle", NULL);
        _exit(1);
    }
}

static int is_pantheon_active(void) {
    const char *desktop = getenv("XDG_CURRENT_DESKTOP");
    if (desktop && (strstr(desktop, "Pantheon") || strstr(desktop, "pantheon"))) {
        return 1;
    }
    const char *session = getenv("DESKTOP_SESSION");
    if (session && (strstr(session, "Pantheon") || strstr(session, "pantheon"))) {
        return 1;
    }
    // Also check if Gala is running
    if (system("pgrep -x gala > /dev/null 2>&1") == 0) {
        return 1;
    }
    return 0;
}

int main(void) {
    signal(SIGINT, handle_signal);
    signal(SIGTERM, handle_signal);
    signal(SIGCHLD, SIG_IGN);

    if (is_pantheon_active()) {
        // Gala handles Super key natively via io.elementary.desktop.wm.behavior overlay-action
        // and org.gnome.mutter overlay-key.
        // Sleep to avoid duplicate triggers while keeping service healthy.
        while (running) {
            sleep(60);
        }
        return 0;
    }

    rescan_devices();

    struct pollfd pfd[MAX_DEVICES];
    int meta_down = 0;
    int combo_cancelled = 0;
    uint64_t press_ms = 0;
    uint64_t last_scan_ms = get_time_ms();

    while (running) {
        uint64_t now_ms = get_time_ms();
        if (now_ms - last_scan_ms >= 3000) {
            rescan_devices();
            last_scan_ms = now_ms;
        }

        for (int i = 0; i < num_devices; i++) {
            pfd[i].fd = devices[i].fd;
            pfd[i].events = POLLIN;
            pfd[i].revents = 0;
        }

        int ret = poll(pfd, num_devices, 1000);
        if (ret < 0) {
            if (!running) break;
            continue;
        }

        for (int i = 0; i < num_devices; i++) {
            if (pfd[i].revents & (POLLERR | POLLHUP | POLLNVAL)) {
                close(devices[i].fd);
                devices[i].fd = -1;
                // Will be refreshed on next scan
                continue;
            }

            if (pfd[i].revents & POLLIN) {
                struct input_event ev;
                while (read(devices[i].fd, &ev, sizeof(ev)) == sizeof(ev)) {
                    if (ev.type == EV_KEY) {
                        if (ev.code == KEY_LEFTMETA || ev.code == KEY_RIGHTMETA) {
                            if (ev.value == 1) { // Press
                                meta_down = 1;
                                combo_cancelled = 0;
                                press_ms = get_time_ms();
                            } else if (ev.value == 0) { // Release
                                if (meta_down && !combo_cancelled) {
                                    uint64_t elapsed = get_time_ms() - press_ms;
                                    if (elapsed < TAP_TIMEOUT_MS) {
                                        trigger_poisk_toggle();
                                    }
                                }
                                meta_down = 0;
                                combo_cancelled = 0;
                            }
                        } else {
                            // Another key was pressed or held while Meta was down
                            if (meta_down && (ev.value == 1 || ev.value == 2)) {
                                combo_cancelled = 1;
                            }
                        }
                    }
                }
            }
        }
    }

    close_all_devices();
    return 0;
}
