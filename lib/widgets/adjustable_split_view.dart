import 'package:flutter/material.dart';

class AdjustableSplitView extends StatefulWidget {
  final Widget left;
  final Widget right;
  final double initialLeftWidthPercentage;

  const AdjustableSplitView({
    super.key,
    required this.left,
    required this.right,
    this.initialLeftWidthPercentage = 0.35,
  });

  @override
  State<AdjustableSplitView> createState() => _AdjustableSplitViewState();
}

class _AdjustableSplitViewState extends State<AdjustableSplitView> {
  late double _leftWidthPercentage;

  @override
  void initState() {
    super.initState();
    _leftWidthPercentage = widget.initialLeftWidthPercentage;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final leftWidth = totalWidth * _leftWidthPercentage;

        return Row(
          children: [
            SizedBox(width: leftWidth, child: widget.left),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (details) {
                setState(() {
                  double newPercentage =
                      _leftWidthPercentage + (details.delta.dx / totalWidth);
                  _leftWidthPercentage = newPercentage.clamp(0.2, 0.8);
                });
              },
              child: Container(
                width: 8,
                color: Colors.transparent,
                child: Center(
                  child: Container(
                    width: 2,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: widget.right),
          ],
        );
      },
    );
  }
}
