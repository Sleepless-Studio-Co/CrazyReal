import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A "Sign in with Google" button, styled to sit next to the app's other
/// authentication actions.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF3B2A21),
          side: const BorderSide(color: Color(0xFFD9CBB8)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _GoogleLogo(),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: GoogleFonts.karla(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF3B2A21),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// The multicolour Google "G". It is painted with a gradient so the button
/// needs no bundled image asset.
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const SweepGradient(
        colors: [
          Color(0xFF4285F4), // blue
          Color(0xFF34A853), // green
          Color(0xFFFBBC05), // yellow
          Color(0xFFEA4335), // red
          Color(0xFF4285F4), // blue
        ],
        stops: [0.0, 0.25, 0.5, 0.75, 1.0],
        transform: GradientRotation(0.8),
      ).createShader(bounds),
      child: const Text(
        'G',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
}
