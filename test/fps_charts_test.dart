import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multithread_isolate/fps_charts.dart';
import 'package:multithread_isolate/fps_monitor.dart';

FrameStats trial(double averageFps) => FrameStats(
  fpsSamples: [
    const FpsSample(-0.25, 60),
    FpsSample(0.125, averageFps),
    const FpsSample(1.5, 60),
  ],
  highestFps: averageFps,
  lowestFps: averageFps,
  averageFps: averageFps,
  responseTimeMs: 16,
  longPauses: 0,
  droppedFramePercent: 0,
  processingMs: 500,
  durationMs: 3000,
);

Future<void> showCharts(
  WidgetTester tester, {
  FrameStats? mainThread,
  FrameStats? compute,
  FrameStats? isolate,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: FpsChartsPage(
          mainThread: mainThread,
          compute: compute,
          isolate: isolate,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Chỉ hiện số liệu của cách chạy đã hoàn tất', (tester) async {
    await showCharts(tester);
    expect(find.text('Chưa có dữ liệu FPS cho Main Thread.'), findsOneWidget);

    await showCharts(tester, mainThread: trial(32));
    expect(find.text('FPS trung bình: 32.0'), findsOneWidget);

    await tester.tap(find.text('compute()'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có dữ liệu FPS cho compute().'), findsOneWidget);

    await tester.tap(find.text('Tổng quan'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chạy đủ Main Thread'), findsOneWidget);
  });

  testWidgets('Tổng quan xuất hiện sau khi có đủ ba lần chạy', (tester) async {
    await showCharts(
      tester,
      mainThread: trial(28),
      compute: trial(58),
      isolate: trial(59),
    );

    await tester.tap(find.text('Tổng quan'));
    await tester.pumpAndSettle();
    expect(find.text('So sánh FPS'), findsOneWidget);
    final chart = find.byKey(const ValueKey('comparison-chart-FPS trung bình'));
    expect(tester.getSize(chart).width, greaterThan(100));
    expect(tester.getSize(chart).height, 220);
    expect(find.textContaining('Chạy đủ Main Thread'), findsNothing);
    expect(find.text('FPS trung bình'), findsOneWidget);
    expect(find.text('Số lần giật (> 50 ms)'), findsOneWidget);
    expect(find.text('Tỉ lệ rớt khung hình'), findsOneWidget);
    expect(find.text('Thời gian phản hồi tương tác'), findsNothing);
  });
}
