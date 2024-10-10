#ifndef FTP_SERVER_H
#define FTP_SERVER_H

#define PORT 21
#define BUFFER_SIZE 4096
#define MAX_CLIENTS 10
#define DEFAULT_ROOT_DIR "data"

void make_absolute_path(char *path, char *absolute_path);

void handle_client(int client_socket);
void send_response(int client_socket, const char *response);
void handle_user(int client_socket, char *args);
void handle_pass(int client_socket, char *args);
void handle_quit(int client_socket);
void handle_retr(int client_socket, char *filename);
void handle_stor(int client_socket, char *filename);
void handle_port(int client_socket, char *args);
void handle_pasv(int client_socket);
void handle_type(int client_socket, char *args);
void handle_list(int client_socket, char *args);
void handle_mkd(int client_socket, char *dirname);
void handle_cwd(int client_socket, char *dirname);
void handle_pwd(int client_socket);
void handle_rmd(int client_socket, char *dirname);
void handle_syst(int client_socket);
void handle_abor(int client_socket);
void handle_epsv(int client_socket);
void handle_dele(int client_socket, char *filename);
void handle_size(int client_socket, char *filename);

char* get_absolute_path(const char* relative_path);

#endif // FTP_SERVER_H