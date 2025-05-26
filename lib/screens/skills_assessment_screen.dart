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
        title: Text(
          widget.isEditing ? 'Edit Skills' : 'Professional Skills',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        automaticallyImplyLeading: widget.isEditing,
        backgroundColor: const Color(0xFF06D6A0),
        elevation: 0,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF06D6A0)))
        : Column(
            children: [
              // Enhanced Progress indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _steps[_currentStep],
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF06D6A0),
                            letterSpacing: 0.3,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF06D6A0).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Step ${_currentStep + 1}/${_steps.length}',
                            style: const TextStyle(
                              color: Color(0xFF06D6A0),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Custom stepped progress indicator
                    Row(
                      children: List.generate(_steps.length, (index) {
                        final isActive = index <= _currentStep;
                        return Expanded(
                          child: Container(
                            height: 6,
                            margin: EdgeInsets.only(right: index < _steps.length - 1 ? 4 : 0),
                            decoration: BoxDecoration(
                              color: isActive 
                                ? const Color(0xFF06D6A0) 
                                : const Color(0xFFE0E0E0),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),

              // Main content with improved animation
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildCategoriesPage(),
                    _buildCustomSkillsPage(),
                    _buildReviewPage(),
                  ],
                ),
              ),

              // Enhanced Bottom navigation
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.15),
                      spreadRadius: 1,
                      blurRadius: 10,
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
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_back, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              _currentStep > 0 ? 'Back' : 'Cancel',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    
                    ElevatedButton(
                      onPressed: _selectedSkills.isEmpty && _currentStep == _steps.length - 1 
                        ? null 
                        : _goToNextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF06D6A0),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[400],
                        elevation: 2,
                        shadowColor: const Color(0xFF06D6A0).withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentStep < _steps.length - 1 ? 'Continue' : 'Complete',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            _currentStep < _steps.length - 1 
                              ? Icons.arrow_forward 
                              : Icons.check_circle,
                            size: 18,
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 16, left: 4),
            child: Text(
              'Select your professional skills',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF424242)),
            ),
          ),
          ..._skillCategories.entries.map((entry) {
            final category = entry.key;
            final skills = entry.value;
            final icon = _categoryIcons[category] ?? Icons.label;
            
            return Card(
              margin: const EdgeInsets.only(bottom: 18),
              elevation: 0.5,
              shadowColor: Colors.black38,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF06D6A0).withOpacity(0.1),
                    child: Icon(icon, color: const Color(0xFF06D6A0), size: 22),
                  ),
                  title: Text(
                    category,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Color(0xFF303030),
                    ),
                  ),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  childrenPadding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: skills.map((skill) {
                        final isSelected = _selectedSkills.contains(skill);
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          child: FilterChip(
                            label: Text(skill),
                            selected: isSelected,
                            showCheckmark: false,
                            avatar: isSelected 
                              ? const Icon(Icons.check, size: 16, color: Colors.white)
                              : null,
                            backgroundColor: Colors.grey[100],
                            selectedColor: const Color(0xFF06D6A0),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
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
                          ),
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
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          Card(
            elevation: 0.5,
            shadowColor: Colors.black38,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06D6A0).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.add_circle_outline, color: Color(0xFF06D6A0)),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Add Your Custom Skills',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF303030),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Don\'t see your skills in our list? Add your own specialized skills here.',
                    style: TextStyle(color: Color(0xFF757575), fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customSkillController,
                          decoration: InputDecoration(
                            labelText: 'Enter a custom skill',
                            hintText: 'e.g., Machine Learning',
                            floatingLabelBehavior: FloatingLabelBehavior.never,
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF06D6A0), width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          onSubmitted: (_) => _addCustomSkill(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _addCustomSkill,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF06D6A0),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shadowColor: const Color(0xFF06D6A0).withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(16),
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
              elevation: 0.5,
              shadowColor: Colors.black38,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF06D6A0).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.list_alt, color: Color(0xFF06D6A0)),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Your Selected Skills',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF303030),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF06D6A0).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_selectedSkills.length} selected',
                            style: const TextStyle(
                              color: Color(0xFF06D6A0),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10.0,
                      runSpacing: 10.0,
                      children: _selectedSkills.map((skill) {
                        return Chip(
                          label: Text(skill),
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF06D6A0),
                          ),
                          backgroundColor: const Color(0xFF06D6A0).withOpacity(0.08),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          deleteIconColor: const Color(0xFF06D6A0),
                          deleteButtonTooltipMessage: "Remove skill",
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
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          Card(
            elevation: 0.5,
            shadowColor: Colors.black38,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06D6A0).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.check_circle_outline, color: Color(0xFF06D6A0), size: 24),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Review Your Professional Skills',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF303030),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06D6A0).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'These skills will be visible on your profile and help match you with relevant opportunities.',
                      style: TextStyle(color: Color(0xFF424242), height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_selectedSkills.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.red[400], size: 24),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'No skills selected. Please go back and select at least one skill.',
                              style: TextStyle(color: Colors.red, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Wrap(
                            spacing: 10.0,
                            runSpacing: 10.0,
                            children: _selectedSkills.map((skill) {
                              return Chip(
                                label: Text(skill),
                                backgroundColor: const Color(0xFF06D6A0).withOpacity(0.08),
                                labelStyle: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF06D6A0),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue[100]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue[600], size: 24),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'You can edit your skills at any time from your profile settings.',
                                  style: TextStyle(
                                    color: Color(0xFF1976D2),
                                    height: 1.4,
                                  ),
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