# Simple FTP Server

This is a basic FTP server implementation in C. It supports anonymous login and provides essential FTP commands for file and directory operations.

## Features

- Anonymous login
- File upload and download
- Directory listing
- Create and remove directories
- Change working directory
- Get file size
- Delete files
- Passive and active mode support

## Building the Server

1. Navigate to the `ComputerNetworks/FTP/server/src` directory.
2. Run the `make all` command to compile the server executable.

## Running the Server

Use the following command to start the server:

```
./server [-port <port_number>] [-root <root_directory>]
```

Options:
- `-port`: Specify the port number (default is 21)
- `-root`: Specify the root directory for the FTP server (default is "data")

Example:
```
./server -port 2121 -root /home/user/ftp_root
```

## Usage

Connect to the server using any FTP client. The server supports common FTP commands such as USER, PASS, LIST, RETR, STOR, CWD, PWD, MKD, RMD, DELE, and SIZE.

## Implementation Details

The server implementation can be found in the `ftp_server.c` file:
The following commands are implemented in @ftp_server.c:
- USER (Handle user login)
- PASS (Handle password authentication)
- QUIT (Handle client disconnection)
- RETR (Retrieve a file)
- STOR (Store a file)
- PORT (Set up active mode data connection)
- PASV (Enter passive mode)
- TYPE (Set transfer type)
- LIST (List directory contents)
- MKD (Create a directory)
- CWD (Change working directory)
- PWD (Print working directory)
- RMD (Remove a directory)
- SYST (Get system type)
- ABOR (Abort current operation)
- EPSV (Enter extended passive mode)
- DELE (Delete a file)
- SIZE (Get file size)


## Security Considerations

This FTP server implementation is basic and intended for educational purposes. It lacks several security features that would be necessary for a production environment.
