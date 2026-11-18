# File mẫu để thử nhập/xuất CSV

Trong tab **Bộ thẻ**, mở nút **Nhập / xuất CSV** cạnh dấu **+**.

Luồng nhập: chọn file → xác nhận dòng tiêu đề và ghép cột → xem trước/chỉnh riêng từng thẻ → xác nhận nhập. Tên cột quen thuộc như Trước/Sau, Câu hỏi/Trả lời, Question/Answer được nhận diện sẵn. Tên lạ hoặc trùng nghĩa cần chọn cột thủ công. Khi file không có tiêu đề, bỏ chọn **Dòng đầu là tiêu đề** để giữ dòng dữ liệu đầu tiên.

Chủ đề có thể là mã K01–K20, K99 hoặc tên như Nấu ăn/Chơi game. Chọn chung chỉ bổ sung các ô còn thiếu. Muốn sửa riêng một thẻ, mở thẻ trong màn xem trước và chọn **Chỉnh thẻ trước khi nhập**; thao tác này chưa ghi vào bộ thẻ.

Các file mẫu dùng UTF-8 có BOM để Excel nhận đúng tiếng Việt khi mở trực tiếp. Khi sửa bằng Excel, chọn **CSV UTF-8 (Comma delimited)** khi lưu.

- `flashcards_basic.csv`: 2 thẻ, chỉ có Mặt trước/Mặt sau. Chọn chủ đề và mức độ ở màn xem trước.
- `flashcards_bilingual.csv`: 2 thẻ có chủ đề, mức độ và tiếng Anh; có ví dụ code chứa dấu phẩy, ngoặc kép và xuống dòng.
- `flashcards_with_errors.csv`: 1 thẻ hợp lệ và 3 dòng lỗi. Xem trước sẽ báo lỗi; nút xác nhận chỉ nhập 1 thẻ hợp lệ.
- `flashcards_custom_topics.csv`: 3 thẻ thuộc Nấu ăn, Chơi game và K99, có mức độ riêng từng dòng.
- `flashcards_unusual_columns.csv`: chọn có tiêu đề; ghép câu hỏi với Prompt, đáp án với Response, chủ đề với Group; bỏ qua Note. Nhập được 2 thẻ.

CSV xuất có các cột `front,back,topicCode,level,front_en,back_en` và được lưu ở dạng UTF-8 có BOM. Nhập chấp nhận dấu phẩy hoặc dấu chấm phẩy. File không có tiêu đề cần ít nhất hai cột; chọn cột câu hỏi/đáp án và các cột tùy chọn ở bước ghép cột. Các cột `front` và `back` có thể ghi là `Mặt trước` và `Mặt sau`.

Nội dung chứa dấu phân cách, dấu ngoặc kép hoặc xuống dòng phải đặt trong dấu ngoặc kép; dấu `"` bên trong được viết thành `""`. File được giới hạn 5 MB.

Thẻ nhập luôn có ID mới và tiến độ ôn ban đầu. Nhập lại một file tạo thêm bản sao, không cập nhật thẻ cũ. CSV dùng để trao đổi nội dung, không sao lưu lịch ôn. Khi xuất, ứng dụng lấy toàn bộ bộ thẻ, kể cả khi đang tìm kiếm hoặc lọc.

Để kiểm tra xuất rồi nhập lại, nên dùng bộ thẻ thử nghiệm trên thiết bị/emulator riêng. Sau khi nhập, đóng và mở lại app để kiểm tra dữ liệu được giữ.
