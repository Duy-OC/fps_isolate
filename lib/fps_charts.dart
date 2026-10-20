import 'dart:math';

import 'package:flutter/material.dart';

import 'fps_monitor.dart';

class FpsChartsPage extends StatelessWidget {
  const FpsChartsPage({
    super.key,
    required this.mainThread,
    required this.compute,
    required this.isolate,
  });

  final FrameStats? mainThread;
  final FrameStats? compute;
  final FrameStats? isolate;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Main Thread'),
              Tab(text: 'compute()'),
              Tab(text: 'Isolate'),
              Tab(text: 'Tổng quan'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _trialTab(
                  context,
                  'Main Thread',
                  mainThread,
                  Colors.deepOrange,
                ),
                _trialTab(context, 'compute()', compute, Colors.blue),
                _trialTab(context, 'Isolate', isolate, Colors.teal),
                _overviewTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _trialTab(
    BuildContext context,
    String title,
    FrameStats? stats,
    Color color,
  ) {
    if (stats == null) {
      return Center(child: Text('Chưa có dữ liệu FPS cho $title.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'FPS khi chạy $title',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                height: 280,
                child: CustomPaint(painter: _FpsLinePainter(stats, color)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Đỏ: bắt đầu chạy  •  Xanh: xử lý xong'),
          const Text(
            'Đường FPS gồm tối đa 2 giây trước và 2 giây sau khi xử lý.',
          ),
          const SizedBox(height: 18),
          Text('Ghi chú', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'FPS cao nhất khi xử lý: ${stats.highestFps.toStringAsFixed(1)}',
          ),
          Text(
            'FPS thấp nhất khi xử lý: ${stats.lowestFps.toStringAsFixed(1)}',
          ),
          Text(
            'FPS trung bình khi xử lý: ${stats.averageFps.toStringAsFixed(1)}',
          ),
          if (title == 'Main Thread' && stats.averageFps == 0)
            const Text(
              'Main Thread bị chặn trong lúc xử lý nên không có khung hình nào; '
              'FPS trước và sau tác vụ vẫn được vẽ trên biểu đồ.',
            ),
          Text(
            'Thời gian phản hồi tương tác: ${stats.responseTimeMs.toStringAsFixed(1)} ms',
          ),
          Text('Số lần khựng (> 50 ms): ${stats.longPauses}'),
          Text(
            'Tỉ lệ rớt khung hình: ${stats.droppedFramePercent.toStringAsFixed(1)}%',
          ),
          const SizedBox(height: 8),
          Text('Thời gian xử lý: ${stats.processingMs} ms'),
          const SizedBox(height: 8),
          const Text(
            'Các chỉ số FPS và rớt khung hình tính trong lúc xử lý, '
            'so với mốc 60 FPS. Thời gian phản hồi là lúc bắt đầu xử lý '
            'đến khung hình giao diện kế tiếp.',
          ),
        ],
      ),
    );
  }

  Widget _overviewTab(BuildContext context) {
    if (mainThread == null || compute == null || isolate == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Chạy đủ Main Thread, compute() và Isolate để xem biểu đồ so sánh.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final main = mainThread!;
    final worker = compute!;
    final port = isolate!;
    final metrics =
        <({String title, List<double> values, String unit, int decimals})>[
          (
            title: 'FPS trung bình',
            values: [main.averageFps, worker.averageFps, port.averageFps],
            unit: '',
            decimals: 1,
          ),
          (
            title: 'Số lần giật (> 50 ms)',
            values: [
              main.longPauses.toDouble(),
              worker.longPauses.toDouble(),
              port.longPauses.toDouble(),
            ],
            unit: ' lần',
            decimals: 0,
          ),
          (
            title: 'Tỉ lệ rớt khung hình',
            values: [
              main.droppedFramePercent,
              worker.droppedFramePercent,
              port.droppedFramePercent,
            ],
            unit: '%',
            decimals: 1,
          ),
        ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('So sánh FPS', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('So sánh lần chạy gần nhất của mỗi cách xử lý.'),
          const SizedBox(height: 12),
          for (final metric in metrics) ...[
            Text(metric.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      key: ValueKey('comparison-chart-${metric.title}'),
                      width: double.infinity,
                      height: 220,
                      child: CustomPaint(
                        painter: _ComparisonPainter(
                          metric.values,
                          metric.unit,
                          metric.decimals,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        for (var i = 0; i < 3; i++)
                          Text(
                            '${['Main Thread', 'compute()', 'Isolate'][i]}: '
                            '${metric.values[i].toStringAsFixed(metric.decimals)}${metric.unit}',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

void _drawLabel(
  Canvas canvas,
  String label,
  Offset position, {
  Color color = Colors.black54,
  double fontSize = 11,
  bool centered = false,
  bool rightAligned = false,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: label,
      style: TextStyle(color: color, fontSize: fontSize),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final x = centered
      ? position.dx - painter.width / 2
      : rightAligned
      ? position.dx - painter.width
      : position.dx;
  painter.paint(canvas, Offset(x, position.dy));
}

class _FpsLinePainter extends CustomPainter {
  const _FpsLinePainter(this.stats, this.color);

  final FrameStats stats;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final samples = stats.fpsSamples;
    final plot = Rect.fromLTWH(40, 14, size.width - 56, size.height - 48);
    if (plot.width <= 0 || plot.height <= 0 || samples.isEmpty) return;

    final minTime = min(-0.5, samples.first.secondsFromStart);
    final maxTime = max(stats.durationMs / 1000, 0.5);
    double xAt(double seconds) =>
        plot.left + (seconds - minTime) / (maxTime - minTime) * plot.width;
    final maxFps = max(
      60.0,
      (samples.map((sample) => sample.fps).reduce(max) / 20).ceil() * 20.0,
    );

    final gridPaint = Paint()..color = Colors.black12;
    for (var i = 0; i <= 4; i++) {
      final y = plot.bottom - i * plot.height / 4;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      _drawLabel(canvas, (maxFps * i / 4).toStringAsFixed(0), Offset(0, y - 7));
    }

    canvas.drawLine(
      Offset(xAt(0), plot.top),
      Offset(xAt(0), plot.bottom),
      Paint()..color = Colors.red,
    );
    final finishX = xAt(stats.processingMs / 1000);
    canvas.drawLine(
      Offset(finishX, plot.top),
      Offset(finishX, plot.bottom),
      Paint()..color = Colors.green,
    );

    final path = Path();
    for (var i = 0; i < samples.length; i++) {
      final point = samples[i];
      final x = xAt(point.secondsFromStart);
      final y = plot.bottom - point.fps / maxFps * plot.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    for (final point in samples) {
      canvas.drawCircle(
        Offset(
          xAt(point.secondsFromStart),
          plot.bottom - point.fps / maxFps * plot.height,
        ),
        2.2,
        Paint()..color = color,
      );
    }
    _drawLabel(
      canvas,
      '${minTime.toStringAsFixed(1)} s',
      Offset(plot.left, plot.bottom + 9),
    );
    _drawLabel(
      canvas,
      '${maxTime.toStringAsFixed(1)} s',
      Offset(plot.right, plot.bottom + 9),
      rightAligned: true,
    );
  }

  @override
  bool shouldRepaint(covariant _FpsLinePainter oldDelegate) =>
      oldDelegate.stats != stats || oldDelegate.color != color;
}

class _ComparisonPainter extends CustomPainter {
  const _ComparisonPainter(this.values, this.unit, this.decimals);

  final List<double> values;
  final String unit;
  final int decimals;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTWH(40, 22, size.width - 56, size.height - 65);
    if (plot.width <= 0 || plot.height <= 0) return;

    final maxValue = max(1.0, values.reduce(max) * 1.2);
    final gridPaint = Paint()..color = Colors.black12;
    for (var i = 0; i <= 4; i++) {
      final y = plot.bottom - i * plot.height / 4;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      _drawLabel(
        canvas,
        (maxValue * i / 4).toStringAsFixed(maxValue <= 5 ? 1 : 0),
        Offset(0, y - 7),
      );
    }

    const colors = [Colors.deepOrange, Colors.blue, Colors.teal];
    const labels = ['Main', 'compute', 'Isolate'];
    for (var i = 0; i < values.length; i++) {
      final centerX = plot.left + (i + 0.5) * plot.width / 3;
      final barWidth = min(48.0, plot.width / 6);
      final barHeight = values[i] / maxValue * plot.height;
      canvas.drawRect(
        Rect.fromLTWH(
          centerX - barWidth / 2,
          plot.bottom - barHeight,
          barWidth,
          barHeight,
        ),
        Paint()..color = colors[i],
      );
      _drawLabel(
        canvas,
        '${values[i].toStringAsFixed(decimals)}$unit',
        Offset(centerX, plot.bottom - barHeight - 18),
        centered: true,
      );
      _drawLabel(
        canvas,
        labels[i],
        Offset(centerX, plot.bottom + 10),
        centered: true,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ComparisonPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.unit != unit ||
      oldDelegate.decimals != decimals;
}
