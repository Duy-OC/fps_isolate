import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'fps_charts.dart';
import 'fps_monitor.dart';
import 'parsefile.dart';
import 'runmodes.dart';

enum _RunMode { mainThread, compute, isolate }

enum _Page { home, fpsCharts }

enum _ProcessingStatus { idle, running, completed, failed }

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final FpsMonitor _fpsMonitor = FpsMonitor();

  String? _rawJson;
  String? _errorMessage;
  _ProcessingStatus _status = _ProcessingStatus.idle;
  bool _busy = false;
  _Page _page = _Page.home;
  final Map<_RunMode, FrameStats> _trials = {};

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _animation.addListener(_fpsMonitor.onFrame);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final raw = await rootBundle.loadString('assets/data.json');
      if (!mounted) return;

      setState(() {
        _rawJson = raw;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Không đọc được assets/data.json:\n$error';
      });
    }
  }

  Future<void> _showRunOptions() async {
    if (_rawJson == null || _busy) return;

    final mode = await showModalBottomSheet<_RunMode>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Main Thread'),
              onTap: () => Navigator.pop(context, _RunMode.mainThread),
            ),
            ListTile(
              title: const Text('compute()'),
              onTap: () => Navigator.pop(context, _RunMode.compute),
            ),
            ListTile(
              title: const Text('Isolate + Ports'),
              onTap: () => Navigator.pop(context, _RunMode.isolate),
            ),
          ],
        ),
      ),
    );

    if (mode != null && mounted) {
      await _runTest(mode);
    }
  }

  Future<void> _runTest(_RunMode mode) async {
    final raw = _rawJson;
    if (raw == null || _busy) return;

    setState(() {
      _busy = true;
      _status = _ProcessingStatus.running;
      _errorMessage = null;
    });

    // Hiển thị trạng thái trước khi Main Thread bắt đầu xử lý JSON.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    _fpsMonitor.beginTrial();
    final responseClock = Stopwatch()..start();
    final response = Completer<double>();
    WidgetsBinding.instance.scheduleFrameCallback((_) {
      if (!response.isCompleted) {
        response.complete(responseClock.elapsedMicroseconds / 1000);
      }
    });
    try {
      final ProcessResult result = switch (mode) {
        _RunMode.mainThread => runOnMain(raw),
        _RunMode.compute => await runWithCompute(raw),
        _RunMode.isolate => await runWithPorts(raw),
      };

      if (result['userCount'] == null) {
        throw StateError('File JSON không có số lượng bản ghi.');
      }

      _fpsMonitor.markProcessingComplete();
      if (mounted) setState(() => _status = _ProcessingStatus.completed);
      await Future<void>.delayed(const Duration(seconds: 2));
      final responseTimeMs = await response.future.timeout(
        const Duration(milliseconds: 300),
        onTimeout: () => responseClock.elapsedMicroseconds / 1000,
      );
      final stats = _fpsMonitor.endTrial(responseTimeMs: responseTimeMs);

      if (!mounted) return;
      setState(() {
        _busy = false;
        _trials[mode] = stats;
      });
    } catch (error) {
      _fpsMonitor.cancelTrial();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = _ProcessingStatus.failed;
        _errorMessage = 'Xử lý thất bại:\n$error';
      });
    }
  }

  @override
  void dispose() {
    _animation.removeListener(_fpsMonitor.onFrame);
    _animation.dispose();
    _fpsMonitor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_page) {
      _Page.home => 'Màn hình chính',
      _Page.fpsCharts => 'Biểu đồ FPS',
    };

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              const DrawerHeader(child: Text('Main Thread và Isolate')),
              ListTile(
                leading: const Icon(Icons.home_outlined),
                title: const Text('Màn hình chính'),
                selected: _page == _Page.home,
                onTap: () => _selectPage(_Page.home),
              ),
              ListTile(
                leading: const Icon(Icons.show_chart),
                title: const Text('Biểu đồ FPS'),
                selected: _page == _Page.fpsCharts,
                onTap: () => _selectPage(_Page.fpsCharts),
              ),
            ],
          ),
        ),
      ),
      body: switch (_page) {
        _Page.home => _buildHome(context),
        _Page.fpsCharts => FpsChartsPage(
          mainThread: _trials[_RunMode.mainThread],
          compute: _trials[_RunMode.compute],
          isolate: _trials[_RunMode.isolate],
        ),
      },
    );
  }

  void _selectPage(_Page page) {
    Navigator.pop(context);
    setState(() => _page = page);
  }

  Widget _buildHome(BuildContext context) {
    final ready = _rawJson != null && !_busy;
    final imageSize = min(MediaQuery.sizeOf(context).width - 40, 280.0);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Quan sát hoạt ảnh khi xử lý JSON:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            Center(
              child: Image.asset(
                'assets/qiqi.gif',
                width: imageSize,
                height: imageSize,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => SizedBox(
                  width: imageSize,
                  height: imageSize,
                  child: const Center(
                    child: Text(
                      'Không tải được GIF',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<double>(
              valueListenable: _fpsMonitor.liveFps,
              builder: (context, fps, child) => Text(
                'FPS hiện tại: ${fps.toStringAsFixed(1)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 25),
            ElevatedButton(
              onPressed: ready ? _showRunOptions : null,
              child: const Text('Run'),
            ),
            const SizedBox(height: 25),
            const Text(
              'Xử lý file',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text('data.json', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStatusBar(context),
                    if (_rawJson == null && _errorMessage == null) ...[
                      const SizedBox(height: 12),
                      const Text('Đang tải file...'),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar(BuildContext context) {
    const labels = ['Chưa xử lý', 'Đang xử lý', 'Đã xử lý'];
    final activeIndex = switch (_status) {
      _ProcessingStatus.idle => 0,
      _ProcessingStatus.running => 1,
      _ProcessingStatus.completed => 2,
      _ProcessingStatus.failed => -1,
    };
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 8),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 8,
                    decoration: BoxDecoration(
                      color: i <= activeIndex
                          ? colors.primary
                          : colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: i == activeIndex
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: i == activeIndex
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
