import 'package:flutter/material.dart';
import 'ftp_client.dart';
import 'connected_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  FtpClient? _ftpClient;
  bool _isConnected = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FTP Client'),
        actions: [
          if (_isConnected)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _disconnect,
              tooltip: 'Disconnect',
            ),
        ],
      ),
      body: Center(
        child: _isConnected
            ? ConnectedScreen(ftpClient: _ftpClient!)
            : _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: () => _showConnectDialog(context),
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(64),
                    ),
                    child: const Text(
                      "Connect",
                      style: TextStyle(fontSize: 32),
                    ),
                  ),
      ),
    );
  }

  void _showConnectDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ConnectDialog(onConnect: _connect);
      },
    );
  }

  void _connect(String host, int port, String username, String password) async {
    setState(() {
      _isLoading = true;
    });

    _ftpClient = FtpClient(host, port);
    try {
      await _ftpClient!.connect();
      await _ftpClient!.login(username, password);
      setState(() {
        _isConnected = true;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connected to FTP server')),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect: $e')),
      );
    }
  }

  void _disconnect() async {
    setState(() {
      _isLoading = true;
    });

    if (_ftpClient != null) {
      try {
        await _ftpClient!.disconnect();
      } catch (e) {
        print(e);
      }
      setState(() {
        _isConnected = false;
        _isLoading = false;
        _ftpClient = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Disconnected from FTP server')),
      );
    }
  }
}

class ConnectDialog extends StatefulWidget {
  final Function(String, int, String, String) onConnect;

  const ConnectDialog({super.key, required this.onConnect});

  @override
  State<ConnectDialog> createState() => _ConnectDialogState();
}

class _ConnectDialogState extends State<ConnectDialog> {
  final _hostController = TextEditingController(text: "127.0.0.1");
  final _portController = TextEditingController(text: "21");
  final _usernameController = TextEditingController(text: "anonymous");
  final _passwordController = TextEditingController(text: "test@test.com");

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Connect to FTP Server'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _hostController,
              decoration: const InputDecoration(labelText: 'FTP Server'),
            ),
            TextField(
              controller: _portController,
              decoration: const InputDecoration(labelText: 'Port'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onConnect(
              _hostController.text,
              int.tryParse(_portController.text) ?? 21,
              _usernameController.text,
              _passwordController.text,
            );
            Navigator.of(context).pop();
          },
          child: const Text('Connect'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
