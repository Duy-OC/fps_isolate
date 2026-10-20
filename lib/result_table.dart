import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

class ResultTable extends StatefulWidget {
  const ResultTable({super.key, required this.rawJson, required this.rowCount});

  final String rawJson;
  final int rowCount;

  @override
  State<ResultTable> createState() => _ResultTableState();
}

class _ResultTableState extends State<ResultTable> {
  late _UserDataSource _source;

  @override
  void initState() {
    super.initState();
    _source = _UserDataSource(widget.rawJson, widget.rowCount);
  }

  @override
  void didUpdateWidget(covariant ResultTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawJson != widget.rawJson ||
        oldWidget.rowCount != widget.rowCount) {
      _source.dispose();
      _source = _UserDataSource(widget.rawJson, widget.rowCount);
    }
  }

  @override
  void dispose() {
    _source.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: max(1000.0, constraints.maxWidth),
          child: PaginatedDataTable(
            header: Text('${widget.rowCount} ID trong data.json'),
            rowsPerPage: 10,
            availableRowsPerPage: const [10],
            showFirstLastButtons: true,
            columns: const [
              DataColumn(label: Text('ID')),
              DataColumn(label: Text('Tên')),
              DataColumn(label: Text('Email')),
              DataColumn(label: Text('Điểm')),
              DataColumn(label: Text('Tags')),
              DataColumn(label: Text('Thành phố')),
              DataColumn(label: Text('ZIP')),
            ],
            source: _source,
          ),
        ),
      ),
    );
  }
}

class _UserDataSource extends DataTableSource {
  _UserDataSource(this.rawJson, this.rowCount)
    : _recordStarts = [rawJson.indexOf('\n') + 1];

  final String rawJson;
  @override
  final int rowCount;
  final List<int> _recordStarts;

  @override
  bool get isRowCountApproximate => false;

  @override
  int get selectedRowCount => 0;

  @override
  DataRow? getRow(int index) {
    if (index < 0 || index >= rowCount) return null;

    while (_recordStarts.length <= index) {
      final nextLine = rawJson.indexOf('\n', _recordStarts.last);
      if (nextLine < 0) return null;
      _recordStarts.add(nextLine + 1);
    }

    final start = _recordStarts[index];
    final end = rawJson.indexOf('\n', start);
    var line = rawJson.substring(start, end < 0 ? rawJson.length : end).trim();
    if (line.endsWith(',')) line = line.substring(0, line.length - 1);
    final user = jsonDecode(line) as Map<String, dynamic>;
    final address = user['address'] as Map<String, dynamic>;
    final tags = user['tags'] as List<dynamic>;

    return DataRow.byIndex(
      index: index,
      cells: [
        DataCell(Text('${user['id']}')),
        DataCell(Text('${user['name']}')),
        DataCell(Text('${user['email']}')),
        DataCell(Text((user['score'] as num).toStringAsFixed(2))),
        DataCell(Text(tags.join(', '))),
        DataCell(Text('${address['city']}')),
        DataCell(Text('${address['zip']}')),
      ],
    );
  }
}
