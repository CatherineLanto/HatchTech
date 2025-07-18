import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() {
  runApp(const HatchTechApp());
}

class HatchTechApp extends StatelessWidget {
  const HatchTechApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'HatchTech',
          themeMode: mode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent, brightness: Brightness.light),
            textTheme: GoogleFonts.poppinsTextTheme(),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blueAccent, 
              brightness: Brightness.dark,
            ).copyWith(
              // Enhanced contrast colors for dark mode
              surface: const Color(0xFF121212), // Darker background
              onSurface: Colors.white, // High contrast text
              surfaceContainerHighest: const Color(0xFF1E1E1E), // Card backgrounds
              onSurfaceVariant: const Color(0xFFE1E1E1), // Secondary text
              primary: const Color(0xFF6BB6FF), // Brighter blue for better visibility
              onPrimary: Colors.black, // High contrast on primary
              secondary: const Color(0xFF03DAC6), // Teal accent
              onSecondary: Colors.black,
              error: const Color(0xFFCF6679), // Softer red for dark mode
              onError: Colors.black,
              outline: const Color(0xFF3A3A3A), // Border colors
            ),
            scaffoldBackgroundColor: const Color(0xFF121212),
            cardColor: const Color(0xFF1E1E1E),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF1E1E1E),
            ),
            textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme).copyWith(
              // Enhanced text contrast while preserving font family
              bodyLarge: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
              bodyMedium: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
              titleLarge: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              titleMedium: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              headlineSmall: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              labelLarge: GoogleFonts.poppins(color: const Color(0xFFE1E1E1), fontSize: 14),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF2A2A2A), // Darker input fields
              labelStyle: const TextStyle(color: Color(0xFFB0B0B0)),
              hintStyle: const TextStyle(color: Color(0xFF707070)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF6BB6FF), width: 2),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6BB6FF), // Brighter blue
                foregroundColor: Colors.black, // High contrast text
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1E1E1E),
              foregroundColor: Colors.white,
              elevation: 0,
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            switchTheme: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFF6BB6FF);
                }
                return const Color(0xFF707070);
              }),
              trackColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFF6BB6FF).withValues(alpha: 0.5);
                }
                return const Color(0xFF3A3A3A);
              }),
            ),
          ),
          home: LoginScreen(themeNotifier: themeNotifier),
        );
      },
    );
  }
}
