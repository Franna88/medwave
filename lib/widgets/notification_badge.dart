import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NotificationBadge extends StatelessWidget {
  final int count;
  final double size;
  final Color? backgroundColor;
  final Color? textColor;
  final bool showCount;
  final Widget? child;

  const NotificationBadge({
    super.key,
    required this.count,
    this.size = 16.0,
    this.backgroundColor,
    this.textColor,
    this.showCount = true,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return child ?? const SizedBox.shrink();
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (child != null) child!,
        Positioned(
          right: -4,
          top: -4,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: backgroundColor ?? AppTheme.errorColor,
              borderRadius: BorderRadius.circular(size / 2),
            ),
            constraints: BoxConstraints(
              minWidth: size,
              minHeight: size,
            ),
            child: showCount
                ? Text(
                    count > 99 ? '99+' : count.toString(),
                    style: TextStyle(
                      color: textColor ?? Colors.white,
                      fontSize: size * 0.6,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

class NotificationDot extends StatelessWidget {
  final bool show;
  final double size;
  final Color? color;

  const NotificationDot({
    super.key,
    required this.show,
    this.size = 8.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (!show) {
      return const SizedBox.shrink();
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color ?? AppTheme.primaryColor,
        shape: BoxShape.circle,
      ),
    );
  }
}
