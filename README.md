# FPS Isolate Benchmark (Flutter) 🚀

Ứng dụng Flutter đo lường, giám sát và trực quan hóa hiệu năng FPS (Frames Per Second) khi xử lý tác vụ nặng (Parse tập tin JSON dung lượng lớn ~18.5MB) giữa **Main Thread (UI Thread)** và **Đa luồng (Background Isolate - `compute()` & `Isolate.spawn`)**.

> [!NOTE]
> Repository này lưu trữ **Phần UI (Giao diện người dùng)** và **Hệ thống Giám sát FPS (FPS Monitor Engine & Real-time Charts)** (phần đảm nhận 1 nửa dự án).

---

## 📌 Tính năng chính

### 1. 🖥️ Giao diện người dùng (UI Component)
- **Visual Jank Indicator**: Tích hợp AnimationController quay liên tục kết hợp hiển thị GIF. Khi tác vụ chạy trên Main Thread, animation sẽ lập tức bị khựng/đóng băng (freeze), giúp người dùng quan sát trực quan sự ảnh hưởng đến trải nghiệm người dùng (UX).
- **Control Panel**: Các nút điều khiển kích hoạt đo đạc hiệu năng theo 3 chế độ:
  - **Main Thread**: Xử lý trực tiếp trên UI thread (gây giật/lag giao diện).
  - **compute()**: Tận dụng cơ chế `compute()` tích hợp sẵn của Flutter.
  - **Custom Isolate**: Tự tạo Isolate riêng qua `Isolate.spawn` và truyền kết quả qua `ReceivePort` / `Isolate.exit`.
- **Result Metrics Card**: Hiển thị bảng tóm tắt thời gian xử lý (Processing time), thời gian phản hồi giao diện (Response time), FPS trung bình và số khung hình bị bỏ rơi (% Dropped frames).
- **Result Table (Lazy Paginated Table)**: Hiển thị dữ liệu trích xuất từ tập tin JSON lớn qua `PaginatedDataTable` với cơ chế đọc phân trang mượt mà, tối ưu bộ nhớ (`lib/result_table.dart`).

### 2. 📊 Hệ thống giám sát FPS (FPS Monitor & Charts Engine)
- **Đo lường Frame Time chính xác (`lib/fps_monitor.dart`)**:
  - Lắng nghe sự kiện render frame thông qua `AnimationController.addListener` và time tracker (`microseconds`).
  - Phân tích mẫu theo cửa sổ thời gian (Sample Window 250ms) để loại bỏ nhiễu và ngăn hiện tượng FPS ảo ở các khung thời gian ngắn.
- **Các chỉ số phân tích chi tiết (`FrameStats`)**:
  - `averageFps`: FPS trung bình trong suốt thời gian xử lý tác vụ.
  - `lowestFps` / `highestFps`: FPS thấp nhất và cao nhất ghi nhận được.
  - `droppedFramePercent`: Tỷ lệ khung hình bị mất so với mốc chuẩn 60 FPS.
  - `longPauses`: Đếm số lần giao diện bị đơ/khựng quá 50ms (> 3 khung hình bị mất liên tiếp).
  - `responseTimeMs`: Thời gian từ lúc hoàn thành xử lý đến khi UI vẽ được frame tiếp theo.
- **Biểu đồ trực quan hóa chuyên sâu (`lib/fps_charts.dart`)**:
  - Được vẽ tùy biến bằng `CustomPainter` (`_FpsLinePainter`).
  - Hỗ trợ 4 Tab: **Main Thread**, **compute()**, **Isolate**, và **Tổng quan (Overview Comparison)**.
  - Vẽ đường biến thiên FPS theo trục thời gian, vạch mốc chuẩn 60 FPS, vạch FPS trung bình, cùng các thẻ chỉ số trực quan.

---

## 📁 Cấu trúc thư mục (Source Code Structure)

```text
lib/
├── main.dart             # Điểm khởi chạy ứng dụng (Entry point)
├── interface.dart        # [Đảm nhận - UI] Màn hình tương tác chính, visual animation, điều khiển benchmark
├── fps_monitor.dart      # [Đảm nhận - Monitor] Bộ tính toán chỉ số FPS, thu thập frame times, tính frame drop
├── fps_charts.dart       # [Đảm nhận - UI/Charts] Biểu đồ FPS chi tiết vẽ bằng CustomPainter (4 tabs)
├── result_table.dart     # [Đảm nhận - UI] Bảng hiển thị kết quả phân trang PaginatedDataTable
├── parsefile.dart        # (Module thành viên khác: Parse JSON dữ liệu lớn)
└── runmodes.dart         # (Module thành viên khác: 3 chế độ chạy Main Thread, compute(), Isolate)
assets/
├── data.json             # Dữ liệu mẫu lớn (~18.5MB) phục vụ kiểm thử benchmark
└── qiqi.gif              # Ảnh động kiểm tra độ mượt của UI
```

---

## 📊 So sánh hiệu năng thực tế

| Tiêu chí | Main Thread | compute() | Custom Isolate (`Isolate.spawn`) |
| :--- | :---: | :---: | :---: |
| **Trạng thái UI** | ❌ Đóng băng hoàn toàn (Freeze) | ✔️ Mượt mà (Smooth 60 FPS) | ✔️ Mượt mà (Smooth 60 FPS) |
| **Average FPS** | ~0 - 15 FPS | ~58 - 60 FPS | ~58 - 60 FPS |
| **Long Pauses (>50ms)** | Cao (100% thời gian chạy) | 0 | 0 |
| **Dropped Frame %** | > 80% | ~ 0% | ~ 0% |
| **Trải nghiệm người dùng** | Rất tệ (lag/khựng) | Cực kỳ mượt mà | Cực kỳ mượt mà |

---

## 🛠️ Hướng dẫn cài đặt & Khởi chạy

### Yêu cầu môi trường
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Khuyến nghị phiên bản `>= 3.13.5`)
- Dart SDK đi kèm
- Thiết bị Android / Trình giả lập hoặc Windows Desktop

### Các bước chạy ứng dụng
1. **Clone repository về máy:**
   ```bash
   git clone https://github.com/Duy-OC/fps_isolate.git
   cd fps_isolate
   ```

2. **Cài đặt các gói phụ thuộc:**
   ```bash
   flutter pub get
   ```

3. **Khởi chạy ứng dụng:**
   ```bash
   flutter run
   ```

4. **Tạo file APK (Release mode):**
   ```bash
   flutter build apk
   # Hoặc build chia theo từng kiến trúc CPU (tối ưu dung lượng):
   flutter build apk --split-per-abi
   ```

---

## 👤 Phần việc đảm nhận (1 nửa dự án)
- **UI & FPS Monitor Module**:
  - Thiết kế & hoàn thiện toàn bộ Giao diện người dùng (UI) và hoạt ảnh kiểm tra giật lag (Visual Indicator).
  - Triển khai bảng dữ liệu phân trang tối ưu bộ nhớ `PaginatedDataTable` (`lib/result_table.dart`).
  - Xây dựng hệ thống đo lường hiệu năng FPS theo thời gian thực (`lib/fps_monitor.dart`).
  - Thiết kế và vẽ biểu đồ hiệu năng FPS tùy chỉnh bằng `CustomPainter` (`lib/fps_charts.dart`).
  - Viết tài liệu hướng dẫn và báo cáo kỹ thuật `README.md`.
