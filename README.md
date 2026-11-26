# Memora — Ứng dụng thẻ ghi nhớ lặp lại ngắt quãng (SM-2 & AI)

Ứng dụng học và ôn tập kiến thức dài hạn kết hợp thuật toán **SuperMemo SM-2 (Spaced Repetition)**, **Trợ lý AI tạo thẻ** (Cloudflare Worker + Gemini/Groq) và **lưu trữ ngoại tuyến (Offline-first)** trên nền tảng **Flutter**.

- **Học phần:** INT1449 — Lập trình di động · **Chủ đề 33:** Thẻ ghi nhớ lặp lại ngắt quãng
- **Nhóm thực hiện:**
  - Nguyễn Cao Quảng — `B24DCCC237` 
  - Lâm Đức Bảo — `B24DCCC033`
  - Lê Viết Khánh — `B24DCCC159`
  - Vũ Bình Minh — `B24DCCC207`

---

## 1. Cài đặt, cấu hình và chạy

Chạy các lệnh sau tại thư mục gốc dự án (thư mục chứa `pubspec.yaml`):

```powershell
flutter pub get
flutter run
```

Nếu máy kết nối nhiều thiết bị, dùng `flutter devices` để lấy mã rồi chạy `flutter run -d <device-id>`.

- **Cấu hình AI (không chứa khóa):** Ứng dụng mặc định gọi Worker `https://flashcard-ai.lambao2108.workers.dev`. Khoá API được giữ hoàn toàn trên Cloudflare dưới dạng secret, đồng đội chỉ cần kéo mã về chạy ngay mà không cần cài Wrangler hay nhập API key.
- **Ghi đè URL Worker khác (tuỳ chọn):**
  ```powershell
  flutter run --dart-define=AI_WORKER_URL=https://worker-khac.example.workers.dev
  ```
  _(Khi đổi `--dart-define`, cần thoát hẳn bằng `q` và chạy lại lệnh; hot reload không cập nhật biến này.)_

Chạy kiểm thử và kiểm tra cảnh báo:

```powershell
flutter test
flutter analyze
node --test worker/test/index.test.js
```

---

## 2. Ứng dụng làm được gì

| Màn hình / Phân hệ       | Tính năng chính                                                                                                                                                                 |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Trang chủ**            | Thống kê thẻ mới, thẻ cần ôn, đã thuộc, tổng số thẻ; đếm chuỗi ngày học liên tiếp (**Streak**); chọn bộ thẻ để ôn nhanh.                                                        |
| **Học thẻ (SM-2)**       | Hoạt ảnh lật thẻ 3D; đánh giá 4 mức (**Học lại**, **Khó**, **Tốt**, **Dễ**); hiển thị khoảng cách ngày ôn kế tiếp; hỗ trợ hoàn tác (Undo) câu vừa đánh giá.               |
| **Bộ thẻ & Quản lý thẻ** | Tạo, đổi tên, xóa bộ thẻ; thêm/sửa/xóa/di chuyển thẻ; tìm kiếm không dấu tiếng Việt; lọc theo chủ đề và **3 mức độ Bloom** (Nhớ, Hiểu, Vận dụng); định dạng khối code markdown. |
| **Nhập / Xuất CSV**      | Nhập hàng loạt từ CSV với màn hình ghép cột linh hoạt, xem trước thẻ hợp lệ/dòng lỗi; xuất toàn bộ bộ thẻ ra file CSV chuẩn UTF-8.                                              |
| **Trợ lý AI tạo thẻ**    | Tạo nhanh 1–10 thẻ theo chủ đề hoặc văn bản kiến thức (có tuỳ chọn song ngữ Anh–Việt), xem trước và chỉnh sửa bản nháp trước khi lưu; có **chế độ Demo offline**.               |
| **Cài đặt**              | Chuyển giao diện **Sáng / Tối**; chuyển ngôn ngữ **Tiếng Việt / English** toàn ứng dụng; bật/tắt **thông báo nhắc ôn hằng ngày** theo giờ tùy chọn; khôi phục 300 thẻ mẫu gốc.  |

---

## 3. Cấu trúc mã nguồn

```text
Flashcard/
├── lib/
│   ├── main.dart                     Khởi tạo Hive (`app_settings`) & gắn Provider (`CardController`)
│   ├── core/app_theme.dart           Bảng màu và ThemeData (Sáng / Tối)
│   ├── l10n/app_strings.dart         Bản dịch song ngữ Việt – Anh dùng chung
│   ├── models/                       Mô hình dữ liệu thuần Dart (Flashcard, CardDeck)
│   ├── logic/sm2_algorithm.dart      Thuật toán SuperMemo SM-2 thuần Dart (không import Flutter)
│   ├── controllers/
│   │   └── card_controller.dart      Quản lý trạng thái tập trung (ChangeNotifier)
│   ├── services/                     Lưu trữ Hive, CSV, Thông báo cục bộ và Client AI Worker
│   ├── widgets/                      Thành phần UI tái sử dụng (lật thẻ 3D, code view, hộp thoại)
│   └── screens/                      Các màn hình chính (Home, Study, Decks, Manage, CSV, AI, Settings)
├── worker/                           Mã nguồn Cloudflare Worker proxy (Gemini + Groq dự phòng)
├── test/                             Bộ kiểm thử tự động (Unit test & Widget test)
└── .github/workflows/flutter.yml     CI tự động chạy flutter analyze và flutter test
```

Quy tắc phân tầng — dữ liệu và phụ thuộc chỉ đi theo một chiều:

```text
screens/  →  widgets/  →  controllers/  →  services/  →  logic/ & models/
```

---

## 4. Thuật toán SM-2, dữ liệu lưu ở đâu và quyền ứng dụng

### 4.1. Thuật toán SuperMemo SM-2 (`lib/logic/sm2_algorithm.dart`)

- **Hệ số độ dễ ($EF$):** mặc định $2.5$, tối thiểu $1.3$, cập nhật theo công thức:
  $$EF' = EF + (0.1 - (5 - q) \times (0.08 + (5 - q) \times 0.02))$$
- **Khoảng cách ôn tập ($I$ tính theo ngày):**
  - Chọn **Học lại** ($q = 1 < 3$): đặt lại chuỗi ôn thành công về $0$, ôn lại sau **1 ngày**.
  - Chọn **Khó / Tốt / Dễ** ($q \in \{3, 4, 5\}$): lần thành công thứ nhất **1 ngày**, lần thứ hai **6 ngày**, từ lần thứ ba trở đi $I(n) = \text{round}(I(n-1) \times EF')$.

### 4.2. Dữ liệu lưu ở đâu

Toàn bộ dữ liệu học tập được lưu cục bộ trên máy bằng **Hive NoSQL**, hoạt động bình thường khi tắt mạng:

| Hive Box       | Dữ liệu lưu trữ                                                                                                                                     |
| -------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `flashcards`   | Nội dung câu hỏi/đáp án (Việt–Anh), chủ đề, mức độ Bloom, thông số SM-2 và ngày ôn tiếp theo.                                                       |
| `decks`        | Danh sách các bộ thẻ (`id`, `name`, `description`).                                                                                                 |
| `app_settings` | Trạng thái `isDarkMode`, `isEnglish`, `isReminderEnabled`, `reminderHour`, `reminderMinute` và danh sách ngày đã học `studied_dates` (tính Streak). |

### 4.3. Quyền ứng dụng Android (`android/app/src/main/AndroidManifest.xml`)

- **`INTERNET`:** Chỉ dùng khi người dùng chủ động bấm **Tạo thẻ AI** (chỉ gửi chủ đề/văn bản yêu cầu tạo thẻ, số lượng, mức độ tới Worker; không gửi bộ thẻ cá nhân).
- **`POST_NOTIFICATIONS` (Android 13+):** Chỉ xin runtime đúng lúc người dùng bật **Nhắc nhở ôn tập hằng ngày** trong Cài đặt. Nếu từ chối, ứng dụng vẫn chạy bình thường.
- **`SCHEDULE_EXACT_ALARM` & `USE_EXACT_ALARM`:** Hỗ trợ đặt lịch nhắc ôn đúng giờ đã chọn (`AndroidScheduleMode.exactAllowWhileIdle`); nếu thiết bị không cấp quyền exact alarm, app tự chuyển sang chế độ `inexactAllowWhileIdle`.
- **`RECEIVE_BOOT_COMPLETED`:** Tự động khôi phục lịch nhắc ôn đã bật sau khi người dùng khởi động lại điện thoại.
- **`VIBRATE`:** Cho phép rung nhẹ khi thông báo nhắc ôn kích hoạt.

---

## 5. Tích hợp chức năng AI (Cloudflare Worker, Gemini & Groq dự phòng)

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

---

## 6. Bộ kiểm thử và CI

- **Kiểm thử Flutter (`flutter test`):** Bao phủ thuật toán SM-2 thuần (`sm2_test.dart`), lưu trữ Hive (`storage_test.dart`, `manage_card_hive_test.dart`), CRUD & lọc thẻ (`manage_cards_test.dart`, `manage_card_filter_test.dart`), nhập/xuất CSV (`csv_test.dart`, `manage_csv_*_test.dart`), luồng tạo thẻ AI (`manage_ai_test.dart`) và cài đặt (`settings_test.dart`).
- **Kiểm thử Worker (`node --test worker/test/index.test.js`):** Kiểm tra đầu vào, rate limit, retry backoff, fallback sang Groq và đảm bảo không lộ khóa API (59/59 tests pass).
- **CI tự động (`.github/workflows/flutter.yml`):** Tự chạy `flutter pub get`, `flutter analyze --no-fatal-infos` và `flutter test` trên mỗi lần `push` hoặc `pull_request`.

---

## 7. Muốn sửa gì thì sửa ở đâu

| Nhu cầu                              | Tệp cần sửa                                                                                                |
| ------------------------------------ | ---------------------------------------------------------------------------------------------------------- |
| Sửa công thức hoặc ngưỡng SM-2       | `lib/logic/sm2_algorithm.dart`                                                                             |
| Đổi bảng màu Sáng / Tối              | `lib/core/app_theme.dart`                                                                                  |
| Sửa / thêm bản dịch Việt – Anh       | `lib/l10n/app_strings.dart`, `lib/services/manage_ai_strings.dart`, `lib/services/manage_csv_strings.dart` |
| Sửa logic nhập / xuất CSV            | `lib/services/csv_service.dart`                                                                            |
| Sửa prompt AI hoặc model trên Worker | `worker/src/index.js` và `worker/wrangler.jsonc`                                                           |
| Sửa thông báo nhắc học hằng ngày     | `lib/services/notification_service.dart`                                                                   |
| Đổi logo / Adaptive Icon Android     | `android/app/src/main/res/mipmap-*/` và `mipmap-anydpi-v26/`                                               |

---

## 8. Đóng gói bản cài thử

```powershell
flutter build apk --release
```

- File đầu ra: `build/app/outputs/flutter-apk/app-release.apk`.
- **Ký số APK Release:** Cấu hình tại `android/app/build.gradle.kts` hỗ trợ ký bằng khóa riêng qua `android/key.properties` (chặn đẩy lên Git bởi `.gitignore`); nếu máy thành viên khác không có `key.properties`, Gradle tự lùi về khóa `debug` để build thử không bị lỗi.
- **Kênh phân phối thử nghiệm (GitHub Releases):** [Memora Release APK](https://github.com/quang01112006/FlashCard/releases).

---

## 9. Dùng AI

- **Công cụ sử dụng:** Google Gemini / Antigravity.
- **Phần được hỗ trợ:** Tư vấn chia cấu trúc thư mục dự án, chuẩn hóa thuật toán SM-2 & luồng Hoàn tác (Undo), cấu hình ký số APK Release an toàn cho nhóm, hỗ trợ kiểm thử (`flutter test`) và biên tập tài liệu.
- **Kiểm chứng:** Toàn bộ mã nguồn được các thành viên tự kiểm tra, chạy thử trực tiếp trên thiết bị Android thật (`CPH2565`), xác minh qua `flutter analyze` và `flutter test`.
- **Nhật ký hội thoại:** Các đoạn trao đổi kiến trúc, thuật toán và cấu hình ký số với AI được lưu tại [`docs/ai/`](docs/ai/).
