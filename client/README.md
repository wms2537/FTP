# FTP Client

A cross-platform FTP client built with Flutter. Note that FTP functionalities is limited to non-web platforms, since raw TCP socket is not supported in web.

## Features

- Cross-platform support (Windows, macOS, Linux, iOS, Android)
- User-friendly interface for FTP operations
- File upload and download capabilities
- Drag and drop support for file transfers

## Details
Source code is in `src/lib`.

## Getting Started

### Prerequisites

- Flutter SDK (version ^3.6.0-216.1.beta)
- Dart SDK (version ^3.6.0-216.1.beta)

### Installation

1. Clone the repository:
   ```
   git clone https://github.com/your-username/ftp-client.git
   ```

2. Navigate to the project directory:
   ```
   cd ftp-client
   ```

3. Install dependencies:
   ```
   flutter pub get
   ```

### Running the Application

To run the application in debug mode:
```
flutter run
```

To run the application in release mode:
```
flutter run --release
```

### Use pre-built executable

We prepared pre-built executable forlinux/amd64 and linux/arm64 in the `linux_amd64` and `linux_arm64` folder.

