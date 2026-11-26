# Ghi chép dùng AI — Nguyễn Cao Quảng (`B24DCCC237`)

- **Công cụ AI sử dụng:** Google Gemini (Antigravity)
- **Phần việc chính của mình:** Chốt cấu trúc thư mục cho cả nhóm làm việc chung, chuẩn hóa công thức SM-2 và cấu hình ký số file APK Release.

---

## Hội thoại 1 — Chia thư mục dự án sao cho nhóm 4 người dễ làm chung

- **Bối cảnh:** Nhóm có 4 người làm song song trên Git, thời gian gấp. Mình phân vân không biết nên chia thư mục theo từng tính năng lớn hay chia thẳng theo từng loại file (`screens/`, `widgets/`, `controllers/`, `services/`, `logic/`, `models/`).
- **Mình hỏi AI:** *"Nhóm 4 sinh viên làm app Flutter trong vài tuần, nên chia thư mục kiểu nào cho dễ chia việc, ít đụng nhau trên Git mà vẫn dễ viết test?"*
- **AI gợi ý:** Nên chia thẳng theo tầng (`screens → widgets → controllers → services → logic & models`), đừng tách quá vụn. Quan trọng nhất là tách riêng `logic/sm2_algorithm.dart` thành code Dart thuần, không import Flutter để chạy test cho lẹ.
- **Cách mình chốt cho nhóm:**
  - Thống nhất chia `lib/` thành 8 thư mục con như trong `README.md`.
  - Quy ước trong nhóm: màn hình bên `screens/` không gọi thẳng `Hive`, muốn lưu hay đọc dữ liệu thì đi qua `CardController` và `StorageService`.

---

## Hội thoại 2 — Chốt công thức SuperMemo SM-2 và nút Hoàn tác (Undo)

- **Bối cảnh:** Thuật toán SM-2 gốc chấm điểm từ `0` đến `5`, nhưng trên điện thoại chỉ làm 4 nút (**Học lại**, **Khó**, **Tốt**, **Dễ**) cho dễ bấm. Ngoài ra cần xử lý trường hợp bấm nhầm nút muốn quay lại.
- **Mình hỏi AI:** *"Ánh xạ 4 nút đánh giá trên app vào thang điểm 0–5 của SM-2 như thế nào cho đúng chuẩn, và làm sao hỗ trợ bấm Hoàn tác khi lỡ tay đánh giá nhầm?"*
- **AI gợi ý:** Gán 4 nút tương ứng `q = 1, 3, 4, 5`. Nếu `q < 3` (Học lại) thì reset chuỗi về 0 và hẹn 1 ngày sau học lại; còn `q >= 3` thì lần 1 hẹn 1 ngày, lần 2 hẹn 6 ngày, từ lần 3 trở đi lấy khoảng cách cũ nhân với hệ số độ dễ `EF` (giữ mức tối thiểu `EF >= 1.3`).
- **Cách mình áp dụng vào code:**
  - Viết gọn thành hàm thuần trong `lib/logic/sm2_algorithm.dart` và kiểm tra bằng 10 test case trong `test/sm2_test.dart` (gồm cả test sàn `EF = 1.3` và chuỗi lặp tăng dần).
  - Lưu lại bản sao thẻ trước khi chấm điểm (`_lastRatedCard` bên `study_screen.dart`) để bấm Undo khôi phục được nguyên trạng.

---

## Hội thoại 3 — Ký số file APK Release bằng khóa riêng mà không làm lỗi máy đồng đội

- **Bối cảnh:** Cần tạo khóa riêng (`upload-keystore.jks`) ký vào `app-release.apk` để phát hành bản cài thử, nhưng file khóa và mật khẩu (`key.properties`) không được đẩy lên GitHub. Nếu cấu hình cứng thì 3 bạn còn lại kéo code về máy sẽ bị lỗi build vì không có file khóa của mình.
- **Mình hỏi AI:** *"Chỉ mình cách cấu hình ký APK Release bằng khóa riêng trên máy mình, nhưng Khánh, Bảo, Minh kéo code về chạy `flutter run` hay build thử vẫn chạy bình thường dù không có file khóa."*
- **AI gợi ý:** Lưu mật khẩu vào `android/key.properties`, chặn cả `.jks` lẫn `key.properties` trong `.gitignore`, rồi kiểm tra nếu có file này mới dùng khóa riêng.
- **Cách mình áp dụng vào code:**
  - Chuyển đoạn cấu hình mẫu sang đúng cú pháp Kotlin DSL trong `android/app/build.gradle.kts`, thêm nhánh `else` tự lùi về khóa `debug` nếu máy không có `key.properties`.
  - Đảm bảo `.gitignore` chặn sạch 2 file bí mật trước khi commit (`ec21c7b`), rồi chạy `flutter build apk --release` ra file `55.4 MB` mang chữ ký `CN=Nguyen Cao Quang` để up lên GitHub Releases.
