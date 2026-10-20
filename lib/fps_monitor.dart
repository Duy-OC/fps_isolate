import 'dart:math';

import 'package:flutter/foundation.dart';

const fpsSampleWindowUs = 250000;

class FpsSample {
  const FpsSample(this.secondsFromStart, this.fps);

  final double secondsFromStart;
  final double fps;
}

class FrameStats {
  const FrameStats({
    required this.fpsSamples,
    required this.highestFps,
    required this.lowestFps,
    required this.averageFps,
    required this.responseTimeMs,
    required this.longPauses,
    required this.droppedFramePercent,
    required this.processingMs,
    required this.durationMs,
  });

  final List<FpsSample> fpsSamples;
  final double highestFps;
  final double lowestFps;
  final double averageFps;
  final double responseTimeMs;
  final int longPauses;
  final double droppedFramePercent;
  final int processingMs;
  final int durationMs;
}

FrameStats buildFrameStats({
  required List<int> frameTimesUs,
  required List<FpsSample> baselineSamples,
  required int processingUs,
  required int totalUs,
  required double responseTimeMs,
}) {
  final processing = max(1, processingUs);
  final total = max(processing, totalUs);
  // Tách các ô tại thời điểm xử lý xong để frame hồi phục không bị vẽ
  // ngược vào khoảng thời gian Main Thread còn đang bị chặn.
  final processingBucketCount = processing ~/ fpsSampleWindowUs;
  final recoveryBucketCount = (total - processing) ~/ fpsSampleWindowUs;
  final processingCounts = List<int>.filled(processingBucketCount, 0);
  final recoveryCounts = List<int>.filled(recoveryBucketCount, 0);
  var processingFrames = 0;

  for (final timeUs in frameTimesUs) {
    if (timeUs >= 0 && timeUs < processing) {
      processingFrames++;
      final bucket = timeUs ~/ fpsSampleWindowUs;
      if (bucket < processingBucketCount) processingCounts[bucket]++;
    } else if (timeUs >= processing) {
      final bucket = (timeUs - processing) ~/ fpsSampleWindowUs;
      if (bucket < recoveryBucketCount) recoveryCounts[bucket]++;
    }
  }

  final averageFps = processingFrames * 1000000 / processing;
  final processingFps = processingBucketCount == 0
      ? [averageFps]
      : [
          for (final count in processingCounts)
            count * 1000000 / fpsSampleWindowUs,
        ];
  final firstProcessingFps = processingFps.first;
  final lastProcessingFps = processingFps.last;
  final samples = <FpsSample>[
    ...baselineSamples,
    if (baselineSamples.isNotEmpty) FpsSample(0, baselineSamples.last.fps),
    FpsSample(0, firstProcessingFps),
    for (var bucket = 0; bucket < processingBucketCount; bucket++)
      FpsSample(
        (bucket + 0.5) * fpsSampleWindowUs / 1000000,
        processingCounts[bucket] * 1000000 / fpsSampleWindowUs,
      ),
    FpsSample(processing / 1000000, lastProcessingFps),
    for (var bucket = 0; bucket < recoveryBucketCount; bucket++)
      FpsSample(
        (processing + (bucket + 0.5) * fpsSampleWindowUs) / 1000000,
        recoveryCounts[bucket] * 1000000 / fpsSampleWindowUs,
      ),
  ];

  var longPauses = 0;
  var previousFrameUs = 0;
  var sawRecoveryFrame = false;
  for (final timeUs in frameTimesUs) {
    if (timeUs - previousFrameUs > 50000) longPauses++;
    previousFrameUs = timeUs;
    if (timeUs > processing) {
      sawRecoveryFrame = true;
      break;
    }
  }
  if (!sawRecoveryFrame && total - previousFrameUs > 50000) longPauses++;

  // Ước lượng khung hình bị thiếu so với mốc 60 FPS trong lúc xử lý.
  final expectedFrames = processing * 60 / 1000000;
  final droppedFramePercent = expectedFrames < 1
      ? 0.0
      : ((expectedFrames - processingFrames) / expectedFrames * 100).clamp(
          0.0,
          100.0,
        );

  return FrameStats(
    fpsSamples: samples,
    highestFps: processingFps.reduce(max),
    lowestFps: processingFps.reduce(min),
    averageFps: averageFps,
    responseTimeMs: responseTimeMs,
    longPauses: longPauses,
    droppedFramePercent: droppedFramePercent,
    processingMs: processing ~/ 1000,
    durationMs: total ~/ 1000,
  );
}

class _TimedFps {
  const _TimedFps(this.timeUs, this.fps);

  final int timeUs;
  final double fps;
}

class FpsMonitor {
  final ValueNotifier<double> liveFps = ValueNotifier<double>(0);
  final Stopwatch _clock = Stopwatch()..start();
  final List<_TimedFps> _recentFps = [];
  final List<int> _trialFrameTimesUs = [];

  int _liveWindowStartUs = 0;
  int _liveFrames = 0;
  int _trialStartUs = 0;
  int? _processingEndUs;
  List<FpsSample> _baselineSamples = [];
  bool _measuring = false;

  void onFrame() {
    final nowUs = _clock.elapsedMicroseconds;
    _liveFrames++;
    final liveElapsedUs = nowUs - _liveWindowStartUs;
    if (liveElapsedUs >= fpsSampleWindowUs) {
      final fps = _liveFrames * 1000000 / liveElapsedUs;
      liveFps.value = fps;
      _recentFps.add(_TimedFps(nowUs, fps));
      _recentFps.removeWhere((sample) => nowUs - sample.timeUs > 3000000);
      _liveFrames = 0;
      _liveWindowStartUs = nowUs;
    }

    if (_measuring) {
      _trialFrameTimesUs.add(nowUs - _trialStartUs);
    }
  }

  void beginTrial() {
    final nowUs = _clock.elapsedMicroseconds;
    _baselineSamples = [
      for (final sample in _recentFps)
        if (nowUs - sample.timeUs <= 2000000)
          FpsSample((sample.timeUs - nowUs) / 1000000, sample.fps),
    ];
    _trialStartUs = nowUs;
    _processingEndUs = null;
    _trialFrameTimesUs.clear();
    _measuring = true;
  }

  void markProcessingComplete() {
    _processingEndUs = max(1, _clock.elapsedMicroseconds - _trialStartUs);
  }

  FrameStats endTrial({required double responseTimeMs}) {
    final totalUs = max(1, _clock.elapsedMicroseconds - _trialStartUs);
    _measuring = false;
    return buildFrameStats(
      frameTimesUs: _trialFrameTimesUs,
      baselineSamples: _baselineSamples,
      processingUs: _processingEndUs ?? totalUs,
      totalUs: totalUs,
      responseTimeMs: responseTimeMs,
    );
  }

  void cancelTrial() {
    _measuring = false;
  }

  void dispose() {
    _clock.stop();
    liveFps.dispose();
  }
}
