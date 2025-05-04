import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../helpers/database_helper.dart';
import '../models/user.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

// Color palette definition - consistent with other screens
class AppColors {
  static const textColor = Color(0xFF050315);
  static const backgroundColor = Color(0xFFFBFBFE);
  static const primaryColor = Color(0xFF06D6A0);
  static const secondaryColor = Color(0xFF64DFDF);
  static const accentColor = Color(0xFF80FFDB);
}

class MessageScreen extends StatefulWidget {
  final int jobId;
  final String jobTitle;
  final int senderId;
  final int receiverId;
  final String receiverName;

  const MessageScreen({
    Key? key,
    required this.jobId,
    required this.senderId,
    required this.receiverId,
    required this.jobTitle,
    required this.receiverName,
  }) : super(key: key);

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  List<Map<String, dynamic>> _messages = [];
  User? _sender;
  User? _receiver;
  bool _isLoading = true;
  Timer? _refreshTimer;
  Map<int, bool> _selectedMessages = {}; // Track selected messages for deletion
  bool _isSelectMode = false;
  
  // For attachments
  File? _attachmentFile;
  String? _attachmentType;
  String? _attachmentPreview;

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
    _loadMessages();
    
    // Set up refresh timer to check for new messages every 5 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && !_isSelectMode) {
        _loadMessages(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserDetails() async {
    try {
      _sender = await _dbHelper.getUserById(widget.senderId);
      _receiver = await _dbHelper.getUserById(widget.receiverId);
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error loading user details: $e');
    }
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final messages = await _dbHelper.getMessagesByJob(
        widget.jobId,
        widget.senderId,
        widget.receiverId,
      );
      
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
      }

      // Mark messages as read
      for (var message in messages) {
        if (message['receiverId'] == widget.senderId && message['isRead'] == 0) {
          await _dbHelper.markMessageAsRead(message['id']);
        }
      }

      // Scroll to bottom after messages load
      if (_messages.isNotEmpty && _scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      }
    } catch (e) {
      print('Error loading messages: $e');
      if (!silent && mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Add this method to delete messages
  Future<void> _deleteSelectedMessages() async {
    try {
      // Get IDs of selected messages
      final selectedIds = _selectedMessages.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();
      
      if (selectedIds.isEmpty) return;
      
      // Show confirmation dialog
      final shouldDelete = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Delete Messages"),
          content: Text("Delete ${selectedIds.length} selected message(s)?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("CANCEL"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("DELETE", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ) ?? false;
      
      if (!shouldDelete) return;

      // Delete messages from database
      await _dbHelper.deleteMessages(selectedIds);

      // Exit select mode and refresh messages
      setState(() {
        _isSelectMode = false;
        _selectedMessages.clear();
      });
      
      // Reload messages
      _loadMessages();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${selectedIds.length} message(s) deleted"))
      );
    } catch (e) {
      print('Error deleting messages: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting messages: $e"))
      );
    }
  }

  // Methods for handling attachments
  Future<void> _handleImageAttachment() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image == null) return;
      
      // Save image to app directory for persistence
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedFile = File('${directory.path}/attachments/$fileName');
      
      // Create attachments directory if it doesn't exist
      await Directory('${directory.path}/attachments').create(recursive: true);
      
      // Copy the image file to our app directory
      await File(image.path).copy(savedFile.path);
      
      setState(() {
        _attachmentFile = savedFile;
        _attachmentType = 'image';
        _attachmentPreview = savedFile.path;
      });
      
    } catch (e) {
      print('Error attaching image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error attaching image"))
      );
    }
  }

  Future<void> _handleDocumentAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );
      
      if (result == null || result.files.isEmpty) return;
      
      final file = result.files.first;
      
      if (file.path == null) return;
      
      // Save document to app directory for persistence
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'doc_${DateTime.now().millisecondsSinceEpoch}${path.extension(file.path!)}';
      final savedFile = File('${directory.path}/attachments/$fileName');
      
      // Create attachments directory if it doesn't exist
      await Directory('${directory.path}/attachments').create(recursive: true);
      
      // Copy the document file to our app directory
      await File(file.path!).copy(savedFile.path);
      
      setState(() {
        _attachmentFile = savedFile;
        _attachmentType = 'document';
        _attachmentPreview = file.name;
      });
      
    } catch (e) {
      print('Error attaching document: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error attaching document"))
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty && _attachmentFile == null) return;

    final message = _messageController.text.trim();
    _messageController.clear();
    
    // Clear attachment after capturing its data
    final attachmentFile = _attachmentFile;
    final attachmentType = _attachmentType;
    setState(() {
      _attachmentFile = null;
      _attachmentType = null;
      _attachmentPreview = null;
    });

    try {
      // Prepare message data
      final messageData = {
        'senderId': widget.senderId,
        'receiverId': widget.receiverId,
        'jobId': widget.jobId,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
        'isRead': 0,
      };
      
      // Add attachment info if present
      if (attachmentFile != null && attachmentType != null) {
        messageData['attachmentPath'] = attachmentFile.path;
        messageData['attachmentType'] = attachmentType;
      }
      
      // Insert message
      final messageId = await _dbHelper.insertMessage(messageData);
      
      // Create notification for receiver
      await _dbHelper.createNotification(
        widget.receiverId,
        widget.senderId,
        'message',
        'New message regarding ${widget.jobTitle}',
        '{"jobId": ${widget.jobId}, "messagePreview": "$message"}',
      );
      
      _loadMessages();
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: _isSelectMode 
          ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isSelectMode = false;
                  _selectedMessages.clear();
                });
              },
            ) 
          : null,
        title: Row(
          children: [
            if (!_isSelectMode) ...[
              CircleAvatar(
                radius: 16,
                backgroundImage: _receiver?.profileImage != null 
                    ? FileImage(File(_receiver!.profileImage!)) 
                    : null,
                child: _receiver?.profileImage == null 
                    ? const Icon(Icons.person, size: 16) 
                    : null,
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isSelectMode 
                        ? '${_selectedMessages.values.where((v) => v).length} selected' 
                        : widget.receiverName,
                    style: const TextStyle(fontSize: 16, color: Colors.black),
                  ),
                  if (!_isSelectMode)
                    Text(
                      'Re: ${widget.jobTitle}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_isSelectMode) ...[
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteSelectedMessages,
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.select_all),
                        title: const Text('Select messages'),
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            _isSelectMode = true;
                          });
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.clear_all),
                        title: const Text('Clear chat'),
                        onTap: () async {
                          Navigator.pop(context);
                          // Show confirmation dialog
                          final shouldClear = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("Clear Chat"),
                              content: const Text("Are you sure you want to delete all messages in this conversation?"),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text("CANCEL"),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text("CLEAR", style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          ) ?? false;
                          
                          if (shouldClear) {
                            await _dbHelper.clearChat(widget.jobId, widget.senderId, widget.receiverId);
                            _loadMessages();
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Date header at top
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Today',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
            ),
          ),
          
          // Messages
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMe = message['senderId'] == widget.senderId;
                      final time = DateTime.parse(message['timestamp']);
                      
                      // Get attachment info if present
                      final hasAttachment = message['attachmentPath'] != null;
                      final attachmentType = message['attachmentType'];
                      final attachmentPath = message['attachmentPath'];
                      
                      return GestureDetector(
                        onLongPress: () {
                          if (!_isSelectMode) {
                            setState(() {
                              _isSelectMode = true;
                              _selectedMessages[message['id']] = true;
                            });
                          }
                        },
                        onTap: () {
                          if (_isSelectMode) {
                            setState(() {
                              _selectedMessages[message['id']] = 
                                  !(_selectedMessages[message['id']] ?? false);
                            });
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Selection checkbox
                              if (_isSelectMode)
                                Checkbox(
                                  value: _selectedMessages[message['id']] ?? false,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedMessages[message['id']] = value ?? false;
                                    });
                                  },
                                ),
                              
                              // Message bubble
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMe ? Colors.greenAccent[400] : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Show attachment if present
                                      if (hasAttachment) ...[
                                        if (attachmentType == 'image')
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.file(
                                              File(attachmentPath),
                                              height: 150,
                                              width: 200,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => 
                                                  Container(
                                                    height: 100,
                                                    width: 100,
                                                    color: Colors.grey[300],
                                                    alignment: Alignment.center,
                                                    child: const Icon(Icons.broken_image),
                                                  ),
                                            ),
                                          ),
                                        if (attachmentType == 'document')
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.blue[50],
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.insert_drive_file, color: Colors.blue),
                                                const SizedBox(width: 8),
                                                Flexible(
                                                  child: Text(
                                                    path.basename(attachmentPath),
                                                    style: const TextStyle(color: Colors.blue),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        const SizedBox(height: 8),
                                      ],
                                      
                                      // Message text
                                      if (message['message'].isNotEmpty)
                                        Text(
                                          message['message'],
                                          style: TextStyle(
                                            color: isMe ? Colors.white : Colors.black,
                                          ),
                                        ),
                                        
                                      // Timestamp
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isMe ? Colors.white70 : Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          // Preview of attachment if any
          if (_attachmentPreview != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey[100],
              child: Row(
                children: [
                  if (_attachmentType == 'image') ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_attachmentPreview!),
                        height: 60,
                        width: 60,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ] else if (_attachmentType == 'document') ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.insert_drive_file, color: Colors.blue),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _attachmentPreview!,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _attachmentFile = null;
                        _attachmentType = null;
                        _attachmentPreview = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          
          // Input field
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 1,
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Attachment button
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    onPressed: () => _showAttachmentOptions(),
                  ),
                  
                  // Message input field
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Type a message',
                          border: InputBorder.none,
                        ),
                        minLines: 1,
                        maxLines: 4,
                      ),
                    ),
                  ),
                  
                  // Send button
                  IconButton(
                    icon: const Icon(Icons.send, color: AppColors.primaryColor),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.image, color: Colors.purple),
            ),
            title: const Text('Image'),
            onTap: () {
              Navigator.pop(context);
              _handleImageAttachment();
            },
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.insert_drive_file, color: Colors.blue),
            ),
            title: const Text('Document'),
            onTap: () {
              Navigator.pop(context);
              _handleDocumentAttachment();
            },
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_on, color: Colors.red),
            ),
            title: const Text('Location'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Location sharing coming soon"))
              );
            },
          ),
        ],
      ),
    );
  }
}