import 'package:flutter/material.dart';

class SmoothRoute<T> extends PageRouteBuilder<T> {
  SmoothRoute(Widget page)
      : super(
          transitionDuration: const Duration(milliseconds: 380),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (_, _, _) => page,
          transitionsBuilder: (_, animation, _, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
}
