import 'package:flutter/material.dart';

// 🍋 A custom route that creates a fluid Fade and Scale animation
class ModernFadeRoute extends PageRouteBuilder {
  final Widget page;

  ModernFadeRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          // You can adjust the speed here! 300ms feels very snappy.
          transitionDuration: const Duration(milliseconds: 300), 
          
          // This builds the actual animation
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            
            // 1. The Curve: easeOutCubic makes it start fast and slow down gracefully at the end
            var curve = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );

            // 2. The Fade + Scale effect
            return FadeTransition(
              opacity: curve,
              child: ScaleTransition(
                // Starts at 96% size and grows to 100%
                scale: Tween<double>(begin: 0.96, end: 1.0).animate(curve),
                child: child,
              ),
            );
          },
        );
}