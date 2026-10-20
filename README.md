# FPS Isolate Benchmark (Flutter) 🚀

Ứng dụng Flutter đo lường, giám sát và trực quan hóa hiệu năng FPS (Frames Per Second) khi xử lý tác vụ CPU-bound nặng (phân tích cú pháp tệp JSON dung lượng lớn ~18.5 MB với 120.000 bản ghi) giữa **Main Thread (UI Thread)** và **Đa luồng (Background Isolate với `compute()` & `Isolate.spawn`)**.

---

## 1. Chạy thử nhanh

- **Tải [app-release.apk](app-release.apk)** ở ngay thư mục gốc của repository (bên cạnh file `README.md`).
- **Cài đặt vào điện thoại Android**: Cho phép cài đặt ứng dụng từ nguồn ngoài (nếu hệ thống hiển thị cảnh báo bảo mật).
- **Trải nghiệm trực tiếp trên app**:
  1. Mở ứng dụng: Quan sát hoạt ảnh GIF Qiqi đang chạy mượt mà trên **Màn hình chính** cùng chỉ số `FPS hiện tại: ~60 FPS`. Tệp dữ liệu `data.json` (~18.5 MB) đã được tích hợp sẵn trong ứng dụng.
  2. Bấm nút **Run** $\rightarrow$ Chọn một trong ba chế độ xử lý trong menu:
     - **Main Thread**: Thao tác parse JSON chạy trực tiếp trên UI thread $\rightarrow$ Hoạt ảnh Qiqi bị đóng băng (freeze) hoàn toàn trong suốt quá trình xử lý; FPS rơi thẳng về 0.
     - **compute()**: Tác vụ được chuyển sang Isolate ngầm do Flutter quản lý $\rightarrow$ Hoạt ảnh Qiqi chạy mượt mà liên tục, không hề bị gián đoạn.
     - **Isolate + Ports**: Tác vụ được thực thi trên Isolate riêng với `Isolate.spawn` và nhận kết quả qua `ReceivePort` / `Isolate.exit` $\rightarrow$ Giao diện giữ vững độ mượt ~60 FPS.
  3. Mở menu **Drawer** (góc trên bên trái) $\rightarrow$ Chọn **Biểu đồ FPS** để xem chi tiết biểu đồ đường FPS của từng chế độ và tab **Tổng quan** so sánh đối chiếu dạng cột.
- **Không cần cài đặt thêm**: Bản APK universal (~50 MB, chạy trên mọi kiến trúc CPU Android: ARM64, ARMv7, x86_64) được build trực tiếp từ mã nguồn trong repo và ký bằng debug key để tiện thử nghiệm.

---

## 2. Ảnh demo thực tế từ ứng dụng

Dưới đây là ảnh chụp màn hình thực tế được ghi nhận khi chạy ứng dụng trên thiết bị Android:

| 1. Màn hình chính (UI & Animation) | 2. Biểu đồ chi tiết tab `compute()` | 3. Tab Tổng quan (So sánh đối chiếu) |
| :---: | :---: | :---: |
| <img src="demo/home_screen.jpg" width="260" alt="Màn hình chính" /> | <img src="demo/compute_chart.jpg" width="260" alt="Biểu đồ compute()" /> | <img src="demo/overview_comparison.jpg" width="260" alt="So sánh tổng quan" /> |
| *Hoạt ảnh Qiqi chạy mượt mà 60.5 FPS khi chưa tải và thẻ trạng thái xử lý data.json* | *Đường FPS ổn định quanh 60 FPS khi xử lý ngầm (thời gian phản hồi tương tác 10.3 ms)* | *So sánh trực quan: Main Thread đạt 0.0 FPS & 1 lần khựng lớn; Isolate đạt 58.9 FPS & 0 lần khựng* |

---

## 3. Mục tiêu đề tài

- **So sánh Single-thread vs Multi-thread**: Làm rõ sự khác biệt giữa việc xử lý tác vụ nặng trên Main UI Thread và đưa ra Background Isolate trong Flutter.
- **Làm rõ bản chất bộ nhớ độc lập của Isolate**: Phân tích cơ chế cô lập Heap (Isolated Memory) của Dart, chứng minh các biến top-level/static là bản sao riêng biệt giữa các isolate, giúp tránh hoàn toàn hiện tượng race condition và deadlock.
- **Thực nghiệm các cơ chế giao tiếp luồng trong Dart**:
  - Giao tiếp hai chiều bằng thông điệp qua cặp cổng `SendPort` và `ReceivePort`.
  - Hàm tiện ích `compute()` tích hợp sẵn trong Flutter Foundation.
  - Tối ưu hóa chuyển giao đối tượng zero-copy bằng `Isolate.exit()`.
- **Đo lường định lượng và trực quan hóa FPS**:
  - Đo lường khung hình thời gian thực thông qua `AnimationController` và `FpsMonitor`.
  - Ghi nhận các chỉ số hiệu năng cụ thể: FPS trung bình, FPS cao nhất/thấp nhất khi xử lý, thời gian xử lý (Processing time), thời gian phản hồi tương tác (Response time), số lần khựng (> 50 ms), và tỉ lệ rớt khung hình (Dropped frame %).
  - Vẽ biểu đồ đường biến thiên FPS theo trục thời gian và biểu đồ cột so sánh tổng quan giữa cả 3 chế độ chạy.

---

## 4. Lý thuyết ngắn

Trong Dart, mã nguồn ứng dụng chạy mặc định trong một **Root Isolate** với một **Event Loop** duy nhất. Cơ chế `async/await` bản chất là lập trình bất đồng bộ dựa trên Event Queue, **không tự động tạo ra luồng mới**.

Khi gặp một tác vụ tính toán đồng bộ ngốn nhiều CPU (CPU-bound) như giải mã chuỗi JSON lớn (`jsonDecode(rawJson)`):
- Tác vụ này chiếm giữ toàn bộ CPU trên Root Isolate.
- Event Loop bị phong tỏa (blocked), không thể tiếp nhận và xử lý tín hiệu vẽ khung hình từ hệ điều hành (Vsync).
- Hậu quả: Hoạt ảnh và giao diện người dùng bị **đóng băng hoàn toàn (Jank / UI Freeze)** trong suốt thời gian hàm thực thi.

```dart
// Ví dụ về bộ nhớ độc lập (Isolated Heap):
int counter = 0; // Biến top-level trong Root Isolate

void worker(SendPort port) {
  // Isolate worker đọc biến counter trong Heap riêng của nó
  port.send(counter); // Worker thấy counter = 0, KHÔNG PHẢI 42!
}

void main() async {
  counter = 42; // Thay đổi này chỉ nằm trong Root Isolate
  final port = ReceivePort();
  await Isolate.spawn(worker, port.sendPort);
  final result = await port.first;
  print(result); // In ra 0
}
```

📖 **Tài liệu lý thuyết chi tiết:** Xem [docs/theory.md](docs/theory.md).

---

## 5. Kiến trúc ứng dụng & Luồng dữ liệu

Mã nguồn dự án được tổ chức gọn gàng theo từng trách nhiệm:

```text
lib/
├── main.dart             # Điểm khởi chạy ứng dụng (Entry point)
├── interface.dart        # Màn hình chính (DemoPage), hoạt ảnh Qiqi, nút Run, thanh trạng thái
├── runmodes.dart         # Triển khai 3 chế độ chạy: runOnMain, runWithCompute, runWithPorts
├── parsefile.dart        # Hàm processLargeJson giải mã JSON và tính toán thống kê
├── fps_monitor.dart      # Engine đo FPS (FpsMonitor) với cửa sổ mẫu 250ms
├── fps_charts.dart       # Màn hình Biểu đồ FPS (FpsChartsPage): 3 tab đường và 1 tab cột Tổng quan
└── result_table.dart     # Bảng phân trang PaginatedDataTable đọc dữ liệu lazy từ rawJson
assets/
├── data.json             # Tệp dữ liệu JSON lớn (~18.5 MB, ~120.000 bản ghi)
└── qiqi.gif              # Hoạt ảnh GIF dùng làm thước đo trực quan độ mượt của UI
tool/
└── gen.dart              # Script tạo tệp data.json mẫu ngẫu nhiên
```

### Chi tiết hoạt động của các module:

1. **Bộ phân tích cú pháp (`lib/parsefile.dart`)**:
   - `processLargeJson(String rawJson)`: Nhận chuỗi JSON thô, dùng `jsonDecode` để chuyển thành danh sách các đối tượng người dùng, tính tổng điểm (`totalScore`), số người sống tại Đà Nẵng (`daNangCount`), số lượng tags (`tagCount`), và trả về `ProcessResult` (Map chứa kết quả thống kê).
2. **Các chế độ xử lý (`lib/runmodes.dart`)**:
   - **`runOnMain`**: Thực thi trực tiếp hàm `processLargeJson` trên Root Isolate $\rightarrow$ Chặn UI thread.
   - **`runWithCompute`**: Sử dụng `compute(processLargeJson, rawJson)` để Flutter tự tạo Isolate tạm thời và thu dọn sau khi xong.
   - **`runWithPorts`**: Tự tạo Isolate bằng `Isolate.spawn` kèm cặp `SendPort`/`ReceivePort`. Hàm worker sau khi tính toán xong sẽ gọi `Isolate.exit(sendPort, result)` để chuyển quyền sở hữu kết quả về Root Isolate theo cơ chế **zero-copy**.
3. **Engine đo lường FPS (`lib/fps_monitor.dart`)**:
   - Lắng nghe sự kiện vẽ khung hình thông qua listener của `AnimationController`.
   - Sử dụng cửa sổ lấy mẫu chuẩn **250 ms** (`fpsSampleWindowUs = 250000`).
   - Phân tách riêng biệt số lượng frame trong thời gian xử lý (`processingBucketCount`) và thời gian hồi phục sau đó (`recoveryBucketCount`) để đảm bảo các khung hình hồi phục không bị vẽ lấn vào giai đoạn Main Thread đang bị khóa.
4. **Biểu đồ FPS (`lib/fps_charts.dart`)**:
   - **Tab Chế độ riêng (Main Thread / compute / Isolate)**: Sử dụng `CustomPainter` vẽ đường biến thiên FPS theo trục thời gian (tối đa 2s trước khi chạy đến 2s sau khi xong); có vạch đỏ đánh dấu thời điểm bắt đầu chạy và vạch xanh đánh dấu thời điểm xử lý xong.
   - **Tab Tổng quan**: Sử dụng `CustomPainter` vẽ 3 biểu đồ cột so sánh đối chiếu trực tiếp giữa 3 chế độ theo 3 tiêu chí: *FPS trung bình*, *Số lần giật (> 50 ms)*, và *Tỉ lệ rớt khung hình (%)*.
5. **Bảng phân trang hiển thị (`lib/result_table.dart`)**:
   - Sử dụng `PaginatedDataTable` hiển thị 120.000 bản ghi với cơ chế đọc phân trang lười (lazy loading qua `_UserDataSource`), chỉ giải mã các dòng JSON thuộc trang hiện tại (10 dòng/trang), giúp tiết kiệm tối đa bộ nhớ RAM.

📖 **Tài liệu kiến trúc chi tiết:** Xem [docs/architecture.md](docs/architecture.md).

---

## 6. Chạy từ source code

### Yêu cầu môi trường:
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (phiên bản `>= 3.13.5`)
- Thiết bị Android thật (đã bật *Tùy chọn cho nhà phát triển* & *Gỡ lỗi USB*) hoặc Android Emulator.

### Các lệnh thực thi:

```bash
# 1. Clone repo về máy
git clone https://github.com/Duy-OC/fps_isolate.git
cd fps_isolate

# 2. Cài đặt các thư viện phụ thuộc
flutter pub get

# 3. Chạy ứng dụng (khuyến nghị chế độ --profile hoặc --release để đo hiệu năng chuẩn xác nhất)
flutter run --profile

# 4. (Tùy chọn) Chạy bộ kiểm thử tự động
flutter test

# 5. (Tùy chọn) Tạo lại file data.json mẫu nếu muốn
dart run tool/gen.dart
```

---

## 7. Hướng dẫn sử dụng ứng dụng từng bước

1. **Màn hình chính**:
   - Khi mở app, bạn sẽ thấy hoạt ảnh GIF Qiqi quay liên tục cùng nhãn `FPS hiện tại: ~60.0`.
   - Phần thẻ **Xử lý file** bên dưới hiển thị tên tệp `data.json` cùng thanh tiến trình 3 trạng thái: `Chưa xử lý`, `Đang xử lý`, `Đã xử lý`.
2. **Kích hoạt Benchmark**:
   - Bấm nút **Run** $\rightarrow$ Một menu Bottom Sheet xuất hiện cho phép chọn 1 trong 3 chế độ:
     - **Main Thread**: Ngay khi bấm, hoạt ảnh Qiqi lập tức bị khựng cứng lại hoàn toàn; giao diện không thể cuộn hay tương tác trong khoảng 0.5s – 1.5s.
     - **compute()**: Hoạt ảnh Qiqi vẫn chuyển động mượt mà, không xảy ra hiện tượng giật lag.
     - **Isolate + Ports**: Hoạt ảnh tiếp tục xoay đều đặn ở mức ~60 FPS.
   - Khi xử lý xong, thanh trạng thái chuyển sang màu tím ở ô `Đã xử lý`.
3. **Xem kết quả & biểu đồ**:
   - Mở thanh menu bên cạnh (Drawer) $\rightarrow$ Chọn **Biểu đồ FPS**.
   - Chuyển giữa các tab:
     - Tab **Main Thread** / **compute()** / **Isolate**: Xem đường FPS theo thời gian, thời gian xử lý (ms), thời gian phản hồi tương tác (ms), số lần khựng (> 50 ms), và tỉ lệ rớt khung hình (%).
     - Tab **Tổng quan**: Sau khi đã bấm thử nghiệm cả 3 chế độ, tab này sẽ hiển thị 3 biểu đồ cột so sánh trực diện giúp nhận thấy ngay sự vượt trội của Isolate.

---

## 8. Dữ liệu thử nghiệm & Tối ưu bộ nhớ

- **Tệp dữ liệu `assets/data.json`**: Dung lượng ~18.5 MB, gồm 120.000 đối tượng JSON phẳng có cấu trúc:
  ```json
  {
    "id": 0,
    "name": "User 0",
    "email": "user0@example.com",
    "score": 85.4,
    "tags": ["a", "b", "c"],
    "address": {"city": "Da Nang", "zip": 54321}
  }
  ```
- **Tối ưu RAM**:
  - Khi parse trong Isolate: Hàm chỉ trả về kết quả tổng hợp nhỏ gọn `ProcessResult` (userCount, averageScore, daNangCount, tagCount), giải phóng bộ nhớ của 120.000 đối tượng ngay khi worker kết thúc.
  - Khi hiển thị bảng: `_UserDataSource` chỉ tìm kiếm vị trí dòng theo chỉ mục (index offset) trong chuỗi `rawJson` và giải mã đúng 10 bản ghi cho trang hiện hành, không giữ toàn bộ danh sách đối tượng trong RAM.

---

## 9. Kết quả đo đạc thực tế (Benchmark Results)

Số liệu đo lường thực tế ghi nhận từ chính ứng dụng trên thiết bị Android:

| Chỉ số Hiệu năng | Main Thread (UI Thread) | Flutter `compute()` | Custom Isolate (`Isolate.spawn`) |
| :--- | :---: | :---: | :---: |
| **FPS trung bình khi xử lý** | **0.0 FPS** *(đóng băng)* | **51.5 FPS** | **58.9 FPS** |
| **FPS cao nhất / thấp nhất** | 0.0 / 0.0 FPS | 56.0 / 48.0 FPS | 60.0 / 58.0 FPS |
| **Số lần khựng (> 50 ms)** | **1 lần** *(toàn bộ thời gian xử lý)* | **0 lần** | **0 lần** |
| **Thời gian phản hồi tương tác** | ~1.400 ms | **10.3 ms** | **~8.5 ms** |
| **Thời gian xử lý** | ~500 – 1.450 ms | ~505 ms | ~490 ms |
| **Tỉ lệ rớt khung hình** | **100%** | **14.2%** | **~1.5%** |
| **Trạng thái Hoạt ảnh GIF** | ❌ Bị đóng băng hoàn toàn | ✔️ Chuyển động mượt mà | ✔️ Chuyển động mượt mà |

📖 **Xem thêm phân tích chi tiết:** [docs/benchmark_results.md](docs/benchmark_results.md).

---

## 10. Phân tích, Kết luận & Hạn chế

### 10.1. Phân tích & Kết luận
- **Main Thread**: Do Event Loop phải gánh toàn bộ quá trình `jsonDecode` nặng, không một khung hình nào được vẽ trong suốt thời gian này $\rightarrow$ FPS trung bình khi xử lý tụt về đúng **0.0 FPS**, gây gián đoạn nghiêm trọng trải nghiệm người dùng.
- **`compute()` và Isolate**: Tách rời tác vụ tính toán sang một thread nền của hệ điều hành. Root Isolate hoàn toàn rảnh tay để tiếp tục duy trì hoạt ảnh mượt mà quanh mức **~60 FPS** với thời gian phản hồi tương tác cực nhanh (~10 ms).
- **`Isolate.spawn` + `Isolate.exit`**: Mang lại hiệu năng tối ưu nhất nhờ cơ chế zero-copy transfer, giúp gửi kết quả Map thống kê về Main Isolate tức thời mà không tốn chi phí sao chép bộ nhớ (deep copy).

### 10.2. Hạn chế cần lưu ý
1. **Chi phí khởi tạo Isolate**: Việc khởi tạo một Isolate tiêu tốn từ vài mili-giây, do đó không nên dùng Isolate cho các tác vụ tính toán quá nhỏ (< 5 ms).
2. **Bộ nhớ độc lập**: Không thể chia sẻ trực tiếp biến đối tượng giữa các isolate; mọi thông điệp cần trao đổi phải thông qua `SendPort`/`ReceivePort`.
3. **Nền tảng Flutter Web**: Trình duyệt chạy đơn luồng JavaScript nên `compute()` trên Web không chạy song song thật như trên thiết bị Android/iOS.
4. **Nút thắt Render**: Isolate chỉ giải quyết được tác vụ nặng về mặt logic/tính toán CPU-bound. Nếu giật lag do cây Widget quá sâu hoặc layout/paint quá nặng thì Isolate không thể can thiệp.

---

## 11. Tài liệu tham khảo & Giấy phép

- 📖 [docs/theory.md](docs/theory.md) – Lý thuyết chuyên sâu về Concurrency và Isolate trong Dart.
- 📐 [docs/architecture.md](docs/architecture.md) – Kiến trúc chi tiết các module và cơ chế đo FPS của ứng dụng.
- 📊 [docs/benchmark_results.md](docs/benchmark_results.md) – Kết quả đo đạc thực nghiệm.
- 🔗 [Dart Documentation – Concurrency & Isolates](https://dart.dev/language/concurrency)
- 🔗 [Flutter API – `compute` function](https://api.flutter.dev/flutter/foundation/compute-constant.html)

**Giấy phép (License)**: Dự án được phát hành theo giấy phép [MIT](LICENSE).
