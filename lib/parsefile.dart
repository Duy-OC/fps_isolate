import 'dart:convert';

typedef ProcessResult = Map<String, num>;

// data.json được tạo với một bản ghi JSON trên mỗi dòng.
int countJsonRows(String rawJson) {
  var count = 0;
  var position = rawJson.indexOf('\n{');
  while (position >= 0) {
    count++;
    position = rawJson.indexOf('\n{', position + 2);
  }
  return count;
}

ProcessResult processLargeJson(String rawJson) {
  // Phần nặng nhất: chuyển chuỗi JSON thành các đối tượng Dart.
  final users = jsonDecode(rawJson) as List<dynamic>;

  double totalScore = 0;
  int daNangCount = 0;
  int tagCount = 0;

  for (final element in users) {
    final user = element as Map<String, dynamic>;

    totalScore += (user['score'] as num).toDouble();

    final address = user['address'] as Map<String, dynamic>;
    if (address['city'] == 'Da Nang') {
      daNangCount++;
    }

    final tags = user['tags'] as List<dynamic>;
    tagCount += tags.length;
  }

  return {
    'userCount': users.length,
    'averageScore': users.isEmpty ? 0 : totalScore / users.length,
    'daNangCount': daNangCount,
    'tagCount': tagCount,
  };
}
