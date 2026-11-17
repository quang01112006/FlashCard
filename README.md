# Flashcard SM-2

## Chạy ứng dụng có chức năng AI

Chạy các lệnh sau tại thư mục gốc của dự án (thư mục chứa `pubspec.yaml`):

```powershell
flutter pub get
flutter run --dart-define=AI_WORKER_URL=https://flashcard-ai.lambao2108.workers.dev
```

Nếu máy có nhiều thiết bị, thêm `-d <device-id>` vào lệnh chạy. Dùng `flutter devices` để xem danh sách thiết bị.

`AI_WORKER_URL` là địa chỉ dịch vụ trung gian đã được triển khai trên Cloudflare. Ứng dụng gửi yêu cầu đến Worker; Worker gọi Gemini bằng khóa được lưu trên Cloudflare. Đồng đội chỉ cần dùng lệnh trên, không cần tạo Worker, cài Wrangler hay nhập Gemini API key.

Nếu chạy bằng `flutter run` thông thường, các chức năng quản lý/học thẻ vẫn dùng được; chức năng tạo thẻ AI sẽ báo chưa cấu hình địa chỉ dịch vụ.

### Thử tạo thẻ AI

1. Mở tab **Bộ thẻ**, chọn bộ muốn thêm câu hỏi.
2. Mở menu **Nhập / xuất CSV**, chọn **Tạo thẻ AI**.
3. Nhập chủ đề hoặc kiến thức, chọn số lượng (1–10 thẻ) và mức độ. Bật **Tạo thêm bản tiếng Anh** nếu cần thẻ song ngữ.
4. Nhấn **Tạo bản nháp**, kiểm tra nội dung, chỉnh sửa hoặc bỏ chọn các thẻ không muốn lưu.
5. Nhấn **Lưu … thẻ đã chọn**. Thẻ chỉ được thêm vào bộ đang mở sau bước xác nhận này.

Nên thử với 2 thẻ trước. Nội dung AI cần được kiểm tra trước khi dùng để học. Tạo thẻ AI cần kết nối Internet; việc xem bản nháp chưa tự lưu thẻ.

### Chạy lại và build APK

Nếu ứng dụng đang chạy bằng lệnh có `--dart-define` ở trên, có thể nhấn `r` để hot reload hoặc `R` để hot restart trong terminal Flutter.

Khi thêm hoặc đổi `AI_WORKER_URL`, cần dừng phiên chạy bằng `q` rồi chạy lại toàn bộ lệnh. Hot reload/hot restart không cập nhật giá trị `--dart-define` của phiên đang chạy.

Khi build APK để demo, cũng phải truyền địa chỉ Worker:

```powershell
flutter build apk --release --dart-define=AI_WORKER_URL=https://flashcard-ai.lambao2108.workers.dev
```

### Khi gặp lỗi AI

- **Chưa cấu hình địa chỉ dịch vụ AI:** dừng app và chạy lại bằng lệnh đầy đủ ở trên.
- **Không thể kết nối / quá thời gian:** kiểm tra Internet rồi thử lại.
- **Đạt giới hạn yêu cầu:** Worker hiện giới hạn khoảng 5 yêu cầu/phút theo IP; chờ ít nhất một phút trước khi thử lại. Người dùng chung mạng có thể dùng chung giới hạn này. Hạn mức Gemini được tính riêng.
- **Gemini tạm thời quá tải hoặc không khả dụng:** chờ một lúc rồi thử lại.
- **Lỗi khóa API, model, vùng máy chủ hoặc cấu hình Cloudflare:** báo người phụ trách AI kiểm tra Worker; không cần sửa dữ liệu bộ thẻ hay nhập khóa vào ứng dụng.

### Lưu ý cho người phụ trách AI

- Mã Worker nằm trong `worker/src/index.js`, cấu hình nằm trong `worker/wrangler.jsonc`.
- Gemini API key được lưu dưới dạng secret tên `GEMINI_API_KEY` trên Cloudflare. Không ghi khóa vào README, mã Flutter, Git hoặc ảnh chụp gửi trong nhóm.
- Đồng đội dùng chung Worker và hạn mức Gemini của dự án. Chỉ người phụ trách dịch vụ cần cập nhật Worker khi thay đổi backend.
