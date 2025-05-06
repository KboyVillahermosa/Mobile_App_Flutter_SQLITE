import 'package:flutter/material.dart';
import '../helpers/database_helper.dart';
import '../models/user.dart';

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

class _SkillsAssessmentState extends State<SkillsAssessment> {
  final _dbHelper = DatabaseHelper();
  int _currentStep = 0;
  final List<String> _selectedSkills = [];
  final TextEditingController _customSkillController = TextEditingController();
  bool _isLoading = false;
  
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

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadUserSkills();
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load skills: $e'))
      );
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
          const SnackBar(content: Text('Skills saved successfully!'))
        );
        
        // If we're not editing, navigate back to main app flow
        if (!widget.isEditing) {
          Navigator.of(context).pushReplacementNamed('/home');
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
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Skills' : 'Skills Assessment'),
        automaticallyImplyLeading: widget.isEditing, // Only show back button in edit mode
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Stepper(
            currentStep: _currentStep,
            onStepContinue: () {
              if (_currentStep < 2) {
                setState(() {
                  _currentStep++;
                });
              } else {
                _saveSkills();
              }
            },
            onStepCancel: () {
              if (_currentStep > 0) {
                setState(() {
                  _currentStep--;
                });
              } else if (widget.isEditing) {
                Navigator.of(context).pop();
              }
            },
            controlsBuilder: (context, details) {
              return Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: Row(
                  children: [
                    ElevatedButton(
                      onPressed: details.onStepContinue,
                      child: Text(_currentStep < 2 ? 'Next' : 'Finish'),
                    ),
                    const SizedBox(width: 12),
                    if (_currentStep > 0 || widget.isEditing)
                      TextButton(
                        onPressed: details.onStepCancel,
                        child: Text(_currentStep > 0 ? 'Back' : 'Cancel'),
                      ),
                  ],
                ),
              );
            },
            steps: [
              Step(
                title: const Text('Choose Your Skill Categories'),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _skillCategories.keys.map((category) {
                    return ExpansionTile(
                      title: Text(category),
                      children: _skillCategories[category]!.map((skill) {
                        return CheckboxListTile(
                          title: Text(skill),
                          value: _selectedSkills.contains(skill),
                          onChanged: (selected) {
                            setState(() {
                              if (selected!) {
                                _selectedSkills.add(skill);
                              } else {
                                _selectedSkills.remove(skill);
                              }
                            });
                          },
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
                isActive: _currentStep >= 0,
              ),
              Step(
                title: const Text('Add Custom Skills'),
                content: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customSkillController,
                            decoration: const InputDecoration(
                              labelText: 'Enter a custom skill',
                              hintText: 'e.g., Mobile App Development',
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _addCustomSkill,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (_selectedSkills.isNotEmpty) ...[
                      const Text('Your selected skills:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: _selectedSkills.map((skill) {
                          return Chip(
                            label: Text(skill),
                            onDeleted: () {
                              setState(() {
                                _selectedSkills.remove(skill);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ]
                  ],
                ),
                isActive: _currentStep >= 1,
              ),
              Step(
                title: const Text('Review & Complete'),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Please review your selected skills:',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    if (_selectedSkills.isEmpty)
                      const Text('No skills selected. Please go back and select at least one skill.',
                          style: TextStyle(color: Colors.red)),
                    if (_selectedSkills.isNotEmpty)
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: _selectedSkills.map((skill) {
                          return Chip(label: Text(skill));
                        }).toList(),
                      ),
                  ],
                ),
                isActive: _currentStep >= 2,
              ),
            ],
          ),
    );
  }
}