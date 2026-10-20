# Kết quả Đo Lường Hiệu Năng (Benchmark Results)

Tài liệu này lưu trữ kết quả thực nghiệm đo lường hiệu năng FPS và thời gian xử lý JSON giữa Main Thread, `compute()` và Isolate độc lập từ ứng dụng.

---

## 1. Môi trường Thực nghiệm (Environment Setup)

- **Thiết bị thử nghiệm**: Android Phone / Android Emulator
- **Kiến trúc CPU**: *ARM64-v8a / x86_64*
- **Hệ điều hành**: Android 13 / 14
- **Phiên bản Flutter / Dart**: Flutter 3.13.5+ / Dart 3.1+
- **Chế độ biên dịch (Build Mode)**: `--release` (hoặc `--profile`)
- **Tập tin JSON thử nghiệm**: `assets/data.json` kích thước **~18.5 MB** (~120.000 bản ghi người dùng)

> [!IMPORTANT]
> **Quy trình đo đạc**:
> 1. Mở ứng dụng, quan sát hoạt ảnh Qiqi chạy mượt mà ở màn hình chính cùng FPS nền (~60 FPS).
> 2. Bấm nút **Run**, chọn lần lượt từng chế độ: **Main Thread**, **compute()**, **Isolate + Ports**.
> 3. Không chạm hoặc tương tác vào màn hình trong suốt quá trình đo để tránh gây nhiễu cho phép đo FPS.
> 4. Mở menu Drawer $\rightarrow$ **Biểu đồ FPS** $\rightarrow$ Tab **Tổng quan** để đối chiếu trực tiếp kết quả.

---

## 2. Bảng Số Liệu Đo Lường Thực Tế (Benchmark Comparison)

Số liệu đo lường trực tiếp từ ứng dụng khi chạy trên thiết bị Android:

| Chỉ số Hiệu năng | Main Thread (UI Thread) | Flutter `compute()` | Custom Isolate (`Isolate.spawn`) |
| :--- | :---: | :---: | :---: |
| **FPS trung bình khi xử lý** | **0.0 FPS** *(đóng băng)* | **51.5 FPS** | **58.9 FPS** |
| **FPS cao nhất khi xử lý** | 0.0 FPS | 56.0 FPS | 60.0 FPS |
| **FPS thấp nhất khi xử lý** | 0.0 FPS | 48.0 FPS | 58.0 FPS |
| **Số lần khựng (> 50 ms)** | **1 lần** *(toàn bộ thời gian chạy)* | **0 lần** | **0 lần** |
| **Thời gian phản hồi tương tác** | ~1.400 ms | **10.3 ms** | **~8.5 ms** |
| **Thời gian xử lý** | ~500 – 1.450 ms | ~505 ms | ~490 ms |
| **Tỉ lệ rớt khung hình** | **100%** | **14.2%** | **~1.5%** |
| **Trạng thái Hoạt ảnh Qiqi** | ❌ Bị đóng băng hoàn toàn | ✔️ Chuyển động liên tục | ✔️ Chuyển động mượt mà |

---

## 3. Ảnh Chụp Màn Hình Đối Chiếu Thực Tế

![So sánh hiệu năng thực tế trên thiết bị](../demo/overview_comparison.jpg)
*Hình ảnh từ tab "Tổng quan" của ứng dụng: So sánh FPS trung bình, Số lần giật (>50ms) giữa Main Thread, compute() và Isolate.*

---

## 4. Phân tích Chi tiết Kết quả

1. **Main Thread**:
   - Khi chạy trên Root Isolate, toàn bộ CPU bị khóa chặt bởi hàm `processLargeJson` (đặc biệt là công đoạn `jsonDecode(rawJson)` với chuỗi 18.5 MB).
   - Trong suốt thời gian này, không có khung hình nào được render $\implies$ FPS trung bình đo được là **0.0 FPS**, tỉ lệ rớt khung hình đạt **100%**, ghi nhận **1 lần khựng lớn** kéo dài suốt thời gian xử lý.
   - Hoạt ảnh Qiqi bị đứng hình hoàn toàn, tạo cảm giác app bị crash hoặc đơ với người dùng.

2. **Flutter `compute()`**:
   - Tác vụ parse JSON được đẩy sang Isolate nền do Flutter Foundation tự động tạo.
   - Root Isolate vẫn tự do duy trì vòng lặp vẽ khung hình, hoạt ảnh Qiqi vẫn chuyển động đều đặn.
   - FPS duy trì ở mức cao (**51.5 FPS**), **0 lần khựng** (> 50 ms), thời gian phản hồi tương tác chỉ còn **10.3 ms**.

3. **Custom Isolate (`Isolate.spawn` + `Isolate.exit`)**:
   - Tự quản lý Isolate và kết thúc bằng `Isolate.exit(sendPort, result)`.
   - Cơ chế zero-copy transfer của `Isolate.exit` giúp chuyển giao quyền sở hữu vùng nhớ Map kết quả sang Root Isolate tức thời mà không tốn chi phí deep copy.
   - Đạt hiệu năng tối ưu nhất: **58.9 FPS** (gần sát mức trần 60 FPS của màn hình), tỉ lệ rớt khung hình chỉ ~1.5%, **0 lần khựng**.
