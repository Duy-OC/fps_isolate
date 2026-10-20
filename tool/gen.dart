import 'dart:convert';
import 'dart:io';
import 'dart:math';

void main() {
  final random = Random();

  final items = List.generate(
    120000,
    (i) => {
      'id': i,
      'name': 'User $i',
      'email': 'user$i@example.com',
      'score': random.nextDouble() * 100,
      'tags': ['a', 'b', 'c'],
      'address': {'city': 'Da Nang', 'zip': 10000 + random.nextInt(90000)},
    },
  );

  Directory('assets').createSync(recursive: true);

  final file = File('assets/data.json');

  // Dấu [ và ] bao quanh danh sách.
  // Mỗi bản ghi được ngăn cách bằng dấu phẩy và ký tự xuống dòng.
  file.writeAsStringSync('[\n${items.map(jsonEncode).join(',\n')}\n]');

  final sizeMb = file.lengthSync() / (1024 * 1024);
  print('Đã tạo assets/data.json: ${sizeMb.toStringAsFixed(2)} MB');
}
