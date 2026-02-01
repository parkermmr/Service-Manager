#define _GNU_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <signal.h>
#include <time.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <errno.h>
#include <ctype.h>
#include <sys/prctl.h>

#define APP_NAME "APPLICATION"
#define CONFIG_PATH "/home/%s/application/config/CONFIG_FILE"
#define DEFAULT_PID_FILE "/home/%s/application/run/application.pid"
#define DEFAULT_DATA_FILE "/home/%s/application/run/application.data"

static int run_interval = 5;
static char pid_file[512] = {0};
static char data_file[512] = {0};

static volatile sig_atomic_t running = 1;

void handle_signal(int sig) {
    (void)sig;
    running = 0;
}

int process_running(pid_t pid) {
    return (pid > 1 && kill(pid, 0) == 0);
}

pid_t read_pid(const char *path) {
    FILE *f = fopen(path, "r");
    if (!f)
        return -1;

    pid_t pid;
    if (fscanf(f, "%d", &pid) != 1) {
        fclose(f);
        return -1;
    }

    fclose(f);
    return pid;
}

void write_pid(const char *path) {
    FILE *f = fopen(path, "w");
    if (!f) {
        perror("fopen(pid_file)");
        exit(1);
    }
    fprintf(f, "%d\n", getpid());
    fclose(f);
}

void remove_pid(const char *path) {
    unlink(path);
}

int ensure_dir(const char *path) {
    if (!path || path[0] == '\0') return -1;

    struct stat st = {0};
    if (stat(path, &st) == -1) {
        if (mkdir(path, 0755) != 0) {
            perror("mkdir");
            return -1;
        }
    } else if (!S_ISDIR(st.st_mode)) {
        fprintf(stderr, "Path exists but is not a directory: %s\n", path);
        return -1;
    }
    return 0;
}

void expand_env(const char *in, char *out, size_t out_size) {
    size_t oi = 0;

    for (size_t i = 0; in[i] && oi + 1 < out_size; ) {
        if (in[i] == '$' && in[i + 1] == '{') {
            i += 2;
            char var[128];
            size_t vi = 0;

            while (in[i] && in[i] != '}' && vi + 1 < sizeof(var)) {
                var[vi++] = in[i++];
            }
            var[vi] = '\0';

            if (in[i] == '}')
                i++;

            const char *val = getenv(var);
            if (val) {
                while (*val && oi + 1 < out_size)
                    out[oi++] = *val++;
            }
        } else {
            out[oi++] = in[i++];
        }
    }

    out[oi] = '\0';
}

void load_config(const char *path) {
    FILE *f = fopen(path, "r");
    if (!f) {
        fprintf(stderr, "Config file not found: %s\n", path);
        return;
    }

    char line[1024];
    while (fgets(line, sizeof(line), f)) {
        char *p = line;

        while (isspace((unsigned char)*p))
            p++;

        if (*p == '#' || *p == '\0')
            continue;

        char key[256], raw_value[512], value[512];
        if (sscanf(p, "%255s %511s", key, raw_value) != 2)
            continue;

        expand_env(raw_value, value, sizeof(value));

        if (strcmp(key, "APPLICATION_RUN_INTERVAL") == 0) {
            run_interval = atoi(value);
        } else if (strcmp(key, "APPLICATION_PID_FILE") == 0) {
            snprintf(pid_file, sizeof(pid_file), "%s", value);
        } else if (strcmp(key, "APPLICATION_DATA_FILE") == 0) {
            snprintf(data_file, sizeof(data_file), "%s", value);
        }
    }

    fclose(f);

    printf("Loaded config:\n");
    printf("  Interval : %d\n", run_interval);
    printf("  PID file : %s\n", pid_file[0] ? pid_file : "(default)");
    printf("  Data file: %s\n", data_file[0] ? data_file : "(default)");
}

void daemon_loop(const char *data_path) {
    signal(SIGTERM, handle_signal);
    signal(SIGINT, handle_signal);

    while (running) {
        FILE *f = fopen(data_path, "w");
        if (f) {
            time_t now = time(NULL);
            fprintf(f, "Last update: %s", ctime(&now));
            fclose(f);
        }
        sleep(run_interval);
    }

    unlink(data_path);
}

void start_app(const char *pid_path, const char *data_path) {
    pid_t existing = read_pid(pid_path);
    if (existing > 0 && process_running(existing)) {
        fprintf(stderr, "%s already running (PID %d)\n", APP_NAME, existing);
        exit(1);
    }

    printf("Starting %s...\n", APP_NAME);

    pid_t pid = fork();
    if (pid < 0)
        exit(1);
    if (pid > 0)
        exit(0);

    if (setsid() < 0)
        exit(1);

    pid = fork();
    if (pid < 0)
        exit(1);
    if (pid > 0)
        exit(0);

    umask(0);
    if (chdir("/") != 0)
        perror("chdir");

    prctl(PR_SET_NAME, "applicationRun", 0, 0, 0);

    write_pid(pid_path);

    printf("%s started (PID %d)\n", APP_NAME, getpid());

    daemon_loop(data_path);

    remove_pid(pid_path);
    printf("%s stopped cleanly\n", APP_NAME);
    exit(0);
}

void stop_app(const char *pid_path) {
    pid_t pid = read_pid(pid_path);
    if (pid <= 0 || !process_running(pid)) {
        printf("%s is not running\n", APP_NAME);
        return;
    }

    kill(pid, SIGTERM);
    printf("%s stopped\n", APP_NAME);
}

void status_app(const char *pid_path) {
    pid_t pid = read_pid(pid_path);
    if (pid > 0 && process_running(pid))
        printf("%s is running (PID %d)\n", APP_NAME, pid);
    else
        printf("%s is not running\n", APP_NAME);
}

void help() {
    printf("Usage: application <command>\n\n");
    printf("Commands:\n");
    printf("  start    Start background process\n");
    printf("  stop     Stop background process\n");
    printf("  restart  Stop then start\n");
    printf("  status   Check if running\n");
    printf("  help     Show this message\n");
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        help();
        return 1;
    }

    const char *user = getenv("USER");
    if (!user) {
        fprintf(stderr, "USER environment variable not set\n");
        return 1;
    }

    char config_path[512];
    snprintf(config_path, sizeof(config_path), CONFIG_PATH, user);

    load_config(config_path);

    if (pid_file[0] == '\0')
        snprintf(pid_file, sizeof(pid_file), DEFAULT_PID_FILE, user);

    if (data_file[0] == '\0')
        snprintf(data_file, sizeof(data_file), DEFAULT_DATA_FILE, user);

    char pid_dir[512], data_dir[512], config_dir[512];
    strncpy(pid_dir, pid_file, sizeof(pid_dir));
    char *last = strrchr(pid_dir, '/');
    if (last) *last = '\0';

    strncpy(data_dir, data_file, sizeof(data_dir));
    last = strrchr(data_dir, '/');
    if (last) *last = '\0';

    snprintf(config_dir, sizeof(config_dir), "/home/%s/application/config", user);

    ensure_dir(pid_dir);
    ensure_dir(data_dir);
    ensure_dir(config_dir);
    
    if (strcmp(argv[1], "start") == 0)
        start_app(pid_file, data_file);
    else if (strcmp(argv[1], "stop") == 0)
        stop_app(pid_file);
    else if (strcmp(argv[1], "restart") == 0) {
        stop_app(pid_file);
        sleep(1);
        start_app(pid_file, data_file);
    }
    else if (strcmp(argv[1], "status") == 0)
        status_app(pid_file);
    else
        help();

    return 0;
}
