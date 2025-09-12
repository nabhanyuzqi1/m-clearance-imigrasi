import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart' as shimmer;
import '../../config/theme.dart';

// Shared animation controller to reduce memory usage and improve performance
class ShimmerAnimationController {
  static AnimationController? _controller;
  static Animation<double>? _animation;
  static int _usageCount = 0;

  static Animation<double> getAnimation(TickerProvider vsync) {
    _usageCount++;
    if (_controller == null) {
      _controller = AnimationController(
        duration: const Duration(milliseconds: 1500),
        vsync: vsync,
      )..repeat();

      _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _controller!, curve: Curves.easeInOut),
      );
    }
    return _animation!;
  }

  static void releaseAnimation() {
    _usageCount--;
    if (_usageCount <= 0) {
      _controller?.stop();
    }
  }

  static void resumeAnimation() {
    if (_usageCount > 0 && _controller != null && !_controller!.isAnimating) {
      _controller!.repeat();
    }
  }

  static void dispose() {
    _controller?.dispose();
    _controller = null;
    _animation = null;
    _usageCount = 0;
  }
}

class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    ShimmerAnimationController.getAnimation(this);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ShimmerAnimationController.releaseAnimation();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      ShimmerAnimationController.releaseAnimation();
      _isVisible = false;
    } else if (state == AppLifecycleState.resumed) {
      ShimmerAnimationController.resumeAnimation();
      _isVisible = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: _isVisible,
      maintainState: true,
      maintainAnimation: true,
      maintainSize: true,
      child: shimmer.Shimmer.fromColors(
        baseColor: AppTheme.greyShade300,
        highlightColor: AppTheme.greyShade100,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: AppTheme.greyShade300,
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

class SkeletonListLoader extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final EdgeInsetsGeometry? padding;

  const SkeletonListLoader({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 60,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = padding ?? EdgeInsets.symmetric(horizontal: screenWidth * 0.04);

    return shimmer.Shimmer.fromColors(
      baseColor: AppTheme.greyShade300,
      highlightColor: AppTheme.greyShade100,
      child: ListView.builder(
        shrinkWrap: true,
        padding: horizontalPadding,
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: itemHeight,
                  height: itemHeight,
                  decoration: BoxDecoration(
                    color: AppTheme.greyShade300,
                    borderRadius: BorderRadius.circular(itemHeight / 2),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: itemHeight * 0.4,
                        decoration: BoxDecoration(
                          color: AppTheme.greyShade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: screenWidth * 0.6,
                        height: itemHeight * 0.3,
                        decoration: BoxDecoration(
                          color: AppTheme.greyShade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}