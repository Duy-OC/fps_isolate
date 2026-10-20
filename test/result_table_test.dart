import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multithread_isolate/parsefile.dart';
import 'package:multithread_isolate/result_table.dart';

void main() {
  testWidgets('Mỗi ID nằm trên một hàng và dữ liệu nằm trong các cột', (
    tester,
  ) async {
    final users = [
      {
        'id': 0,
        'name': 'User 0',
        'email': 'user0@example.com',
        'score': 82.5,
        'tags': ['a', 'b'],
        'address': {'city': 'Da Nang', 'zip': 12345},
      },
      {
        'id': 1,
        'name': 'User 1',
        'email': 'user1@example.com',
        'score': 91.0,
        'tags': ['c'],
        'address': {'city': 'Hue', 'zip': 54321},
      },
    ];
    final rawJson = '[\n${users.map(jsonEncode).join(',\n')}\n]';
    expect(countJsonRows(rawJson), users.length);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ResultTable(rawJson: rawJson, rowCount: users.length),
          ),
        ),
      ),
    );

    expect(find.text('ID'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('User 0'), findsOneWidget);
    expect(find.text('user1@example.com'), findsOneWidget);
    expect(find.text('82.50'), findsOneWidget);
    expect(find.text('Da Nang'), findsOneWidget);
  });

  testWidgets('Chuyển trang vẫn đọc đúng ID ở phần sau của file', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final users = List.generate(
      12,
      (id) => {
        'id': id,
        'name': 'User $id',
        'email': 'user$id@example.com',
        'score': 80,
        'tags': ['a'],
        'address': {'city': 'Da Nang', 'zip': 12345},
      },
    );
    final rawJson = '[\n${users.map(jsonEncode).join(',\n')}\n]';
    expect(countJsonRows(rawJson), users.length);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ResultTable(rawJson: rawJson, rowCount: users.length),
          ),
        ),
      ),
    );

    expect(find.text('User 0'), findsOneWidget);
    await tester.tap(find.byTooltip('Next page'));
    await tester.pump();
    expect(find.text('User 10'), findsOneWidget);
    expect(find.text('User 0'), findsNothing);
  });
}
