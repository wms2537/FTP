#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <dirent.h>
#include <limits.h> // For PATH_MAX
#include <libgen.h> // For dirname() function
#include <errno.h> // For errno
#include "ftp_server.h"

int data_socket = -1;
struct sockaddr_in data_addr;
char *root_dir = NULL;

typedef struct
{
    int client_socket;
    int logged_in;
} ClientSession;

char* get_absolute_path(const char* relative_path) {
    printf("DEBUG: get_absolute_path called with: %s\n", relative_path);
    
    char* abs_path = malloc(PATH_MAX);
    if (abs_path == NULL) {
        printf("DEBUG: Failed to allocate memory for abs_path\n");
        return NULL;
    }

    if (relative_path[0] == '/') {
        // It's already an absolute path
        snprintf(abs_path, PATH_MAX, "%s%s", root_dir, relative_path);
    } else {
        // It's a relative path
        char cwd[PATH_MAX];
        if (getcwd(cwd, sizeof(cwd)) == NULL) {
            printf("DEBUG: Failed to get current working directory\n");
            free(abs_path);
            return NULL;
        }
        snprintf(abs_path, PATH_MAX, "%s/%s", cwd, relative_path);
    }

    printf("DEBUG: Constructed path: %s\n", abs_path);

    // Check if the path is within the root directory
    char* real_root = realpath(root_dir, NULL);
    if (real_root == NULL) {
        printf("DEBUG: Failed to resolve root directory\n");
        free(abs_path);
        return NULL;
    }

    if (strncmp(abs_path, real_root, strlen(real_root)) != 0) {
        printf("DEBUG: Path is outside root directory\n");
        free(abs_path);
        free(real_root);
        return NULL;
    }

    free(real_root);
    return abs_path;
}

void handle_client(int client_socket)
{
    ClientSession session = {client_socket, 0}; // Initialize session with client_socket and logged_in = 0
    char buffer[BUFFER_SIZE];
    ssize_t bytes_read;

    send_response(session.client_socket, "220 Anonymous FTP server ready.\r\n");

    while ((bytes_read = recv(session.client_socket, buffer, BUFFER_SIZE, 0)) > 0)
    {
        buffer[bytes_read] = '\0';
        char *command = strtok(buffer, " \r\n");

        char *args = strtok(NULL, "\r\n");
        printf("Command Received: %s, socket: %d, args: %s\n", command, session.client_socket, args);

        if (strcasecmp(command, "USER") == 0)
        {
            handle_user(session.client_socket, args);
        }
        else if (strcasecmp(command, "PASS") == 0)
        {
            handle_pass(session.client_socket, args);
            session.logged_in = 1;
        }
        else if (session.logged_in)
        {
            if (strcasecmp(command, "QUIT") == 0)
            {
                handle_quit(session.client_socket);
                break;
            }
            else if (strcasecmp(command, "RETR") == 0)
            {
                handle_retr(session.client_socket, args);
            }
            else if (strcasecmp(command, "STOR") == 0)
            {
                handle_stor(session.client_socket, args);
            }
            else if (strcasecmp(command, "PORT") == 0)
            {
                handle_port(session.client_socket, args);
            }
            else if (strcasecmp(command, "PASV") == 0)
            {
                handle_pasv(session.client_socket);
            }
            else if (strcasecmp(command, "TYPE") == 0)
            {
                handle_type(session.client_socket, args);
            }
            else if (strcasecmp(command, "LIST") == 0)
            {
                handle_list(session.client_socket, args);
            }
            else if (strcasecmp(command, "MKD") == 0)
            {
                handle_mkd(session.client_socket, args);
            }
            else if (strcasecmp(command, "CWD") == 0)
            {
                handle_cwd(session.client_socket, args);
            }
            else if (strcasecmp(command, "PWD") == 0)
            {
                handle_pwd(session.client_socket);
            }
            else if (strcasecmp(command, "RMD") == 0)
            {
                handle_rmd(session.client_socket, args);
            }
            else if (strcasecmp(command, "SYST") == 0)
            {
                handle_syst(session.client_socket);
            }
            else if (strcasecmp(command, "ABOR") == 0)
            {
                handle_abor(session.client_socket);
            }
            else if (strcasecmp(command, "EPSV") == 0)
            {
                handle_epsv(session.client_socket);
            }
            else if (strcasecmp(command, "TYPE") == 0)
            {
                handle_type(session.client_socket, args);
            }
            else if (strcasecmp(command, "DELE") == 0)
            {
                handle_dele(session.client_socket, args);
            }
            else if (strcasecmp(command, "SIZE") == 0)
            {
                handle_size(session.client_socket, args);
            }
            else
            {
                send_response(session.client_socket, "502 Command not implemented\r\n");
            }
        }
        else
        {
            send_response(session.client_socket, "530 Not logged in\r\n");
        }
    }

    close(session.client_socket);
}

void send_response(int client_socket, const char *response)
{
    send(client_socket, response, strlen(response), 0);
}

void handle_user(int client_socket, char *args)
{
    if (strcasecmp(args, "anonymous") == 0)
    {
        send_response(client_socket, "331 Guest login ok, send your complete e-mail address as password.\r\n");
    }
    else
    {
        send_response(client_socket, "530 Only anonymous login is supported\r\n");
    }
}

void handle_pass(int client_socket, char *args)
{
    send_response(client_socket, "230 Guest login ok, access restrictions apply.\r\n");
}

void handle_quit(int client_socket)
{
    send_response(client_socket, "221 Goodbye.\r\n");
}

void handle_retr(int client_socket, char *filename)
{
    char* filepath = get_absolute_path(filename);
    if (filepath == NULL) {
        send_response(client_socket, "550 Invalid file path\r\n");
        return;
    }

    int file_fd = open(filepath, O_RDONLY);
    if (file_fd < 0)
    {
        send_response(client_socket, "550 File not found\r\n");
        free(filepath);
        return;
    }

    send_response(client_socket, "150 Opening binary mode data connection\r\n");

    char buffer[BUFFER_SIZE];
    ssize_t bytes_read;
    while ((bytes_read = read(file_fd, buffer, BUFFER_SIZE)) > 0)
    {
        send(data_socket, buffer, bytes_read, 0);
    }

    close(file_fd);
    close(data_socket);
    send_response(client_socket, "226 Transfer complete\r\n");
    free(filepath);
}

void handle_stor(int client_socket, char *filename)
{
    printf("DEBUG: Attempting to store file: %s\n", filename);
    
    char* filepath = get_absolute_path(filename);
    if (filepath == NULL) {
        printf("DEBUG: get_absolute_path returned NULL\n");
        send_response(client_socket, "550 Invalid file path\r\n");
        return;
    }
    
    printf("DEBUG: Absolute filepath: %s\n", filepath);

    // Create directories if they don't exist
    char *dir_path = strdup(filepath);
    char *dir_name = dirname(dir_path);
    
    printf("DEBUG: Directory path: %s\n", dir_name);

    char temp_path[PATH_MAX] = "";
    char *token = strtok(dir_name, "/");
    while (token != NULL) {
        strcat(temp_path, "/");
        strcat(temp_path, token);
        printf("DEBUG: Creating directory: %s\n", temp_path);
        if (mkdir(temp_path, 0777) != 0 && errno != EEXIST) {
            printf("DEBUG: Failed to create directory: %s (errno: %d)\n", temp_path, errno);
            send_response(client_socket, "550 Failed to create directory\r\n");
            free(dir_path);
            free(filepath);
            return;
        }
        token = strtok(NULL, "/");
    }
    free(dir_path);

    int file_fd = open(filepath, O_WRONLY | O_CREAT | O_TRUNC, 0666);
    if (file_fd < 0)
    {
        printf("DEBUG: Failed to open file: %s (errno: %d)\n", filepath, errno);
        send_response(client_socket, "550 Cannot create file\r\n");
        free(filepath);
        return;
    }

    send_response(client_socket, "150 Opening binary mode data connection\r\n");

    char buffer[BUFFER_SIZE];
    ssize_t bytes_read;
    while ((bytes_read = recv(data_socket, buffer, BUFFER_SIZE, 0)) > 0)
    {
        write(file_fd, buffer, bytes_read);
    }

    close(file_fd);
    close(data_socket);
    send_response(client_socket, "226 Transfer complete\r\n");
    free(filepath);
}

void handle_port(int client_socket, char *args)
{
    int h1, h2, h3, h4, p1, p2;
    sscanf(args, "%d,%d,%d,%d,%d,%d", &h1, &h2, &h3, &h4, &p1, &p2);
    int port = p1 * 256 + p2;
    char ip[16];
    snprintf(ip, sizeof(ip), "%d.%d.%d.%d", h1, h2, h3, h4);

    data_socket = socket(AF_INET, SOCK_STREAM, 0);
    if (data_socket < 0)
    {
        send_response(client_socket, "425 Can't open data connection\r\n");
        return;
    }

    memset(&data_addr, 0, sizeof(data_addr));
    data_addr.sin_family = AF_INET;
    data_addr.sin_port = htons(port);
    inet_pton(AF_INET, ip, &data_addr.sin_addr);

    if (connect(data_socket, (struct sockaddr *)&data_addr, sizeof(data_addr)) < 0)
    {
        send_response(client_socket, "425 Can't open data connection\r\n");
        close(data_socket);
        return;
    }

    send_response(client_socket, "200 PORT command successful\r\n");
}

void handle_pasv(int client_socket)
{
    int port = 20000 + rand() % 45536;
    int p1 = port / 256;
    int p2 = port % 256;

    // Assuming the server's IP address is 127.0.0.1
    char ip[16] = "127.0.0.1";
    int h1, h2, h3, h4;
    sscanf(ip, "%d.%d.%d.%d", &h1, &h2, &h3, &h4);

    char response[BUFFER_SIZE];
    snprintf(response, sizeof(response), "227 Entering Passive Mode (%d,%d,%d,%d,%d,%d)\r\n", h1, h2, h3, h4, p1, p2);
    send_response(client_socket, response);

    data_socket = socket(AF_INET, SOCK_STREAM, 0);
    if (data_socket < 0)
    {
        send_response(client_socket, "425 Can't open data connection\r\n");
        return;
    }

    memset(&data_addr, 0, sizeof(data_addr));
    data_addr.sin_family = AF_INET;
    data_addr.sin_addr.s_addr = INADDR_ANY;
    data_addr.sin_port = htons(port);

    if (bind(data_socket, (struct sockaddr *)&data_addr, sizeof(data_addr)) < 0)
    {
        send_response(client_socket, "425 Can't open data connection\r\n");
        close(data_socket);
        return;
    }

    if (listen(data_socket, 1) < 0)
    {
        send_response(client_socket, "425 Can't open data connection\r\n");
        close(data_socket);
        return;
    }

    struct sockaddr_in client_data_addr;
    socklen_t client_data_addr_len = sizeof(client_data_addr);
    data_socket = accept(data_socket, (struct sockaddr *)&client_data_addr, &client_data_addr_len);
    if (data_socket < 0)
    {
        send_response(client_socket, "425 Can't open data connection\r\n");
        close(data_socket);
        return;
    }
}

void handle_type(int client_socket, char *args)
{
    if (strcasecmp(args, "I") == 0)
    {
        send_response(client_socket, "200 Type set to I.\r\n");
    }
    else
    {
        send_response(client_socket, "504 Command not implemented for that parameter\r\n");
    }
}

void handle_list(int client_socket, char *args)
{
    send_response(client_socket, "150 Opening ASCII mode data connection for file list\r\n");

    FILE *ls = popen("ls -l", "r");
    char buffer[BUFFER_SIZE];
    
    // Skip the first line (total)
    if (fgets(buffer, sizeof(buffer), ls) != NULL) {
        // First line read and discarded
    }
    
    // Send the rest of the lines
    while (fgets(buffer, sizeof(buffer), ls) != NULL)
    {
        send(data_socket, buffer, strlen(buffer), 0);
    }
    pclose(ls);

    close(data_socket);
    send_response(client_socket, "226 Transfer complete\r\n");
}

void handle_mkd(int client_socket, char *dirname)
{
    if (mkdir(dirname, 0777) == 0)
    {
        send_response(client_socket, "257 Directory created\r\n");
    }
    else
    {
        send_response(client_socket, "550 Failed to create directory\r\n");
    }
}

void handle_cwd(int client_socket, char *dirname)
{
    char new_path[PATH_MAX];
    char real_root[PATH_MAX];
    char real_new_path[PATH_MAX];

    // Resolve the root directory path
    if (realpath(root_dir, real_root) == NULL)
    {
        send_response(client_socket, "550 Failed to resolve root directory\r\n");
        return;
    }

    // Construct the new path
    if (dirname[0] == '/')
    {
        // Absolute path
        snprintf(new_path, sizeof(new_path), "%s%s", root_dir, dirname);
    }
    else
    {
        // Relative path
        char current_dir[PATH_MAX];
        if (getcwd(current_dir, sizeof(current_dir)) == NULL)
        {
            send_response(client_socket, "550 Failed to get current directory\r\n");
            return;
        }
        snprintf(new_path, sizeof(new_path), "%s/%s", current_dir, dirname);
    }

    // Resolve the new path
    if (realpath(new_path, real_new_path) == NULL)
    {
        send_response(client_socket, "550 Failed to resolve path\r\n");
        return;
    }

    // Check if the new path is within the root directory
    if (strncmp(real_new_path, real_root, strlen(real_root)) != 0)
    {
        send_response(client_socket, "550 Access denied\r\n");
        return;
    }

    // Change to the new directory
    if (chdir(real_new_path) == 0)
    {
        send_response(client_socket, "250 Directory successfully changed\r\n");
    }
    else
    {
        send_response(client_socket, "550 Failed to change directory\r\n");
    }
}

void handle_pwd(int client_socket)
{
    char cwd[BUFFER_SIZE];
    if (getcwd(cwd, sizeof(cwd)) != NULL)
    {
        char relative_path[BUFFER_SIZE];
        if (strncmp(cwd, root_dir, strlen(root_dir)) == 0)
        {
            // The current working directory is within or equal to root_dir
            const char *rel = cwd + strlen(root_dir);
            snprintf(relative_path, sizeof(relative_path), "%s%s", 
                     (*rel == '\0' || *rel == '/') ? "/" : "/", 
                     (*rel == '/') ? rel + 1 : rel);
        }
        else
        {
            // The current working directory is outside root_dir
            strcpy(relative_path, cwd);
        }
        
        char response[BUFFER_SIZE];
        snprintf(response, sizeof(response), "257 \"%s\" is the current directory.\r\n", relative_path);
        send_response(client_socket, response);
    }
    else
    {
        send_response(client_socket, "550 Failed to get current directory\r\n");
    }
}

void handle_rmd(int client_socket, char *dirname)
{
    if (rmdir(dirname) == 0)
    {
        send_response(client_socket, "250 Directory successfully removed\r\n");
    }
    else
    {
        send_response(client_socket, "550 Failed to remove directory\r\n");
    }
}

void handle_syst(int client_socket)
{
    send_response(client_socket, "215 UNIX Type: L8\r\n");
}

void handle_abor(int client_socket)
{
    send_response(client_socket, "226 Abort successful\r\n");
}

void handle_epsv(int client_socket)
{
    int port = 20000 + rand() % 45536; // Random port selection

    // Respond with the EPSV format, which does not include the IP address
    char response[BUFFER_SIZE];
    snprintf(response, sizeof(response), "229 Entering Extended Passive Mode (|||%d|)\r\n", port);
    send_response(client_socket, response);

    data_socket = socket(AF_INET, SOCK_STREAM, 0);
    if (data_socket < 0)
    {
        send_response(client_socket, "425 Can't open data connection\r\n");
        return;
    }

    memset(&data_addr, 0, sizeof(data_addr));
    data_addr.sin_family = AF_INET;
    data_addr.sin_addr.s_addr = INADDR_ANY;
    data_addr.sin_port = htons(port);

    if (bind(data_socket, (struct sockaddr *)&data_addr, sizeof(data_addr)) < 0)
    {
        send_response(client_socket, "425 Can't open data connection\r\n");
        close(data_socket);
        return;
    }

    if (listen(data_socket, 1) < 0)
    {
        send_response(client_socket, "425 Can't open data connection\r\n");
        close(data_socket);
        return;
    }

    struct sockaddr_in client_data_addr;
    socklen_t client_data_addr_len = sizeof(client_data_addr);
    data_socket = accept(data_socket, (struct sockaddr *)&client_data_addr, &client_data_addr_len);
    if (data_socket < 0)
    {
        send_response(client_socket, "425 Can't open data connection\r\n");
        close(data_socket);
        return;
    }
}

void handle_dele(int client_socket, char *filename)
{
    if (strstr(filename, "../") != NULL)
    {
        send_response(client_socket, "550 Invalid file path\r\n");
        return;
    }
    char filepath[BUFFER_SIZE];
    snprintf(filepath, sizeof(filepath), "%s/%s", root_dir, filename);

    if (remove(filepath) == 0)
    {
        send_response(client_socket, "250 File deleted successfully\r\n");
    }
    else
    {
        send_response(client_socket, "550 Failed to delete file\r\n");
    }
}

void handle_size(int client_socket, char *filename)
{
    char* filepath = get_absolute_path(filename);
    if (filepath == NULL) {
        send_response(client_socket, "550 Invalid file path\r\n");
        return;
    }

    struct stat file_stat;
    if (stat(filepath, &file_stat) == 0) {
        char response[BUFFER_SIZE];
        snprintf(response, sizeof(response), "213 %lld\r\n", (long long)file_stat.st_size);
        send_response(client_socket, response);
    } else {
        send_response(client_socket, "550 Could not get file size\r\n");
    }

    free(filepath);
}

void make_absolute_path(char *path, char *absolute_path)
{
    
    if (realpath(path, absolute_path) != NULL)
    {
        return;
    }
    else
    {
        perror("realpath");
        exit(EXIT_FAILURE);
    }
}

int main(int argc, char *argv[])
{
    int server_socket, client_socket;
    struct sockaddr_in server_addr, client_addr;
    socklen_t client_addr_len = sizeof(client_addr);
    int port = PORT;

    // Parse command line arguments
    for (int i = 1; i < argc; i++)
    {
        if (strcmp(argv[i], "-port") == 0 && i + 1 < argc)
        {
            port = atoi(argv[++i]);
        }
        else if (strcmp(argv[i], "-root") == 0 && i + 1 < argc)
        {
            root_dir = argv[++i];
        }
    }

    if (root_dir == NULL)
    {
        root_dir = DEFAULT_ROOT_DIR;
    }
    printf("Root directory: %s\n", root_dir);
    char absolute_path[PATH_MAX];

    make_absolute_path(root_dir, absolute_path);
    root_dir = absolute_path;
    if (chdir(root_dir) != 0)
    {
        perror("chdir");
        exit(EXIT_FAILURE);
    }
    printf("Starting server...\n");
    server_socket = socket(AF_INET, SOCK_STREAM, 0);
    if (server_socket < 0)
    {
        perror("socket");
        exit(EXIT_FAILURE);
    }

    server_addr.sin_family = AF_INET;
    server_addr.sin_addr.s_addr = INADDR_ANY;
    server_addr.sin_port = htons(port);

    if (bind(server_socket, (struct sockaddr *)&server_addr, sizeof(server_addr)) < 0)
    {
        perror("bind");
        close(server_socket);
        exit(EXIT_FAILURE);
    }

    if (listen(server_socket, MAX_CLIENTS) < 0)
    {
        perror("listen");
        close(server_socket);
        exit(EXIT_FAILURE);
    }

    printf("FTP server listening on port %d\n", port);

    while ((client_socket = accept(server_socket, (struct sockaddr *)&client_addr, &client_addr_len)) >= 0)
    {
        if (fork() == 0)
        {
            close(server_socket);
            handle_client(client_socket);
            exit(EXIT_SUCCESS);
        }
        close(client_socket);
    }

    close(server_socket);
    return 0;
}