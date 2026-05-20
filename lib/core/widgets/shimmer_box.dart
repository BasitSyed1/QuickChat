import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../constants/app_colors.dart';

class ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;

  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius,
      ),
    );
  }
}

class ShimmerArea extends StatelessWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;

  const ShimmerArea({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFFE9ECEF),
    this.highlightColor = const Color(0xFFF7F8FA),
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      period: const Duration(milliseconds: 1300),
      child: child,
    );
  }
}

class ChatRowShimmer extends StatelessWidget {
  const ChatRowShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Row(
          children: [
            const ShimmerBox(
              width: 52,
              height: 52,
              borderRadius: BorderRadius.all(Radius.circular(26)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(
                    width: MediaQuery.of(context).size.width * 0.35,
                    height: 14,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  const SizedBox(height: 8),
                  ShimmerBox(
                    width: MediaQuery.of(context).size.width * 0.55,
                    height: 12,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ShimmerBox(
              width: 36,
              height: 10,
              borderRadius: BorderRadius.circular(5),
            ),
          ],
        ),
      ),
    );
  }
}

class AvatarRailShimmer extends StatelessWidget {
  const AvatarRailShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: ShimmerArea(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 6,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          separatorBuilder: (_, _) => const SizedBox(width: 14),
          itemBuilder: (_, _) => const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShimmerBox(
                width: 56,
                height: 56,
                borderRadius: BorderRadius.all(Radius.circular(28)),
              ),
              SizedBox(height: 8),
              ShimmerBox(
                width: 44,
                height: 10,
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MessageBubbleShimmer extends StatelessWidget {
  final bool isOutgoing;
  final double widthFactor;

  const MessageBubbleShimmer({
    super.key,
    this.isOutgoing = false,
    this.widthFactor = 0.55,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
      child: Align(
        alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
        child: ShimmerArea(
          baseColor: isOutgoing
              ? AppColors.secondaryColor.withValues(alpha: 0.18)
              : const Color(0xFFE9ECEF),
          highlightColor: isOutgoing
              ? AppColors.secondaryColor.withValues(alpha: 0.32)
              : const Color(0xFFF7F8FA),
          child: ShimmerBox(
            width: MediaQuery.of(context).size.width * widthFactor,
            height: 40,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
