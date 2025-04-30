import 'package:random_string/random_string.dart';
import 'package:flutter/material.dart';

class OtpService {
  static String generateOtp() {
    String otp = randomNumeric(6);
    // Print in console for developer testing
    print("⚠️ DEVELOPMENT OTP: $otp");
    return otp;
  }

  static Future<bool> sendOtp(
    String phoneNumber, 
    String otp, 
    BuildContext context
  ) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    
    // Display OTP on screen during development
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("DEV MODE: Your OTP is $otp"),
        duration: const Duration(seconds: 10),
        backgroundColor: Colors.orange,
      ),
    );
    return true;
  }
}