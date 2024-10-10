import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'ftp_commands.dart';

class FtpClient {
  final String _host;
  final int _port;
  Socket? _controlSocket;
  Stream<Uint8List>? _controlStream; // New variable for broadcast stream
  Socket? _dataSocket; // Add the data socket variable
  int _maxReconnectAttempts = 3;
  Duration _reconnectDelay = Duration(seconds: 5);

  FtpClient(this._host, [this._port = 21]);

  Future<void> connect() async {
    await _connectWithRetry();
  }

  Future<void> _connectWithRetry() async {
    for (int attempt = 1; attempt <= _maxReconnectAttempts; attempt++) {
      try {
        _controlSocket = await Socket.connect(_host, _port);
        _controlStream = _controlSocket!.asBroadcastStream();
        _controlStream!.listen(_handleResponse);
        await _readResponse();
        print('Connected successfully');
        return;
      } catch (e) {
        print('Connection attempt $attempt failed: $e');
        if (attempt == _maxReconnectAttempts) {
          throw Exception(
              'Failed to connect after $_maxReconnectAttempts attempts');
        }
        await Future.delayed(_reconnectDelay);
      }
    }
  }

  Future<String> _readResponse() async {
    String response = await utf8.decoder.bind(_controlStream!).first;
    int code = int.parse(response.substring(0, 3));
    if (code >= 400) {
      throw Exception('FTP Error: $response');
    }
    return response;
  }

  Future<String> _sendCommandWithReconnect(String command) async {
    try {
      return await _sendCommand(command);
    } on SocketException catch (e) {
      print('Socket error occurred: $e');
      await _connectWithRetry();
      return await _sendCommand(command);
    }
  }

  Future<void> login(String username, String password) async {
    await _sendCommandWithReconnect(FtpCommands.user(username));
    await _sendCommandWithReconnect(FtpCommands.pass(password));
  }

  Future<String> _sendCommand(String command) async {
    _controlSocket!.write(command + '\r\n');
    return await _readResponse();
  }

  void _handleResponse(Uint8List data) {
    print(String.fromCharCodes(data));
  }

  Future<void> disconnect() async {
    await _sendCommand(FtpCommands.quit());
    _controlSocket?.close();
    _dataSocket?.close();
  }

  Future<List<String>> listDirectory([String? path]) async {
    await _enterPassiveMode();
    await _sendCommandWithReconnect(FtpCommands.list(path));
    List<String> rawListing = await _dataSocket!
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .toList();
    await _closeDataConnection();
    print("Raw lsting:$rawListing");
    return rawListing;
  }

  Future<void> downloadFile(String remoteFile, String localFile,
      {Function(double)? onProgress}) async {
    await _enterPassiveMode();
    await _sendCommandWithReconnect(FtpCommands.retr(remoteFile));
    File file = File(localFile);

    int totalBytes = 0;
    int receivedBytes = 0;

    await for (List<int> chunk in _dataSocket!) {
      file.writeAsBytesSync(chunk, mode: FileMode.append);
      receivedBytes += chunk.length;
      if (totalBytes == 0) {
        // Try to get the file size from the server
        String sizeResponse = await _sendCommand(FtpCommands.size(remoteFile));
        totalBytes = int.tryParse(sizeResponse.split(' ').last) ?? 0;
      }
      if (onProgress != null && totalBytes > 0) {
        onProgress(receivedBytes / totalBytes);
      }
    }

    await _closeDataConnection();
  }

  Future<void> uploadFile(String localFile, String remoteFile,
      {Function(double)? onProgress}) async {
    await _enterPassiveMode();
    await _sendCommandWithReconnect(FtpCommands.stor(remoteFile));
    File file = File(localFile);
    int totalBytes = await file.length();
    int sentBytes = 0;

    await file.openRead().listen((List<int> chunk) async {
      _dataSocket!.add(chunk);
      sentBytes += chunk.length;
      if (onProgress != null) {
        onProgress(sentBytes / totalBytes);
      }
    }).asFuture();

    await _closeDataConnection();
  }

  Future<void> uploadFileBytes(List<int> bytes, String remoteFile,
      {Function(double)? onProgress}) async {
    await _enterPassiveMode();
    await _sendCommandWithReconnect(FtpCommands.stor(remoteFile));

    int totalBytes = bytes.length;
    int sentBytes = 0;
    int chunkSize = 4096; // You can adjust this value

    for (int i = 0; i < bytes.length; i += chunkSize) {
      int end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
      List<int> chunk = bytes.sublist(i, end);
      _dataSocket!.add(chunk);
      sentBytes += chunk.length;
      if (onProgress != null) {
        onProgress(sentBytes / totalBytes);
      }
    }

    await _closeDataConnection();
  }

  Future<void> _enterPassiveMode() async {
    String response = await _sendCommand(FtpCommands.pasv());
    RegExp ipRegex = RegExp(r'\((\d+),(\d+),(\d+),(\d+),(\d+),(\d+)\)');
    Match? match = ipRegex.firstMatch(response);
    if (match != null) {
      String ip = '${match[1]}.${match[2]}.${match[3]}.${match[4]}';
      int port = int.parse(match[5]!) * 256 + int.parse(match[6]!);
      _dataSocket =
          await Socket.connect(ip, port); // Initialize the data socket
    } else {
      throw Exception('Failed to parse PASV response');
    }
  }

  Future<void> _closeDataConnection() async {
    await _dataSocket?.close(); // Close the data socket
    _dataSocket = null;
    await _readResponse(); // Read the transfer complete message
  }

  Future<void> changeDirectory(String dirName) async {
    print("Changing directory to $dirName");
    await _sendCommandWithReconnect(
        FtpCommands.cwd(dirName)); // Send CWD command
  }

  Future<void> createDirectory(String dirName) async {
    await _sendCommandWithReconnect(FtpCommands.mkd(dirName));
  }

  Future<void> removeDirectory(String dirName) async {
    await _sendCommandWithReconnect(FtpCommands.rmd(dirName));
  }

  Future<void> deleteFile(String fileName) async {
    await _sendCommandWithReconnect(FtpCommands.dele(fileName));
  }

  Future<String> pwd() async {
    String response = await _sendCommandWithReconnect(FtpCommands.pwd());
    RegExp pathRegex = RegExp(r'257\s+"(.*?)"');
    Match? match = pathRegex.firstMatch(response);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)!;
    } else {
      throw Exception('Failed to parse PWD response');
    }
  }
}
