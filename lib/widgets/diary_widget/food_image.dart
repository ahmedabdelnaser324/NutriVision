import 'dart:io';
import 'package:flutter/material.dart';

/// صورة أكلة من asset أو رابط أو ملف مع بديل آمن عند الفشل
class FoodImage extends StatelessWidget {
  const FoodImage(
      this.source, {
        super.key,
        this.width,
        this.height,
        this.fit = BoxFit.contain,
      });

  final String? source;
  final double? width;
  final double? height;
  final BoxFit fit;

  Widget _buildPlaceholder() {
    final double iconSize =
    (((width ?? height ?? 40) * .5).clamp(16, 80)).toDouble();
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: .4)),
      ),
      child: Icon(
        Icons.add_a_photo,
        color: Colors.cyanAccent,
        size: iconSize,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? s = source;
    if (s == null || s.trim().isEmpty) return _buildPlaceholder();

    if (s.startsWith('assets/')) {
      return Image.asset(
        s,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }

    final Widget img = s.startsWith('http')
        ? Image.network(
      s,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildPlaceholder(),
    )
        : Image.file(
      File(s),
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildPlaceholder(),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: img,
    );
  }
}
