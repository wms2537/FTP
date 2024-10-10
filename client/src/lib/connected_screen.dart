import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart'; // Add this import
import 'dart:io';
import 'ftp_client.dart';
import 'package:flutter/foundation.dart';

class ConnectedScreen extends StatefulWidget {
  final FtpClient ftpClient;

  const ConnectedScreen({super.key, required this.ftpClient});

  @override
  State<ConnectedScreen> createState() => _ConnectedScreenState();
}

class _ConnectedScreenState extends State<ConnectedScreen> {
  List<String> _directoryListing = [];
  String _currentPath = '/';
  bool _isLoading = false;
  bool _isDragging = false;
  double _uploadProgress = 0.0;
  double _downloadProgress = 0.0;
  bool _isUploading = false;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _listDirectory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DropTarget(
        onDragDone: (detail) {
          _uploadFiles(detail.files);
        },
        onDragEntered: (detail) {
          setState(() {
            _isDragging = true;
          });
        },
        onDragExited: (detail) {
          setState(() {
            _isDragging = false;
          });
        },
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Current Directory: $_currentPath',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.create_new_folder),
                        onPressed: _createNewDirectory,
                        tooltip: 'Create New Directory',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: _listDirectory,
                          child: ListView.builder(
                            itemCount: _directoryListing.length + 1,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                if (_currentPath != '/') {
                                  return ListTile(
                                    leading: const Icon(Icons.folder,
                                        color: Colors.amber),
                                    title: const Text('..'),
                                    onTap: () => _navigateToDirectory('..'),
                                  );
                                } else {
                                  return Container();
                                }
                              }
                              final item = _directoryListing[index - 1];
                              final isDirectory = _isDirectory(item);
                              final fileName = _getFileName(item);
                              return ListTile(
                                leading: Icon(
                                  isDirectory
                                      ? Icons.folder
                                      : Icons.insert_drive_file,
                                  color:
                                      isDirectory ? Colors.amber : Colors.blue,
                                ),
                                title: Text(fileName),
                                onTap: () => isDirectory
                                    ? _navigateToDirectory(fileName)
                                    : _downloadFile(fileName),
                                trailing: isDirectory
                                    ? null
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.download),
                                            onPressed: () =>
                                                _downloadFile(fileName),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete),
                                            onPressed: () =>
                                                _deleteFile(fileName),
                                          ),
                                        ],
                                      ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
            if (_isDragging)
              Container(
                color: Colors.blue.withOpacity(0.2),
                child: const Center(
                  child: Text(
                    'Drop files here to upload',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            if (_isUploading)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(value: _uploadProgress),
                        const SizedBox(height: 16),
                        Text(
                            'Uploading: ${(_uploadProgress * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            if (_isDownloading)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(value: _downloadProgress),
                        const SizedBox(height: 16),
                        Text(
                            'Downloading: ${(_downloadProgress * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadFile,
        tooltip: 'Upload File',
        child: const Icon(Icons.upload_file),
      ),
    );
  }

  Future<void> _listDirectory() async {
    setState(() {
      _isLoading = true;
    });
    try {
      List<String> listing = await widget.ftpClient.listDirectory();
      setState(() {
        _directoryListing = listing;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to list directory: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToDirectory(String dirName) async {
    setState(() {
      _isLoading = true;
    });
    try {
      String newPath = _currentPath.substring(1);
      if (dirName == '..') {
        List<String> pathParts = _currentPath.split('/')..removeLast();

        newPath = "/" + pathParts.join('/');
        // if (!_currentPath.endsWith('/')) {
        //   _currentPath += '/';
        // }
      } else {
        newPath = "/$newPath/$dirName";
        // if (!_currentPath.endsWith('/')) {
        //   _currentPath += '/';
        // }
      }
      await widget.ftpClient.changeDirectory("$newPath");
      _currentPath = await widget.ftpClient.pwd();

      _listDirectory();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to change directory: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _downloadFile(String fileName) async {
    String? downloadPath = await FilePicker.platform.getDirectoryPath();
    if (downloadPath != null) {
      setState(() {
        _isDownloading = true;
        _downloadProgress = 0.0;
      });
      try {
        String localFile = '$downloadPath/$fileName';
        await widget.ftpClient.downloadFile(
          fileName,
          localFile,
          onProgress: (progress) {
            setState(() {
              _downloadProgress = progress;
            });
          },
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File downloaded successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download file: $e')),
        );
      } finally {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  void _deleteFile(String fileName) async {
    setState(() {
      _isLoading = true;
    });
    try {
      await widget.ftpClient.deleteFile(fileName);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File "$fileName" deleted successfully')),
      );
      _listDirectory();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete file: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _createNewDirectory() async {
    String? newDirName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        String tempDirName = '';
        return AlertDialog(
          title: const Text('Create New Directory'),
          content: TextField(
            onChanged: (value) => tempDirName = value,
            decoration: const InputDecoration(hintText: "Enter directory name"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Create'),
              onPressed: () => Navigator.of(context).pop(tempDirName),
            ),
          ],
        );
      },
    );

    if (newDirName != null && newDirName.isNotEmpty) {
      setState(() {
        _isLoading = true;
      });
      try {
        await widget.ftpClient.createDirectory(newDirName);
        _listDirectory();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Directory "$newDirName" created successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create directory: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _uploadFiles(List<XFile> files) async {
    for (XFile file in files) {
      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
      });
      try {
        final bytes = await file.readAsBytes();
        await widget.ftpClient.uploadFileBytes(
          bytes,
          file.name,
          onProgress: (progress) {
            setState(() {
              _uploadProgress = progress;
            });
          },
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File "${file.name}" uploaded successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload file: $e')),
        );
      } finally {
        setState(() {
          _isUploading = false;
        });
      }
    }
    _listDirectory();
  }

  void _uploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
      });
      try {
        String filePath = result.files.single.path!;
        String fileName = result.files.single.name;
        await widget.ftpClient.uploadFile(
          filePath,
          fileName,
          onProgress: (progress) {
            setState(() {
              _uploadProgress = progress;
            });
          },
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File uploaded successfully')),
        );
        _listDirectory();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload file: $e')),
        );
      } finally {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  bool _isDirectory(String item) {
    return item.startsWith('d');
  }

  String _getFileName(String item) {
    List<String> parts = item.split(RegExp(r'\s+'));
    return parts.sublist(8).join(' ');
  }
}
