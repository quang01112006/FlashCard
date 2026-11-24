# Flashcard SM-2

## Chạy ứng dụng có chức năng AI

Chạy các lệnh sau tại thư mục gốc của dự án (thư mục chứa `pubspec.yaml`):

```powershell
flutter pub get
flutter run
```

Nếu máy có nhiều thiết bị, thêm `-d <device-id>` vào lệnh chạy. Dùng `flutter devices` để xem danh sách thiết bị.

Ứng dụng mặc định dùng Worker `https://flashcard-ai.lambao2108.workers.dev`. Worker gọi Gemini và tự chuyển sang Groq khi Gemini gặp lỗi tạm thời nếu đã cấu hình khóa Groq. Các khóa được lưu trên Cloudflare. Đồng đội chỉ cần dùng lệnh trên, không cần tạo Worker, cài Wrangler hay nhập API key. URL công khai này không phải khóa API.

Khi cần dùng Worker khác, có thể ghi đè URL mặc định:

```powershell
flutter run --dart-define=AI_WORKER_URL=https://worker-khac.example.workers.dev
```

### Thử tạo thẻ AI

1. Mở tab **Bộ thẻ**, chọn bộ muốn thêm câu hỏi.
2. Mở menu **Nhập / xuất CSV**, chọn **Tạo thẻ AI**.
3. Nhập chủ đề hoặc kiến thức, chọn số lượng (1–10 thẻ) và mức độ. Bật **Tạo thêm bản tiếng Anh** nếu cần thẻ song ngữ.
4. Nhấn **Tạo bản nháp**, kiểm tra nội dung, chỉnh sửa hoặc bỏ chọn các thẻ không muốn lưu.
5. Nhấn **Lưu … thẻ đã chọn**. Thẻ chỉ được thêm vào bộ đang mở sau bước xác nhận này.

Nên thử với 2 thẻ trước. Nội dung AI cần được kiểm tra trước khi dùng để học. Tạo thẻ AI cần kết nối Internet; việc xem bản nháp chưa tự lưu thẻ.

### Chạy lại và build APK

Khi ứng dụng đang chạy, có thể nhấn `r` để hot reload hoặc `R` để hot restart trong terminal Flutter.

Khi thêm hoặc đổi `AI_WORKER_URL`, cần dừng phiên chạy bằng `q` rồi chạy lại toàn bộ lệnh. Hot reload/hot restart không cập nhật giá trị `--dart-define` của phiên đang chạy.

Khi build APK để demo, URL mặc định cũng được dùng:

```powershell
flutter build apk --release
```

### Khi gặp lỗi AI

- **Chưa cấu hình địa chỉ dịch vụ AI:** kiểm tra xem có truyền `AI_WORKER_URL` rỗng hoặc sai định dạng không; dừng app rồi chạy lại bằng `flutter run` để dùng URL mặc định.
- **Không thể kết nối / quá thời gian:** kiểm tra Internet rồi thử lại.
- **Đạt giới hạn yêu cầu:** Worker hiện giới hạn khoảng 5 yêu cầu/phút theo IP; chờ ít nhất một phút trước khi thử lại. Người dùng chung mạng có thể dùng chung giới hạn này. Hạn mức Gemini được tính riêng.
- **Gemini tạm thời quá tải hoặc không khả dụng:** Worker tự thử lại tối đa 2 lần khi Gemini trả lỗi tạm thời (500/502/503/504), chờ tăng dần khoảng 1 rồi 2 giây. Nếu đã có `GROQ_API_KEY`, Worker chuyển sang Groq khi Gemini vẫn lỗi, hết thời gian chờ, lỗi mạng hoặc trả 429. Lỗi khóa API, model, vùng máy chủ, yêu cầu và dữ liệu không hợp lệ không kích hoạt Groq. Tổng thời gian xử lý tối đa 90 giây; Flutter chờ tối đa 105 giây. Sau khi cập nhật mã Flutter, hot restart bằng `R` hoặc chạy lại ứng dụng để áp dụng.
- **Lỗi khóa API, model, vùng máy chủ hoặc cấu hình Cloudflare:** báo người phụ trách AI kiểm tra Worker; không cần sửa dữ liệu bộ thẻ hay nhập khóa vào ứng dụng.

### Lưu ý cho người phụ trách AI

- Mã Worker nằm trong `worker/src/index.js`, cấu hình nằm trong `worker/wrangler.jsonc`.
- Model mặc định là `gemini-3.5-flash-lite`, được đặt qua biến `GEMINI_MODEL` trong `worker/wrangler.jsonc`. Đây là model ổn định có Free tier và hỗ trợ JSON theo [tài liệu Google](https://ai.google.dev/gemini-api/docs/models/gemini-3.5-flash-lite). Có thể đổi biến này để chọn model khác được dự án Gemini cấp quyền; thay đổi model không đảm bảo tránh được sự cố chung của Gemini.
- Gemini API key được lưu dưới dạng secret tên `GEMINI_API_KEY` trên Cloudflare. Không ghi khóa vào README, mã Flutter, Git hoặc ảnh chụp gửi trong nhóm.
- Đồng đội dùng chung Worker và hạn mức Gemini của dự án. Chỉ người phụ trách dịch vụ cần cập nhật Worker khi thay đổi backend.
- Sau khi sửa backend, cần triển khai lại Worker để ứng dụng dùng mã mới: chạy `npx.cmd wrangler deploy` tại thư mục `worker` trong PowerShell bằng tài khoản Cloudflare quản lý dịch vụ. Hot reload Flutter không cập nhật Worker.
- Để chẩn đoán lỗi, mở Real-time logs và bấm Begin log stream trước khi thử tạo thẻ. Worker ghi sự kiện `ai_generation_failed` với nhà cung cấp, model, mã lỗi, trạng thái HTTP của từng lần gọi và thời gian xử lý. Không ghi khóa API, chủ đề, nội dung thẻ hay thông báo lỗi thô từ nhà cung cấp. `outcome: ok` vẫn có thể đi kèm HTTP 502 vì Worker đã xử lý lỗi; cần xem mục `logs` để biết chi tiết.

### Bật Groq dự phòng cho người phụ trách AI

Gemini `gemini-3.5-flash-lite` là model chính; Groq `openai/gpt-oss-120b` là model dự phòng. Groq được gọi tối đa một lần trong mỗi yêu cầu tạo thẻ. Cả hai dùng cùng quy tắc kiểm tra số thẻ, nội dung bắt buộc và bản dịch. Khi Groq đã được cấu hình, Gemini có tối đa 55 giây, Groq dùng phần còn lại của tổng ngân sách 90 giây. Khi chưa có khóa Groq, Gemini vẫn có tối đa 90 giây.

1. Đăng nhập [Groq Console và tạo API key](https://console.groq.com/keys). Groq có Free plan với [hạn mức riêng theo tài khoản và model](https://console.groq.com/docs/rate-limits).
2. Mở PowerShell tại thư mục gốc dự án và lưu khóa vào Cloudflare bằng lệnh tương tác:

   ```powershell
   cd worker
   npx.cmd wrangler secret put GROQ_API_KEY
   ```

   Dán khóa tại lời nhắc của Wrangler. Không điền khóa vào mã nguồn, `wrangler.jsonc`, tham số dòng lệnh hoặc tin nhắn. Có thể dùng Cloudflare Dashboard: **Workers & Pages → flashcard-ai → Settings → Variables and Secrets → Add**, chọn kiểu **Secret**, tên **GROQ_API_KEY**, điền khóa rồi lưu/triển khai.
3. Triển khai mã Worker có hỗ trợ Groq:

   ```powershell
   npx.cmd wrangler deploy
   ```

4. Kiểm tra danh sách tên secret bằng `npx.cmd wrangler secret list`; cần có `GEMINI_API_KEY` và `GROQ_API_KEY`. Lệnh này không hiển thị giá trị khóa.
5. Mở **Real-time logs → Begin log stream** rồi thử tạo thẻ. Nếu chuyển sang Groq, log có `ai_fallback_started`; khi Groq tạo được thẻ hợp lệ sẽ có `ai_fallback_succeeded`. Gemini thành công ngay thì Groq không được gọi. Khi cả hai thất bại, xem `ai_generation_failed` và trường `provider`, `providerStatus`, `attempts`.

`GROQ_MODEL` trong `worker/wrangler.jsonc` đặt model dự phòng. Chỉ đổi sang model hỗ trợ JSON Schema strict; mã dùng [Structured Outputs của Groq](https://console.groq.com/docs/structured-outputs). Giới hạn 5 yêu cầu/phút theo IP của Worker áp dụng trước khi gọi bất kỳ nhà cung cấp nào. Hạn mức miễn phí của Gemini và Groq được tính riêng; cơ chế dự phòng không đảm bảo mọi yêu cầu đều thành công.
