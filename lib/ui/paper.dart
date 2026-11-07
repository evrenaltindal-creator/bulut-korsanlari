import 'package:flutter/material.dart';

import 'theme.dart';

/// A cream logbook page with a soft edge.
class PaperCard extends StatelessWidget {
  const PaperCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.paperEdge, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: AppColors.ink, height: 1.4),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A labelled 0..1 skill bar drawn in ink.
class InkMeter extends StatelessWidget {
  const InkMeter({super.key, required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value.clamp(0, 1),
                minHeight: 8,
                backgroundColor: const Color(0x22000000),
                color: const Color(0xFF2A7C7E),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${(value * 100).round()}',
            style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}
