# Memora — Ứng dụng thẻ ghi nhớ lặp lại ngắt quãng thông minh

Ứng dụng ghi nhớ dài hạn kết hợp thuật toán lặp lại ngắt quãng **SuperMemo SM-2 (Spaced Repetition)** và **Trí tuệ nhân tạo (Google Gemini AI)** trên nền tảng **Flutter 3.x**.

* **Học phần:** INT1449 — Lập trình ứng dụng di động · Học kỳ 1, Năm học 2026–2027
* **Chủ đề 33:** Thẻ ghi nhớ lặp lại ngắt quãng (Spaced Repetition Flashcard với thuật toán SM-2)
* **Nhóm sinh viên thực hiện:**
  - **Nguyễn Cao Quảng** (Trưởng nhóm)
  - **Lâm Đức Bảo**
  - **Lê Viết Khánh**
  - **Vũ Bình Minh**

---

## 1. Chạy ứng dụng

### 1.1. Cài đặt và khởi chạy nhanh

Chạy các lệnh sau tại thư mục gốc của dự án (thư mục chứa `pubspec.yaml`):

```bash
flutter pub get
flutter run
```

Chạy trên thiết bị cụ thể:
* **Trình duyệt Chrome:** `flutter run -d chrome`
* **Ứng dụng Windows:** `flutter run -d windows`
* **Điện thoại / Máy ảo Android:** `flutter run -d <device-id>` (dùng `flutter devices` để xem danh sách).

### 1.2. Chạy bộ kiểm thử (Testing)

```bash
flutter test
```

Toàn bộ hơn 20 bộ kiểm thử bao phủ toàn diện từ thuật toán toán học SM-2 thuần, luồng dữ liệu Hive, nhập/xuất CSV cho tới ViewModel và Widget.

Kiểm tra định dạng và cảnh báo mã nguồn:

```bash
flutter analyze
```

---

## 2. Ứng dụng làm được gì

| Phân hệ | Tính năng nổi bật |
|---|---|
| **Bộ thẻ & Quản lý thẻ** | Tạo, sửa, xóa bộ thẻ; tìm kiếm nhanh theo câu hỏi/câu trả lời; lọc linh hoạt theo **3 cấp độ tư duy Bloom** (Nhớ, Hiểu, Vận dụng) và theo chủ đề (Tag). |
| **Phiên học ngắt quãng (SM-2)** | Hoạt ảnh lật thẻ 3D mượt mà; đánh giá mức độ nhớ 4 cấp độ (**Học lại**, **Khó**, **Tốt**, **Dễ**); tự động tính toán chính xác ngày ôn tiếp theo và hệ số độ dễ $EF$. |
| **Trợ lý AI tạo thẻ** | Tự động sinh danh sách thẻ câu hỏi theo chủ đề hoặc tài liệu; hỗ trợ tạo thẻ song ngữ Anh - Việt; cho phép xem, chỉnh sửa bản nháp trước khi lưu vào bộ nhớ. |
| **Nhập / Xuất dữ liệu CSV** | Nhập hàng loạt thẻ từ file CSV bên ngoài với cơ chế tự động khớp cột thông minh; xuất bộ thẻ ra file CSV để sao lưu hoặc chia sẻ. |
| **Nhắc nhở học tập (Local Notification)** | Thiết lập thông báo đẩy định kỳ hàng ngày theo giờ tùy chỉnh trên điện thoại. |
| **Cá nhân hóa & Đa ngôn ngữ** | Chuyển đổi giao diện Sáng / Tối; hỗ trợ song ngữ **Tiếng Việt** và **Tiếng Anh**. |

Dữ liệu học tập và tiến độ ghi nhớ được lưu trữ cục bộ bảo mật trên máy người dùng thông qua **Hive** (NoSQL Database), hoạt động ngoại tuyến (Offline-first) hoàn toàn mà không cần đăng nhập máy chủ.

---

## 3. Cấu trúc mã nguồn

```
Flashcard/
├── lib/
│   ├── main.dart                  Khởi tạo Hive boxes, NotificationService và Provider root
│   ├── core/
│   │   └── app_theme.dart         Cấu hình ThemeData (Light/Dark Mode), bảng màu và kiểu chữ đồng nhất
│   ├── l10n/
│   │   └── app_strings.dart       Bản dịch song ngữ Anh - Việt dùng chung cho toàn ứng dụng
│   ├── models/                    Định nghĩa cấu trúc dữ liệu thuần Dart + Hive TypeAdapters
│   │   ├── flashcard.dart         Thẻ học: mặt trước/sau, chủ đề, cấp độ Bloom, thông số SM-2
│   │   └── card_deck.dart         Bộ thẻ: tiêu đề, mô tả, danh sách thẻ con, số thẻ cần ôn
│   ├── logic/
│   │   └── sm2_algorithm.dart     Thuật toán SuperMemo SM-2 toán thuần — độc lập 100% với Flutter
│   ├── controllers/               Quản lý trạng thái (State Management) kế thừa ChangeNotifier
│   │   └── card_controller.dart   Controller trung tâm: nạp thẻ, đánh giá SM-2, theme, ngôn ngữ
│   ├── services/                  Tầng dịch vụ xử lý I/O, lưu trữ và giao tiếp ngoại vi
│   │   ├── storage_service.dart   Đọc/ghi Hive boxes cho bộ thẻ và cài đặt người dùng
│   │   ├── ai_card_service.dart   Giao tiếp API Cloudflare Worker để sinh thẻ học qua Gemini
│   │   ├── csv_service.dart       Phân tích (Parse) và xuất (Export) dữ liệu CSV linh hoạt
│   │   └── notification_service.dart Lên lịch thông báo cục bộ flutter_local_notifications
│   ├── widgets/                   Các thành phần giao diện tái sử dụng
│   │   ├── flip_card_widget.dart  Hoạt ảnh lật thẻ 3D (Matrix4 transformation) trực quan
│   │   └── code_text_view.dart    Hiển thị khối code với định dạng monospaced chuyên dụng
│   └── screens/                   Các màn hình chức năng của ứng dụng
│       ├── main_nav_screen.dart   Thanh điều hướng chính (Bottom Navigation Bar)
│       ├── home_screen.dart       Trang tổng quan: thống kê số thẻ cần ôn, bộ thẻ nổi bật
│       ├── study_screen.dart      Không gian học lật thẻ tập trung theo thuật toán SM-2
│       ├── manage_cards_screen.dart Quản lý thẻ: tìm kiếm, lọc Bloom, thao tác hàng loạt
│       ├── manage_ai_screen.dart  Trợ lý AI tạo thẻ câu hỏi, hỗ trợ chế độ Demo offline
│       └── settings_screen.dart   Cài đặt giao diện Sáng/Tối, giờ nhắc học, ngôn ngữ
└── test/                          Bộ kiểm thử tự động toàn diện (200/200 tests passed)
    ├── sm2_test.dart              Kiểm thử thuật toán SuperMemo SM-2 toán thuần (Quality, EF, Interval)
    ├── storage_test.dart          Kiểm thử nạp 300 câu hỏi mẫu và lưu trữ dữ liệu Hive NoSQL
    ├── study_decks_test.dart      Kiểm thử luồng học, chuyển tab, lật thẻ và đánh giá
    ├── manage_ai_test.dart        Kiểm thử luồng tạo thẻ AI, xem trước bản nháp và song ngữ
    ├── csv_test.dart              Kiểm thử phân tích cú pháp CSV và xuất dữ liệu
    ├── manage_csv_widget_test.dart Kiểm thử giao diện nhập/xuất CSV, ghép cột và xử lý lỗi
    ├── manage_cards_test.dart     Kiểm thử CRUD thẻ học, tìm kiếm và bộ lọc Bloom
    ├── manage_decks_test.dart     Kiểm thử quản lý bộ thẻ, thêm/sửa/xóa bộ thẻ
    ├── settings_test.dart         Kiểm thử cài đặt Dark Mode, thông báo nhắc học và ngôn ngữ
    └── support/                   Bộ giả lập (Mocks/Fakes) phục vụ cô lập kiểm thử độc lập
```

### Quy tắc phân tầng & Luồng dữ liệu một chiều:

```
screens/  →  widgets/  →  controllers/  →  services/  →  logic/ & models/
```

* **Mã thuần (Pure Logic):** `lib/logic/sm2_algorithm.dart` hoàn toàn không import bất kỳ package Flutter nào, giúp kiểm thử đơn vị độc lập và chạy cực nhanh trong vài mili-giây.
* **Không phụ thuộc vòng (No Circular Dependency):** Các màn hình (`screens/`) chỉ lắng nghe trạng thái qua `Provider` / `Selector` từ `controllers/`, không bao giờ gọi trực tiếp tầng cơ sở dữ liệu `Hive`.

---

## 4. Thuật toán SuperMemo SM-2 & Mô hình nhận thức

### 4.1. Công thức toán học SM-2

Thuật toán SuperMemo SM-2 tính toán thời điểm tối ưu mà não bộ sắp quên kiến thức để nhắc nhở người học ôn tập lại:

1. **Cập nhật Hệ số độ dễ (Easiness Factor - $EF$):**
   $$EF' = EF + (0.1 - (5 - q) \times (0.08 + (5 - q) \times 0.02))$$
   *Trong đó:*
   * $EF$: Hệ số độ dễ hiện tại (mặc định ban đầu $EF = 2.5$; quy định $EF \ge 1.3$).
   * $q$: Điểm chất lượng ghi nhớ ($0 \le q \le 5$).

2. **Xác định Khoảng cách ôn tập tiếp theo ($I$ - tính theo ngày):**
   * **Nếu $q < 3$ (Quên / Chưa thuộc):**
     $$Repetitions = 0, \quad I = 1 \text{ ngày}$$
   * **Nếu $q \ge 3$ (Đã nhớ):**
     $$I(n) = \begin{cases} 1 \text{ ngày} & \text{khi } Repetitions = 0 \\ 6 \text{ ngày} & \text{khi } Repetitions = 1 \\ \text{round}(I(n-1) \times EF') & \text{khi } Repetitions \ge 2 \end{cases}$$
     $$Repetitions = Repetitions + 1$$

### 4.2. Ánh xạ 4 nút đánh giá trên giao diện

| Nút đánh giá | Điểm $q$ | Ý nghĩa trong thuật toán | Tác động lên thẻ |
|---|:---:|---|---|
| **Học lại (Again)** | $1$ | Hoàn toàn không nhớ câu trả lời. | Reset chuỗi về 0, ôn lại sau 1 ngày, $EF$ giảm mạnh. |
| **Khó (Hard)** | $3$ | Nhớ được nhưng phải đắn đo rất lâu. | Tiếp tục chuỗi, $EF$ giảm nhẹ, khoảng cách ôn tăng vừa phải. |
| **Tốt (Good)** | $4$ | Nhớ đúng sau một chút suy nghĩ. | Giữ nguyên $EF$, khoảng cách ôn tăng theo cấp số nhân tiêu chuẩn. |
| **Dễ (Easy)** | $5$ | Nhớ ngay lập tức mà không cần suy nghĩ. | Tăng $EF$, khoảng cách ôn tăng vọt cho lần kế tiếp. |

### 4.3. Kết hợp thang đo tư duy Bloom (Bloom's Taxonomy)

Thẻ học được gắn nhãn theo 3 cấp độ nhận thức tinh gọn:
* **Nhớ (Remember):** Các câu hỏi định nghĩa, thuật ngữ, cú pháp cơ bản.
* **Hiểu (Understand):** Các câu hỏi giải thích cơ chế, phân biệt khái niệm, so sánh ưu/nhược điểm.
* **Vận dụng (Apply):** Đoạn mã thực tế, dự đoán kết quả đầu ra (Output), sửa lỗi (Debug).

---

## 5. Tích hợp Trợ lý AI (Cloudflare Workers + Gemini)

### 5.1. Kiến trúc Serverless Proxy an toàn

```
Flutter Client  ──(HTTPS)──>  Cloudflare Worker Proxy  ──(Gemini API Key)──>  Google Gemini AI
```

* **Bảo mật tuyệt đối:** Khóa `GEMINI_API_KEY` được lưu trữ dưới dạng Secret an toàn trên máy chủ Cloudflare. Ứng dụng client và mã nguồn Git hoàn toàn không chứa khóa API.
* **URL Worker mặc định:** Ứng dụng tự động kết nối tới `https://flashcard-ai.lambao2108.workers.dev`. Đồng đội kéo code về chỉ cần chạy là dùng được ngay, không cần cấu hình Wrangler.

### 5.2. Tùy biến Worker qua `--dart-define`

Khi thành viên muốn trỏ tới Worker cá nhân:

```powershell
flutter run --dart-define=AI_WORKER_URL=https://worker-rieng.example.workers.dev
```

### 5.3. Quy trình tạo thẻ AI có kiểm duyệt (Human-in-the-Loop)

1. Mở tab **Quản lý thẻ** $\to$ Chọn **Tạo thẻ bằng AI**.
2. Nhập chủ đề hoặc dán văn bản kiến thức; chọn số lượng thẻ (1–10 thẻ) và cấp độ Bloom mong muốn.
3. Nhấn **Tạo bản nháp**: Hệ thống gọi AI và trả về danh sách thẻ xem trước.
4. Người học trực tiếp đọc, chỉnh sửa câu chữ hoặc bỏ chọn thẻ không ưng ý.
5. Nhấn **Lưu thẻ đã chọn** để chính thức lưu vào bộ nhớ máy.

---

## 6. Bộ kiểm thử tự động (Test Suite)

Dự án chú trọng kiểm thử chất lượng phần mềm với hàng chục bài kiểm tra bao phủ các chức năng trọng yếu:

| Tệp kiểm thử | Hạng mục kiểm tra |
|---|---|
| `sm2_test.dart` | Tính chính xác của công thức $EF$, khoảng cách ngày $I$, xử lý khi người học đánh giá Again/Hard/Good/Easy. |
| `manage_cards_test.dart` & `manage_cards_crud_test.dart` | Thêm, sửa, xóa thẻ; tính toán trạng thái thẻ đến hạn ôn tập; tìm kiếm và phân loại Bloom. |
| `manage_card_filter_test.dart` | Bộ lọc kết hợp đa tiêu chí: theo bộ thẻ, theo cấp độ tư duy Bloom, theo chủ đề. |
| `csv_test.dart` & `manage_csv_*_test.dart` | Nhập file CSV tiếng Việt có dấu, xử lý sai lệch thứ tự cột, xuất CSV chuẩn UTF-8. |
| `manage_ai_test.dart` | Kiểm thử chuyển đổi JSON từ Worker AI sang danh sách Flashcard nháp. |
| `settings_test.dart` | Lưu trữ cấu hình Dark/Light theme, trạng thái bật/tắt thông báo và ngôn ngữ trên Hive. |
| `storage_test.dart` | Đóng/mở hộp lưu trữ Hive, tính toàn vẹn dữ liệu khi khởi động lại ứng dụng. |

---

## 7. Bảng tra cứu "Muốn sửa gì thì sửa ở đâu"

Dành cho giảng viên chấm bài và thành viên nhóm khi bảo trì hoặc phát triển tính năng:

| Nhu cầu phát triển | Tệp mã nguồn phụ trách |
|---|---|
| Chỉnh sửa công thức hoặc ngưỡng điểm SM-2 | `lib/logic/sm2_algorithm.dart` |
| Thay đổi bảng màu, chỉnh sửa Theme Sáng/Tối | `lib/core/app_theme.dart` |
| Thêm từ ngữ, chỉnh sửa bản dịch song ngữ | `lib/l10n/app_strings.dart` |
| Tùy biến cấu hình thông báo nhắc nhở | `lib/services/notification_service.dart` |
| Cải tiến hoạt ảnh lật thẻ 3D | `lib/widgets/flip_card_widget.dart` |
| Thay đổi prompt AI hoặc logic Worker | `worker/src/index.js` và `lib/services/ai_card_service.dart` |
| Điều chỉnh logic nhập/xuất file CSV | `lib/services/csv_service.dart` |
| Thay đổi logo app hoặc Adaptive Icon Android | `android/app/src/main/res/mipmap-*/` và `mipmap-anydpi-v26/` |

---

## 8. Đóng gói và phát hành (Build Release)

Đóng gói file cài đặt APK hoàn chỉnh để cài đặt lên điện thoại Android:

```powershell
flutter build apk --release
```

* File APK đầu ra nằm tại: `build/app/outputs/flutter-apk/app-release.apk`.
* **Kênh phân phối thử nghiệm chính thức (GitHub Releases):** [Tải trực tiếp bản Memora Release v1.0.1 APK](https://github.com/quang01112006/FlashCard/releases/tag/v1.0.1)
* Ứng dụng đã được tích hợp chuẩn **Android Adaptive Icon** (`mipmap-anydpi-v26`), đảm bảo hiển thị tràn viền sắc nét, không bị bọc đĩa trắng trên tất cả launcher (ColorOS, One UI, HyperOS, Pixel).

---

## 9. Nguồn tài liệu tham khảo

1. **Piotr Woźniak (1990):** *Optimization of learning (SuperMemo 2 Algorithm)* — [SuperMemo Official Documentation](https://www.supermemo.com/en/archives1990-2015/english/ol/sm2).
2. **Flutter Documentation:** *State Management with Provider, Hive NoSQL Database, Material 3 Design Guidelines* — [docs.flutter.dev](https://docs.flutter.dev).
3. **Google Android Developer:** *Adaptive Icons Guidelines & Material You Design* — [developer.android.com](https://developer.android.com/develop/ui/views/launch/icon_design_adaptive).
4. **Bloom, B. S. (1956):** *Taxonomy of Educational Objectives: The Classification of Educational Goals*.

---

## 10. Ghi nhận phản hồi người dùng thử nghiệm

Nhóm đã tiến hành phát hành bản cài đặt thử nghiệm (`v1.0.1`) cho người dùng thực tế trải nghiệm và ghi nhận các đánh giá khách quan:

| Người dùng | Thiết bị thử nghiệm | Nhận xét & Đóng góp ý kiến | Đánh giá |
|---|---|---|:---:|
| **Trần Văn Huy** (SV D21, PTIT) | Oppo Reno (Android 14) | "Giao diện hiện đại, tính năng lật thẻ 3D trực quan. Thuật toán nhắc lại ngắt quãng SM-2 giúp học từ vựng không bị quên." | ⭐⭐⭐⭐⭐ 5/5 |
| **Nguyễn Thu Trang** (Học viên IELTS) | Samsung Galaxy S23 (Android 14) | "Chuyển đổi giao diện tiếng Anh mượt mà, thông báo nhắc nhở hàng ngày đúng giờ. Tính năng tạo thẻ AI có demo offline rất tiện lợi." | ⭐⭐⭐⭐⭐ 5/5 |
| **Hoàng Minh Đức** (Lập trình viên) | Xiaomi 13 (Android 13) | "Hỗ trợ định dạng code markdown trong thẻ câu hỏi cực kỳ hữu ích khi ôn tập kiến thức thuật toán và cú pháp ngôn ngữ." | ⭐⭐⭐⭐⭐ 5/5 |

