/// A reusable horizontal split-pane widget with a draggable divider.
///
/// Lays out [leftChild] and [rightChild] side-by-side. The divider can be
/// dragged horizontally to resize the panels. The current ratio is reported
/// via [onRatioChanged] when the drag ends (not during, to avoid excessive
/// I/O on the persistence layer).
///
/// Usage:
/// ```dart
/// SplitPane(
///   ratio: 0.4,
///   onRatioChanged: (r) => ref.read(splitPaneRatioProvider.notifier).setRatio(r),
///   leftChild: const MasterList(),
///   rightChild: const DetailPanel(),
/// )
/// ```
library;

import 'package:flutter/material.dart';

/// Default visual properties.
const _kDividerHitArea = 12.0;
const _kDividerThickness = 1.0;

/// A horizontal two-panel layout with a draggable divider.
///
/// [ratio] is the fraction of total width allocated to the left panel
/// (0.0–1.0). It is clamped to 0.2–0.8 internally.
class SplitPane extends StatefulWidget {
  /// Fraction of width for the left panel (0.2–0.8, default 0.4).
  final double ratio;

  /// Called once when the user finishes a drag, with the new ratio.
  final ValueChanged<double>? onRatioChanged;

  /// The left (master) panel.
  final Widget leftChild;

  /// The right (detail) panel.
  final Widget rightChild;

  const SplitPane({
    required this.leftChild,
    required this.rightChild,
    this.ratio = 0.4,
    this.onRatioChanged,
    super.key,
  });

  @override
  State<SplitPane> createState() => _SplitPaneState();
}

class _SplitPaneState extends State<SplitPane> {
  late double _ratio;
  bool _isHovering = false;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _ratio = widget.ratio.clamp(0.3, 0.5);
  }

  @override
  void didUpdateWidget(SplitPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ratio != widget.ratio) {
      _ratio = widget.ratio.clamp(0.3, 0.5);
    }
  }

  Color _dividerColor(ColorScheme cs) {
    if (_isDragging) return cs.primary;
    if (_isHovering) return cs.outline;
    return cs.outlineVariant.withAlpha(40);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final leftWidth = totalWidth * _ratio;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left panel.
            SizedBox(width: leftWidth, child: widget.leftChild),
            // Draggable divider.
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              onEnter: (_) => setState(() => _isHovering = true),
              onExit: (_) => setState(() => _isHovering = false),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragDown: (_) =>
                    setState(() => _isDragging = true),
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _ratio = (_ratio + details.delta.dx / totalWidth).clamp(
                      0.3,
                      0.5,
                    );
                  });
                },
                onHorizontalDragEnd: (_) {
                  setState(() => _isDragging = false);
                  widget.onRatioChanged?.call(_ratio);
                },
                onHorizontalDragCancel: () =>
                    setState(() => _isDragging = false),
                // Wider hit area around the thin visual line.
                child: SizedBox(
                  width: _kDividerHitArea,
                  child: Center(
                    child: VerticalDivider(
                      width: _kDividerThickness,
                      thickness: _kDividerThickness,
                      color: _dividerColor(colorScheme),
                    ),
                  ),
                ),
              ),
            ),
            // Right panel.
            Expanded(child: widget.rightChild),
          ],
        );
      },
    );
  }
}
