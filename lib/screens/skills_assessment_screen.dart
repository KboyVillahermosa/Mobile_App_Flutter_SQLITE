import 'package:flutter/material.dart';
import '../helpers/database_helper.dart';
import '../models/user.dart';
import 'home_screen.dart';

class SkillsAssessment extends StatefulWidget {
  final User user;
  final bool isEditing;

  const SkillsAssessment({
    Key? key, 
    required this.user,
    this.isEditing = false,
  }) : super(key: key);

  @override
  _SkillsAssessmentState createState() => _SkillsAssessmentState();
}

class _SkillsAssessmentState extends State<SkillsAssessment> with SingleTickerProviderStateMixin {
  final _dbHelper = DatabaseHelper();
  int _currentStep = 0;
  final List<String> _selectedSkills = [];
  final TextEditingController _customSkillController = TextEditingController();
  bool _isLoading = false;
  final PageController _pageController = PageController(initialPage: 0);
  
  // Predefined skill categories
  final Map<String, List<String>> _skillCategories = {
    'Technical': [
      'Carpentry', 'Plumbing', 'Electrical', 'Painting', 'Roofing', 
      'Masonry', 'Welding', 'HVAC', 'Landscaping'
    ],
    'Professional': [
      'Accounting', 'Legal', 'Marketing', 'Design', 'Writing', 
      'Teaching', 'Consultation', 'Project Management'
    ],
    'Domestic': [
      'Cleaning', 'Cooking', 'Babysitting', 'Pet Care', 'Gardening', 
      'Elderly Care', 'Grocery Shopping'
    ],
  };
  
  // Category icons for UI - separate from the data structure
  final Map<String, IconData> _categoryIcons = {
    'Technical': Icons.build,
    'Professional': Icons.work,
    'Domestic': Icons.home,
  };

  final List<String> _steps = [
    'Select Skills',
    'Add Custom Skills',
    'Review & Finalize'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadUserSkills();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _customSkillController.dispose();
    super.dispose();
  }

  Future<void> _loadUserSkills() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final skills = await _dbHelper.getUserSkills(widget.user.id!);
      setState(() {
        _selectedSkills.addAll(skills);
      });
    } catch (e) {
      // Handle error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load skills: $e'))
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSkills() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _dbHelper.updateUserSkills(widget.user.id!, _selectedSkills);
      
      if (!widget.isEditing) {
        await _dbHelper.markAssessmentComplete(widget.user.id!);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Skills saved successfully!'),
            behavior: SnackBarBehavior.floating,
          )
        );
        
        if (!widget.isEditing) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => HomeScreen(phoneNumber: widget.user.phoneNumber),
            ),
            (route) => false,
          );
        } else {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save skills: $e'))
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _goToNextPage() {
    if (_currentStep < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep++;
      });
    } else {
      _saveSkills();
    }
  }

  void _goToPreviousPage() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep--;
      });
    } else if (widget.isEditing) {
      Navigator.of(context).pop();
    }
  }

  void _addCustomSkill() {
    final skill = _customSkillController.text.trim();
    if (skill.isNotEmpty && !_selectedSkills.contains(skill)) {
      setState(() {
        _selectedSkills.add(skill);
        _customSkillController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Skills' : 'Professional Skills'),
        automaticallyImplyLeading: widget.isEditing,
        backgroundColor: const Color(0xFF06D6A0),
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF06D6A0)))
        : Column(
            children: [
              // Progress indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _steps[_currentStep],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF06D6A0),
                          ),
                        ),
                        Text(
                          'Step ${_currentStep + 1} of ${_steps.length}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (_currentStep + 1) / _steps.length,
                      backgroundColor: Colors.grey[300],
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF06D6A0)),
                      minHeight: 5,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ],
                ),
              ),

              // Main content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    // STEP 1: Choose skills from categories
                    _buildCategoriesPage(),
                    
                    // STEP 2: Add custom skills
                    _buildCustomSkillsPage(),
                    
                    // STEP 3: Review and confirm
                    _buildReviewPage(),
                  ],
                ),
              ),

              // Bottom navigation
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentStep > 0 || widget.isEditing)
                      ElevatedButton(
                        onPressed: _goToPreviousPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.grey[800],
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_back, size: 16),
                            const SizedBox(width: 8),
                            Text(_currentStep > 0 ? 'Back' : 'Cancel'),
                          ],
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    
                    ElevatedButton(
                      onPressed: _selectedSkills.isEmpty && _currentStep == _steps.length - 1 
                        ? null // Disable if no skills selected on final step
                        : _goToNextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF06D6A0),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[400],
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_currentStep < _steps.length - 1 ? 'Continue' : 'Complete'),
                          const SizedBox(width: 8),
                          Icon(
                            _currentStep < _steps.length - 1 
                              ? Icons.arrow_forward 
                              : Icons.check_circle,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildCategoriesPage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Select your professional skills',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          ..._skillCategories.entries.map((entry) {
            final category = entry.key;
            final skills = entry.value;
            final icon = _categoryIcons[category] ?? Icons.label;
            
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF06D6A0).withOpacity(0.1),
                    child: Icon(icon, color: const Color(0xFF06D6A0)),
                  ),
                  title: Text(
                    category,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  childrenPadding: const EdgeInsets.all(16),
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: skills.map((skill) {
                        final isSelected = _selectedSkills.contains(skill);
                        return FilterChip(
                          label: Text(skill),
                          selected: isSelected,
                          showCheckmark: false,
                          avatar: isSelected 
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : null,
                          backgroundColor: Colors.grey[200],
                          selectedColor: const Color(0xFF06D6A0),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedSkills.add(skill);
                              } else {
                                _selectedSkills.remove(skill);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildCustomSkillsPage() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add Your Custom Skills',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Don\'t see your skills in our list? Add your own specialized skills here.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customSkillController,
                          decoration: InputDecoration(
                            labelText: 'Enter a custom skill',
                            hintText: 'e.g., Machine Learning',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF06D6A0), width: 2),
                            ),
                          ),
                          onSubmitted: (_) => _addCustomSkill(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addCustomSkill,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF06D6A0),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.all(15),
                          minimumSize: const Size(50, 58),
                        ),
                        child: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          if (_selectedSkills.isNotEmpty) ...[
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.list, color: Color(0xFF06D6A0)),
                        const SizedBox(width: 8),
                        const Text(
                          'Your Selected Skills',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_selectedSkills.length} selected',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: _selectedSkills.map((skill) {
                        return Chip(
                          label: Text(skill),
                          labelStyle: const TextStyle(fontWeight: FontWeight.w500),
                          backgroundColor: const Color(0xFF06D6A0).withOpacity(0.1),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          deleteIconColor: const Color(0xFF06D6A0),
                          onDeleted: () {
                            setState(() {
                              _selectedSkills.remove(skill);
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewPage() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF06D6A0)),
                      SizedBox(width: 8),
                      Text(
                        'Review Your Professional Skills',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'These skills will be visible on your profile and help match you with relevant opportunities.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  if (_selectedSkills.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.red[400]),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'No skills selected. Please go back and select at least one skill.',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: _selectedSkills.map((skill) {
                            return Chip(
                              label: Text(skill),
                              backgroundColor: const Color(0xFF06D6A0).withOpacity(0.1),
                              labelStyle: const TextStyle(fontWeight: FontWeight.w500),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info, color: Colors.blue[400]),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'You can edit your skills at any time from your profile settings.',
                                  style: TextStyle(color: Color(0xFF1976D2)), // Fixed blue shade 700
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}