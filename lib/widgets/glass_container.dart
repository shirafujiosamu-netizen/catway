import 'dart:ui';
import 'package:flutter/material.dart';

/// 毛玻璃面板容器 — 背景模糊 + 半透明填充 + 细高光描边。
///
/// 由共享组件统一提供：底图（地图 / 图片 / 列表）会透过面板，
/// 文字仍走主题的深色 foreground，保证对比度。
/// [tintColor] 可覆盖默认填充色；[blurSigma] 控制背景模糊强度。
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final BorderRadius? customRadius;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? width;
  final double? height;
  final Color? tintColor;
  final double blurSigma;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 12,
    this.customRadius,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.tintColor,
    this.blurSigma = 18,
  });

  @override
  Widget build(BuildContext context) {
    final radius = customRadius ?? BorderRadius.circular(borderRadius);
    final bgColor = tintColor ?? Colors.white.withOpacity(0.72);

    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: radius,
              border: Border.all(
                color: Colors.white.withOpacity(0.55),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 毛玻璃底部弹窗
class GlassBottomSheet extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blurSigma;

  const GlassBottomSheet({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.blurSigma = 20,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.vertical(top: Radius.circular(borderRadius));

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.78),
            borderRadius: radius,
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.7),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB8860B).withOpacity(0.65),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// 毛玻璃顶栏背景 — 用作 AppBar 的 flexibleSpace
class GlassAppBarBackground extends StatelessWidget {
  final double blurSigma;

  const GlassAppBarBackground({super.key, this.blurSigma = 16});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.68),
            border: const Border(
              bottom: BorderSide(color: Color(0x26FFFFFF), width: 1),
            ),
          ),
        ),
      ),
    );
  }
}
