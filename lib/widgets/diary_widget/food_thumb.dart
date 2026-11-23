import 'package:flutter/material.dart';
import 'food_image.dart';

/// كبسولة زجاجية + صورة الأكلة بارزة من الأسفل (.bob في التصميم)،
/// مع حركة طفو خفيفة.
class FoodThumb extends StatefulWidget {
  const FoodThumb({super.key, this.asset, this.width = 58, this.height = 66, this.image = 64, this.float = true,this.onPickImage});

  final String? asset;
  final double width;
  final double height;
  final double image;
  final bool float;
  final VoidCallback? onPickImage;

  @override
  State<FoodThumb> createState() => _FoodThumbState();
}

class _FoodThumbState extends State<FoodThumb> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, widget.float ? -6 * Curves.easeInOut.transform(_c.value) : 0),
        child: child,
      ),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(widget.width / 2),
                  topRight: Radius.circular(widget.width / 2),
                  bottomLeft: const Radius.circular(10),
                  bottomRight: const Radius.circular(10),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withValues(alpha: .2), Colors.white.withValues(alpha: .04)],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: .22)),
              ),
            ),
          ),
          Positioned(
            bottom: 3,
            left: (widget.width - widget.image) / 2,
            child: GestureDetector(
              onTap: widget.onPickImage,
              child: (widget.asset == null || widget.asset!.trim().isEmpty)
                  ? Container(
                width: widget.image,
                height: widget.image,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.cyanAccent.withValues(alpha: .5)),
                ),
                child: const Icon(
                  Icons.add_a_photo,
                  color: Colors.cyanAccent,
                  size: 20,
                ),
              )
                  : FoodImage(widget.asset, width: widget.image, height: widget.image),
            ),
          ),
        ]),
      ),
    );
  }
}
