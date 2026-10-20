import 'package:flutter_test/flutter_test.dart';
import 'package:multithread_isolate/fps_monitor.dart';

void main() {
  test('Giữ FPS trước khi chạy và ghi khoảng rơi về 0 khi UI bị chặn', () {
    final stats = buildFrameStats(
      baselineSamples: const [FpsSample(-0.5, 60), FpsSample(-0.25, 60)],
      frameTimesUs: const [700000, 716667, 733334],
      processingUs: 600000,
      totalUs: 1000000,
      responseTimeMs: 700,
    );

    expect(stats.fpsSamples.first.secondsFromStart, lessThan(0));
    expect(stats.fpsSamples[2].fps, 0);
    expect(stats.fpsSamples[3].fps, 0);
    expect(stats.averageFps, 0);
    expect(stats.lowestFps, 0);
    expect(stats.longPauses, 1);
    expect(stats.droppedFramePercent, 100);
    expect(stats.responseTimeMs, 700);
  });

  test('Không tính rớt khung hình khi đủ 60 khung/giây', () {
    final stats = buildFrameStats(
      baselineSamples: const [],
      frameTimesUs: List.generate(45, (index) => (index + 1) * 16666),
      processingUs: 500000,
      totalUs: 750000,
      responseTimeMs: 16.7,
    );

    expect(stats.averageFps, closeTo(60, 1));
    expect(stats.droppedFramePercent, closeTo(0, 1));
    expect(stats.longPauses, 0);
  });

  test('Cửa sổ cuối ngắn không tạo đỉnh FPS giả', () {
    final stats = buildFrameStats(
      baselineSamples: const [],
      frameTimesUs: const [260000, 510000],
      processingUs: 260000,
      totalUs: 520000,
      responseTimeMs: 260,
    );

    expect(
      stats.fpsSamples
          .map((sample) => sample.fps)
          .reduce((a, b) => a > b ? a : b),
      4,
    );
    expect(stats.highestFps, 0);
  });
}
