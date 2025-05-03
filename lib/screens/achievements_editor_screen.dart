import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../helpers/database_helper.dart';
import '../services/image_picker_service.dart';

class AppColors {
  static const textColor = Color(0xFF050315);
  static const backgroundColor = Color(0xFFFBFBFE);
  static const primaryColor = Color(0xFF06D6A0);
  static const secondaryColor = Color(0xFF64DFDF);
  static const accentColor = Color(0xFF80FFDB);
}

class AchievementsEditorScreen extends StatefulWidget {
  final int userId;
  final List<Map<String, dynamic>> initialAchievements;

  const AchievementsEditorScreen({
    Key? key,
    required this.userId,
    required this.initialAchievements,
  }) : super(key: key);

  @override
  State<AchievementsEditorScreen> createState() => _AchievementsEditorScreenState();
}

class _AchievementsEditorScreenState extends State<AchievementsEditorScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _achievements = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _achievements = List.from(widget.initialAchievements);
  }

  void _addNewAchievement() async {
    final result = await _showAchievementDialog();
    if (result != null) {
      setState(() {
        _achievements.add(result);
      });
    }
  }

  void _editAchievement(int index) async {
    final result = await _showAchievementDialog(_achievements[index]);
    if (result != null) {
      setState(() {
        _achievements[index] = result;
      });
    }
  }

  void _deleteAchievement(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Achievement'),
        content: const Text('Are you sure you want to delete this achievement?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _achievements.removeAt(index);
      });
    }
  }

  Future<void> _saveAchievements() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final achievementsJson = jsonEncode(_achievements);
      await _dbHelper.updateAchievements(widget.userId, achievementsJson);

      if (!mounted) return;
      Navigator.pop(context, true); // Return true to indicate success
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save achievements: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<String?> _pickCertificateImage() async {
    try {
      final File? image = await ImagePickerService.showImageSourceDialog(context);
      if (image == null) {
        return null;
      }

      final String imagePath = await ImagePickerService.saveImagePermanently(image);
      return imagePath;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  Future<Map<String, dynamic>?> _showAchievementDialog([Map<String, dynamic>? achievement]) async {
    final titleController = TextEditingController(text: achievement?['title'] ?? '');
    final issuerController = TextEditingController(text: achievement?['issuer'] ?? '');
    final dateController = TextEditingController(text: achievement?['date'] ?? '');
    final descriptionController = TextEditingController(text: achievement?['description'] ?? '');
    String? imagePath = achievement?['imagePath'];

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(achievement == null ? 'Add Achievement' : 'Edit Achievement'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  height: 180,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: imagePath != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Image.file(
                                File(imagePath!),
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    setStateDialog(() {
                                      imagePath = null;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              'Add Certificate Image',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () async {
                                final pickedImage = await _pickCertificateImage();
                                if (pickedImage != null) {
                                  setStateDialog(() {
                                    imagePath = pickedImage;
                                  });
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondaryColor,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Select Image'),
                            ),
                          ],
                        ),
                ),
                const Divider(),
                const SizedBox(height: 8),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: issuerController,
                  decoration: const InputDecoration(
                    labelText: 'Issuer',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: dateController,
                  decoration: const InputDecoration(
                    labelText: 'Date (e.g., May 2023)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Title is required'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(context, {
                  'title': titleController.text.trim(),
                  'issuer': issuerController.text.trim(),
                  'date': dateController.text.trim(),
                  'description': descriptionController.text.trim(),
                  'imagePath': imagePath,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
              ),
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementCard(Map<String, dynamic> achievement, int index) {
    final String? imagePath = achievement['imagePath'];

    return Stack(
      children: [
        Card(
          margin: EdgeInsets.zero,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imagePath != null)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Image.file(
                    File(imagePath!),
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, error, _) => Container(
                      width: double.infinity,
                      height: 100,
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            achievement['title'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editAchievement(index),
                              color: AppColors.secondaryColor,
                              tooltip: 'Edit',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteAchievement(index),
                              color: Colors.red[400],
                              tooltip: 'Delete',
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (achievement['issuer'] != null &&
                        achievement['issuer'].isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        achievement['issuer'],
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                    if (achievement['date'] != null &&
                        achievement['date'].isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        achievement['date'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    if (achievement['description'] != null &&
                        achievement['description'].isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        achievement['description'],
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_achievements.isEmpty
            ? 'Add Achievements'
            : 'Achievements (${_achievements.length})'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveAchievements,
              tooltip: 'Save',
            ),
        ],
      ),
      body: Column(
        children: [
          if (_achievements.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppColors.secondaryColor.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.secondaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You can add multiple achievements. Tap + to add more.',
                      style: TextStyle(color: Colors.grey[800]),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _achievements.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.emoji_events_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No achievements yet',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your certificates and achievements',
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _addNewAchievement,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Achievement'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: ListView.separated(
                      itemCount: _achievements.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 16),
                      itemBuilder: (context, index) =>
                          _buildAchievementCard(_achievements[index], index),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: _achievements.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _addNewAchievement,
              backgroundColor: AppColors.primaryColor,
              icon: const Icon(Icons.add),
              label: const Text('Add More'),
            ),
    );
  }
}