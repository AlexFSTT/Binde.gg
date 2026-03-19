import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DockPageTransition extends CustomTransitionPage<void> {
  const DockPageTransition({required super.child, super.key})
      : super(
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: _build,
        );

  static Widget _build(BuildContext ctx, Animation<double> anim,
      Animation<double> sec, Widget child) {
    final curve = CurvedAnimation(parent: anim, curve: const _MacOSCurve());
    final scale = Tween<double>(begin: 0.85, end: 1.0).animate(curve);
    final slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(curve);
    final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: anim, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
          position: slide,
          child: ScaleTransition(
              scale: scale, alignment: Alignment.bottomCenter, child: child)),
    );
  }
}

class _MacOSCurve extends Curve {
  const _MacOSCurve();
  @override
  double transformInternal(double t) => 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t);
}
