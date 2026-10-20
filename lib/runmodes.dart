import 'dart:isolate';

import 'package:flutter/foundation.dart';

import 'parsefile.dart';

// A. Chạy trực tiếp trên main isolate: giao diện sẽ bị chặn.
ProcessResult runOnMain(String rawJson) {
  return processLargeJson(rawJson);
}

// B. Flutter tạo isolate giúp ta bằng compute().
Future<ProcessResult> runWithCompute(String rawJson) {
  return compute(processLargeJson, rawJson);
}

// C. Tự tạo isolate và nhận kết quả qua ReceivePort.
Future<ProcessResult> runWithPorts(String rawJson) async {
  final receivePort = ReceivePort();

  try {
    await Isolate.spawn<List<dynamic>>(_workerEntry, [
      receivePort.sendPort,
      rawJson,
    ], onError: receivePort.sendPort);

    final message = await receivePort.first;

    if (message is Map) {
      return Map<String, num>.from(message);
    }

    if (message is List && message.isNotEmpty) {
      throw StateError('Isolate bị lỗi: ${message.first}');
    }

    throw StateError('Isolate không trả về kết quả hợp lệ.');
  } finally {
    receivePort.close();
  }
}

// Hàm bắt đầu chạy bên trong isolate mới.
void _workerEntry(List<dynamic> arguments) {
  final sendPort = arguments[0] as SendPort;
  final rawJson = arguments[1] as String;

  final result = processLargeJson(rawJson);

  // Gửi kết quả nhỏ về main isolate và kết thúc worker.
  Isolate.exit(sendPort, result);
}
