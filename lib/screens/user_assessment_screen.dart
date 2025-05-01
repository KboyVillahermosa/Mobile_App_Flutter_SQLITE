import 'package:flutter/material.dart';
import 'home_screen.dart';

class UserAssessmentScreen extends StatefulWidget {
  final String phoneNumber;

  const UserAssessmentScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<UserAssessmentScreen> createState() => _UserAssessmentScreenState();
}

class _UserAssessmentScreenState extends State<UserAssessmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  String _selectedAgeGroup = '';
  List<String> _selectedInterests = [];
  bool _isSubmitting = false;

  final List<String> _ageGroups = [
    '18-24', '25-34', '35-44', '45-54', '55+'
  ];

  final List<String> _interests = [
    'Technology', 'Health', 'Finance', 'Education', 
    'Entertainment', 'Sports', 'Travel', 'Food'
  ];

  Future<void> _submitAssessment() async {
    if (_formKey.currentState!.validate() && _selectedAgeGroup.isNotEmpty) {
      setState(() {
        _isSubmitting = true;
      });

      try {
        // Simulate network delay for data submission
        await Future.delayed(const Duration(seconds: 1));
        
        if (!mounted) return;
        
        // Navigate to home screen after assessment
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(
              phoneNumber: widget.phoneNumber,
            ),
          ),
          (route) => false,
        );
      } finally {
        setState(() {
          _isSubmitting = false;
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFBFBFE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Tell Us About Yourself',
          style: TextStyle(
            color: Color(0xFF050315),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Complete this quick assessment to personalize your experience',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF050315).withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Name field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: const Icon(
                          Icons.person_outline,
                          color: Color(0xFF64DFDF),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Color(0xFF64DFDF).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF06D6A0),
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Age group selection
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Age Group*',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF050315),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _ageGroups.map((age) {
                            return ChoiceChip(
                              label: Text(age),
                              selected: _selectedAgeGroup == age,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedAgeGroup = selected ? age : '';
                                });
                              },
                              backgroundColor: Colors.white,
                              selectedColor: Color(0xFF06D6A0).withOpacity(0.2),
                              labelStyle: TextStyle(
                                color: _selectedAgeGroup == age
                                    ? Color(0xFF06D6A0)
                                    : Color(0xFF050315),
                                fontWeight: _selectedAgeGroup == age
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: _selectedAgeGroup == age
                                      ? Color(0xFF06D6A0)
                                      : Color(0xFF64DFDF).withOpacity(0.3),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Interests selection
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Your Interests (Optional)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF050315),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _interests.map((interest) {
                            return FilterChip(
                              label: Text(interest),
                              selected: _selectedInterests.contains(interest),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedInterests.add(interest);
                                  } else {
                                    _selectedInterests.remove(interest);
                                  }
                                });
                              },
                              backgroundColor: Colors.white,
                              selectedColor: Color(0xFF80FFDB).withOpacity(0.3),
                              labelStyle: TextStyle(
                                color: _selectedInterests.contains(interest)
                                    ? Color(0xFF050315)
                                    : Color(0xFF050315).withOpacity(0.7),
                                fontWeight: _selectedInterests.contains(interest)
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: _selectedInterests.contains(interest)
                                      ? Color(0xFF64DFDF)
                                      : Color(0xFF64DFDF).withOpacity(0.3),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Submit button
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitAssessment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF06D6A0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      shadowColor: Color(0xFF06D6A0).withOpacity(0.5),
                      disabledBackgroundColor: Color(0xFF06D6A0).withOpacity(0.5),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Complete Setup',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}