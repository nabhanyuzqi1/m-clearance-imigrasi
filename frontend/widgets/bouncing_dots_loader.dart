import 'package:flutter/material.dart';

// Widget ini diekstrak ke file sendiri untuk menghindari duplikasi kode
// dan potensi error 'The name is already defined'.
class BouncingDotsLoader extends StatefulWidget {
  const BouncingDotsLoader({super.key});
  @override
  State<BouncingDotsLoader> createState() => _BouncingDotsLoaderState();
}

class _BouncingDotsLoaderState extends State<BouncingDotsLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final delay = index * 0.1;
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final animationValue = CurveTween(curve: Curves.easeInOutSine)
                .transform((_controller.value - delay).clamp(0.0, 1.0));
            final yOffset = -20 * (animationValue * 2 - 1).abs();
            return Transform.translate(
                offset: Offset(0, yOffset),
                child: _Dot(
                    color: index == 1 || index == 4
                        ? Colors.blue
                        : index == 2
                            ? Colors.black87
                            : Colors.grey.shade300));
          },
        );
      }),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        width: 15,
        height: 15,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}
