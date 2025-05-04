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
  // Additional colors for message screen
  static const lightGrey = Color(0xFFEEEEEE);
  static const darkGrey = Color(0xFF757575);
  static const sentMessageColor = Color(0xFFE1F8F5); // Light teal matching primary theme
  static const receivedMessageColor = Color(0xFFFFFFFF); // White for received messages
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
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: _isSelectMode 
          ? IconButton(
              icon: const Icon(Icons.close, color: AppColors.textColor),
              onPressed: () {
                setState(() {
                  _isSelectMode = false;
                  _selectedMessages.clear();
                });
              },
            ) 
          : IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textColor),
              onPressed: () => Navigator.pop(context),
            ),
        title: Row(
          children: [
            if (!_isSelectMode) ...[
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.lightGrey,
                backgroundImage: _receiver?.profileImage != null 
                    ? FileImage(File(_receiver!.profileImage!)) 
                    : null,
                child: _receiver?.profileImage == null 
                    ? const Icon(Icons.person, size: 18, color: AppColors.darkGrey) 
                    : null,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isSelectMode 
                        ? '${_selectedMessages.values.where((v) => v).length} selected' 
                        : widget.receiverName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textColor),
                  ),
                  if (!_isSelectMode)
                    Text(
                      'Re: ${widget.jobTitle}',
                      style: const TextStyle(fontSize: 13, color: AppColors.darkGrey),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_isSelectMode) ...[
            IconButton(
              icon: const Icon(Icons.delete, color: AppColors.textColor),
              onPressed: _deleteSelectedMessages,
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.more_vert, color: AppColors.textColor),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                  ),
                  builder: (context) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.select_all, color: AppColors.primaryColor),
                        title: const Text('Select messages'),
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            _isSelectMode = true;
                          });
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.clear_all, color: AppColors.primaryColor),
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
          // Messages
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryColor))
                : _messages.isEmpty
                    ? _buildEmptyMessagesView()
                    : _buildMessagesList(),
          ),
          
          // Preview of attachment if any
          if (_attachmentPreview != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: Row(
                children: [
                  if (_attachmentType == 'image') ...[
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_attachmentPreview!),
                            height: 70,
                            width: 70,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _attachmentFile = null;
                                _attachmentType = null;
                                _attachmentPreview = null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else if (_attachmentType == 'document') ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accentColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.insert_drive_file, color: AppColors.primaryColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _attachmentPreview!,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textColor),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.darkGrey),
                      onPressed: () {
                        setState(() {
                          _attachmentFile = null;
                          _attachmentType = null;
                          _attachmentPreview = null;
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),
          
          // Input field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Attachment button
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.accentColor.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add, color: AppColors.primaryColor),
                      onPressed: () => _showAttachmentOptions(),
                    ),
                  ),
                  
                  // Message input field
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.lightGrey,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: AppColors.darkGrey),
                          border: InputBorder.none,
                        ),
                        minLines: 1,
                        maxLines: 4,
                      ),
                    ),
                  ),
                  
                  // Send button
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMessagesView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start the conversation with ${widget.receiverName}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    final Map<String, List<Map<String, dynamic>>> groupedMessages = {};
    final dateFormat = DateFormat('MMMM d, yyyy');

    for (final message in _messages) {
      final messageDate = DateTime.parse(message['timestamp']);
      final dateKey = dateFormat.format(messageDate);

      if (!groupedMessages.containsKey(dateKey)) {
        groupedMessages[dateKey] = [];
      }
      groupedMessages[dateKey]!.add(message);
    }

    final List<dynamic> messagesWithHeaders = [];
    groupedMessages.forEach((date, messages) {
      messagesWithHeaders.add({'type': 'header', 'date': date});
      messagesWithHeaders.addAll(messages.map((msg) => {'type': 'message', 'data': msg}));
    });

    return ListView.builder(
      controller: _scrollController,
      itemCount: messagesWithHeaders.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final item = messagesWithHeaders[index];

        if (item['type'] == 'header') {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                item['date'],
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.darkGrey,
                ),
              ),
            ),
          );
        }

        final message = item['data'];
        final isMe = message['senderId'] == widget.senderId;
        final time = DateTime.parse(message['timestamp']);
        final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

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
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isSelectMode)
                  Checkbox(
                    value: _selectedMessages[message['id']] ?? false,
                    onChanged: (value) {
                      setState(() {
                        _selectedMessages[message['id']] = value ?? false;
                      });
                    },
                    activeColor: AppColors.primaryColor,
                  ),

                if (!isMe && !_isSelectMode) ...[
                  CircleAvatar(
                    radius: 14,
                    backgroundImage: _receiver?.profileImage != null 
                        ? FileImage(File(_receiver!.profileImage!)) 
                        : null,
                    backgroundColor: AppColors.lightGrey,
                    child: _receiver?.profileImage == null 
                        ? const Icon(Icons.person, size: 14, color: AppColors.darkGrey) 
                        : null,
                  ),
                  const SizedBox(width: 8),
                ],

                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isMe ? AppColors.sentMessageColor : AppColors.receivedMessageColor,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(isMe ? 16 : 4),
                        topRight: Radius.circular(isMe ? 4 : 16),
                        bottomLeft: const Radius.circular(16),
                        bottomRight: const Radius.circular(16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 0,
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasAttachment) ...[
                          if (attachmentType == 'image')
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(attachmentPath),
                                height: 180,
                                width: 220,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => 
                                    Container(
                                      height: 120,
                                      width: 180,
                                      color: Colors.grey[300],
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.broken_image, color: AppColors.darkGrey),
                                    ),
                              ),
                            ),
                          if (attachmentType == 'document')
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isMe ? Colors.white.withOpacity(0.7) : AppColors.accentColor.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getFileIcon(path.extension(attachmentPath)), 
                                    color: AppColors.primaryColor
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          path.basename(attachmentPath),
                                          style: const TextStyle(
                                            color: AppColors.textColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _getFileSize(attachmentPath),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 8),
                        ],

                        if (message['message'].isNotEmpty)
                          Text(
                            message['message'],
                            style: TextStyle(
                              color: AppColors.textColor,
                              fontSize: 15,
                            ),
                          ),

                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              Icon(
                                message['isRead'] == 1 
                                    ? Icons.done_all 
                                    : Icons.done,
                                size: 14,
                                color: message['isRead'] == 1 
                                    ? AppColors.secondaryColor 
                                    : Colors.grey[600],
                              ),
                            ],
                          ],
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
    );
  }

  IconData _getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case '.pdf':
        return Icons.picture_as_pdf;
      case '.doc':
      case '.docx':
        return Icons.description;
      case '.xls':
      case '.xlsx':
        return Icons.table_chart;
      case '.ppt':
      case '.pptx':
        return Icons.slideshow;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _getFileSize(String filePath) {
    try {
      final file = File(filePath);
      final bytes = file.lengthSync();
      if (bytes < 1024) {
        return '$bytes B';
      } else if (bytes < 1024 * 1024) {
        return '${(bytes / 1024).toStringAsFixed(1)} KB';
      } else {
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    } catch (e) {
      return 'Unknown size';
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Attach File',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textColor,
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAttachmentOption(
                  icon: Icons.image,
                  color: AppColors.secondaryColor,
                  label: 'Photo',
                  onTap: () {
                    Navigator.pop(context);
                    _handleImageAttachment();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.insert_drive_file,
                  color: AppColors.primaryColor,
                  label: 'Document',
                  onTap: () {
                    Navigator.pop(context);
                    _handleDocumentAttachment();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.location_on,
                  color: Colors.redAccent,
                  label: 'Location',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Location sharing coming soon"))
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon, 
    required Color color, 
    required String label, 
    required VoidCallback onTap
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}