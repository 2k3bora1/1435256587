import 'package:flutter/material.dart';

// App Constants
const String appName = "Chit Fund Manager";
const String appVersion = "1.0.0";

// Database Constants
const String dbFileName = "chit_fund.db";
const String driveDbName = "chit_fund.db";

// Google Drive Scopes
const List<String> driveScopes = ['https://www.googleapis.com/auth/drive.file'];

// UI Constants
const Color primaryColor = Color(0xFF2C3E50);
const Color secondaryColor = Color(0xFF3498DB);
const Color backgroundColor = Color(0xFFF0F0F0);
const Color errorColor = Color(0xFFE74C3C);
const Color successColor = Color(0xFF2ECC71);

// Text Styles
const TextStyle headerStyle = TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.bold,
  color: primaryColor,
);

const TextStyle subHeaderStyle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w600,
  color: primaryColor,
);

const TextStyle bodyStyle = TextStyle(
  fontSize: 14,
  color: Colors.black87,
);

// Padding and Spacing
const double defaultPadding = 16.0;
const double smallPadding = 8.0;
const double largePadding = 24.0;

// Animation Durations
const Duration shortAnimationDuration = Duration(milliseconds: 200);
const Duration mediumAnimationDuration = Duration(milliseconds: 400);
const Duration longAnimationDuration = Duration(milliseconds: 800);