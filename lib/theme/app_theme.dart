// Project: Milo App
// File path: /hey_milo/lib/theme/app_theme.dart
// Purpose: Define the application theme with dark background, white text,
//          and accessibility-focused design elements
// Date: May 4, 2025

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Application theme configuration
///
/// Defines color schemes, text styles, and component themes
/// optimized for elderly users (55+) with accessibility considerations.
class AppTheme {
  AppTheme._();

  // Primary colors
  static const Color _primaryDark = Color(0xFF5B86E5);
  static const Color _primaryLight = Color(0xFF36D1DC);

  // Background colors
  static const Color _backgroundDark = Color(0xFF121212);
  static const Color _cardBackgroundDark = Color(0xFF1E1E1E);

  // Text colors
  static const Color _textPrimaryDark = Color(0xFFFFFFFF);
  static const Color _textSecondaryDark = Color(0xFFB0B0B0);

  // Accent colors
  static const Color _accentGreen = Color(0xFF4CAF50);
  static const Color _accentRed = Color(0xFFE57373);

  // Font sizes
  static const double _fontSizeHeading = 28.0;
  static const double _fontSizeSubheading = 24.0;
  static const double _fontSizeBody = 18.0;
  static const double _fontSizeCaption = 16.0;

  // Touch sizes
  static const double _minButtonHeight = 56.0;
  static const double _minButtonWidth = 88.0;
  static const double _iconSize = 32.0;

  // Spacing
  static const double _spacing = 16.0;
  static const double _spacingLarge = 24.0;

  // Border radius
  static const double _borderRadius = 12.0;
  static double borderRadius(BuildContext context) {
    return _borderRadius; // Using the private constant defined in AppTheme
  }

  static final ThemeData lightTheme = ThemeData(
    colorScheme: _darkColorScheme,
    brightness: Brightness.dark,
  );

  static final ThemeData darkTheme = ThemeData(
    colorScheme: _darkColorScheme,
    brightness: Brightness.dark,

    cardTheme: CardTheme(
      color: _cardBackgroundDark,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_borderRadius),
      ),
      margin: EdgeInsets.all(_spacing),
    ),

    dividerTheme: DividerThemeData(color: Colors.white12, thickness: 1),

    textTheme: TextTheme(
      displayLarge: TextStyle(
        color: _textPrimaryDark,
        fontSize: _fontSizeHeading,
        fontWeight: FontWeight.bold,
      ),
      displayMedium: TextStyle(
        color: _textPrimaryDark,
        fontSize: _fontSizeSubheading,
        fontWeight: FontWeight.bold,
      ),
      bodyLarge: TextStyle(
        color: _textPrimaryDark,
        fontSize: _fontSizeBody,
        fontWeight: FontWeight.normal,
      ),
      bodyMedium: TextStyle(
        color: _textPrimaryDark,
        fontSize: _fontSizeBody,
        fontWeight: FontWeight.normal,
      ),
      titleLarge: TextStyle(
        color: _textPrimaryDark,
        fontSize: _fontSizeSubheading,
        fontWeight: FontWeight.bold,
      ),
      titleMedium: TextStyle(
        color: _textPrimaryDark,
        fontSize: _fontSizeBody,
        fontWeight: FontWeight.bold,
      ),
      labelLarge: TextStyle(
        color: _textPrimaryDark,
        fontSize: _fontSizeBody,
        fontWeight: FontWeight.bold,
      ),
      bodySmall: TextStyle(
        color: _textSecondaryDark,
        fontSize: _fontSizeCaption,
        fontWeight: FontWeight.normal,
      ),
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: _backgroundDark,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: TextStyle(
        color: _textPrimaryDark,
        fontSize: _fontSizeSubheading,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: _textPrimaryDark, size: _iconSize),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(_primaryDark),
        foregroundColor: WidgetStateProperty.all(_textPrimaryDark),
        minimumSize: WidgetStateProperty.all(
          Size(_minButtonWidth, _minButtonHeight),
        ),
        padding: WidgetStateProperty.all(
          EdgeInsets.symmetric(horizontal: _spacingLarge, vertical: _spacing),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_borderRadius),
          ),
        ),
        textStyle: WidgetStateProperty.all(
          TextStyle(fontSize: _fontSizeBody, fontWeight: FontWeight.bold),
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.all(_primaryLight),
        minimumSize: WidgetStateProperty.all(
          Size(_minButtonWidth, _minButtonHeight),
        ),
        padding: WidgetStateProperty.all(
          EdgeInsets.symmetric(horizontal: _spacingLarge, vertical: _spacing),
        ),
        textStyle: WidgetStateProperty.all(
          TextStyle(fontSize: _fontSizeBody, fontWeight: FontWeight.bold),
        ),
      ),
    ),

    iconTheme: IconThemeData(color: _textPrimaryDark, size: _iconSize),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _cardBackgroundDark,
      contentPadding: EdgeInsets.all(_spacing),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_borderRadius),
        borderSide: BorderSide.none,
      ),
      hintStyle: TextStyle(color: _textSecondaryDark, fontSize: _fontSizeBody),
      labelStyle: TextStyle(color: _textPrimaryDark, fontSize: _fontSizeBody),
      errorStyle: TextStyle(color: _accentRed, fontSize: _fontSizeCaption),
    ),

    dialogTheme: DialogTheme(
      backgroundColor: _cardBackgroundDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_borderRadius),
      ),
      titleTextStyle: TextStyle(
        color: _textPrimaryDark,
        fontSize: _fontSizeSubheading,
        fontWeight: FontWeight.bold,
      ),
      contentTextStyle: TextStyle(
        color: _textPrimaryDark,
        fontSize: _fontSizeBody,
      ),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          return _primaryLight;
        }
        return _textSecondaryDark;
      }),
      trackColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          return _primaryDark.withAlpha(128);
        }
        return _textSecondaryDark.withAlpha(77);
      }),
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          return _primaryDark;
        }
        return _textSecondaryDark;
      }),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: _backgroundDark,
      selectedItemColor: _primaryLight,
      unselectedItemColor: _textSecondaryDark,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedLabelStyle: TextStyle(
        fontSize: _fontSizeCaption,
        fontWeight: FontWeight.bold,
      ),
      unselectedLabelStyle: TextStyle(fontSize: _fontSizeCaption),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: _primaryLight,
      circularTrackColor: _cardBackgroundDark,
      linearTrackColor: _cardBackgroundDark,
    ),
  );

  static const ColorScheme _darkColorScheme = ColorScheme(
    primary: _primaryDark,
    primaryContainer: _primaryLight,
    secondary: _primaryLight,
    secondaryContainer: _primaryDark,
    surface: _cardBackgroundDark,
    error: _accentRed,
    onPrimary: _textPrimaryDark,
    onSecondary: _textPrimaryDark,
    onSurface: _textPrimaryDark,
    brightness: Brightness.dark,
    onError: _textPrimaryDark,
  );

  static Color successColor(BuildContext context) => _accentGreen;
  static Color errorColor(BuildContext context) => _accentRed;
}
