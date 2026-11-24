/// Chuỗi song ngữ (Việt - Anh) dùng trong luồng nhập/xuất CSV.
class ManageCsvStrings {
  const ManageCsvStrings(this.isEnglish);
  final bool isEnglish;

  // CSV Export Dialog
  String get exportDialogTitle => isEnglish ? 'Export CSV' : 'Xuất CSV';
  String exportDialogContent(int count) => isEnglish
      ? 'Export all $count cards, including Vietnamese–English content, topic and difficulty level. Review schedules will not be exported.'
      : 'Xuất toàn bộ $count thẻ, gồm nội dung Việt–Anh, khối kiến thức và mức độ. Lịch ôn không được xuất.';
  String get chooseSaveLocation =>
      isEnglish ? 'Choose save location' : 'Chọn nơi lưu';
  String get processingCsv => isEnglish ? 'Processing CSV' : 'Đang xử lý CSV';
  String exportedCards(int count) => isEnglish
      ? 'Exported $count cards to CSV file.'
      : 'Đã xuất $count thẻ ra file CSV.';
  String cardsImportedCount(int count) =>
      isEnglish ? 'Imported $count cards.' : 'Đã nhập $count thẻ.';
  String get cannotReadCsv => isEnglish
      ? 'Cannot read CSV file. Please select another file.'
      : 'Không thể đọc file CSV. Vui lòng chọn lại file.';
  String get cannotSaveCsv => isEnglish
      ? 'Cannot save CSV file. Please try again.'
      : 'Không thể lưu file CSV. Vui lòng thử lại.';

  // CSV Mapping Screen
  String get mappingTitle => isEnglish ? 'Map CSV Columns' : 'Ghép cột CSV';
  String get hasHeader =>
      isEnglish ? 'First row is header' : 'Dòng đầu là tiêu đề';
  String get mappingHelp => isEnglish
      ? 'Check detected columns. Only question and answer are required; unmapped columns will be ignored.'
      : 'Kiểm tra các cột được nhận diện. Chỉ câu hỏi và đáp án là bắt buộc; cột không chọn sẽ được bỏ qua.';
  String get noChoice => isEnglish ? 'None' : 'Không chọn';
  String columnLabel(int index, String? sampleName) {
    if (isEnglish) {
      return 'Column ${index + 1}${sampleName != null ? ': $sampleName' : ''}';
    }
    return 'Cột ${index + 1}${sampleName != null ? ': $sampleName' : ''}';
  }

  String sampleColumnLabel(int index, String value) {
    return isEnglish ? 'Column ${index + 1}: $value' : 'Cột ${index + 1}: $value';
  }

  String get sampleDataTitle =>
      isEnglish ? 'Sample data (original content):' : 'Dữ liệu mẫu (nội dung gốc):';
  String get previewCards => isEnglish ? 'Preview cards' : 'Xem trước thẻ';
  String get reading => isEnglish ? 'Reading...' : 'Đang đọc...';
  String get mappingRequiredError => isEnglish
      ? 'Map both question and answer; each column can only be mapped to one field.'
      : 'Chọn đủ câu hỏi, đáp án; mỗi cột chỉ dùng cho một trường.';
  String get readColumnsError => isEnglish
      ? 'Could not read selected columns.'
      : 'Không đọc được các cột đã chọn.';

  String fieldLabel(String key) {
    if (isEnglish) {
      switch (key) {
        case 'front':
          return 'Question';
        case 'back':
          return 'Answer';
        case 'topicCode':
          return 'Topic';
        case 'level':
          return 'Difficulty';
        case 'front_en':
          return 'English question';
        case 'back_en':
          return 'English answer';
      }
    }
    switch (key) {
      case 'front':
        return 'Câu hỏi';
      case 'back':
        return 'Đáp án';
      case 'topicCode':
        return 'Chủ đề';
      case 'level':
        return 'Mức độ';
      case 'front_en':
        return 'Câu hỏi tiếng Anh';
      case 'back_en':
        return 'Đáp án tiếng Anh';
    }
    return key;
  }

  // CSV Import Screen
  String get importPreviewTitle => isEnglish ? 'Preview CSV' : 'Xem trước CSV';
  String validCardsCount(int count) =>
      isEnglish ? '$count valid cards' : '$count thẻ hợp lệ';
  String errorRowsCount(int count) =>
      isEnglish ? '$count error rows' : '$count dòng lỗi';
  String blankRowsCount(int count) =>
      isEnglish ? '$count blank rows' : '$count dòng trống';
  String get importNote => isEnglish
      ? 'Only valid cards will be added to the existing deck with fresh study progress. Importing the same file again will create duplicates.'
      : 'Chỉ các thẻ hợp lệ được thêm vào bộ hiện có, với tiến độ ôn mới. Nhập lại cùng file sẽ tạo thêm bản sao.';
  String get missingDefaultsPrompt => isEnglish
      ? 'Default values for missing fields in file:'
      : 'Bổ sung cho các ô còn thiếu trong file:';
  String get defaultTopic => isEnglish ? 'Default topic' : 'Chủ đề mặc định';
  String get defaultLevel => isEnglish ? 'Default difficulty' : 'Mức độ mặc định';
  String get noValidCards => isEnglish
      ? 'No valid cards to import. Please check your file and try again.'
      : 'Không có thẻ hợp lệ để nhập. Hãy kiểm tra file rồi chọn lại.';
  String get unimportedRowsTitle =>
      isEnglish ? 'Rows not imported' : 'Các dòng không được nhập';
  String rowErrorTitle(int line) => isEnglish ? 'Row $line' : 'Dòng $line';
  String get cardsToImportTitle =>
      isEnglish ? 'Cards to import' : 'Thẻ sẽ được nhập';
  String get importCardsButton => isEnglish ? 'Import cards' : 'Nhập thẻ';
  String get importingButton => isEnglish ? 'Importing...' : 'Đang nhập...';
  String get importFailed => isEnglish
      ? 'Could not import cards. Please try again.'
      : 'Không thể nhập thẻ. Vui lòng thử lại.';

  String csvError(String msg) {
    if (!isEnglish) return msg;
    const map = {
      'Vui lòng chọn file có đuôi .csv.':
          'Please select a file with .csv extension.',
      'File vượt quá 5 MB.': 'File exceeds 5 MB.',
      'File vượt quá 5 MB. Vui lòng chia thành file nhỏ hơn.':
          'File exceeds 5 MB. Please split into smaller files.',
      'Không đọc được tiếng Việt trong file. Hãy lưu file ở dạng CSV UTF-8.':
          'Could not read Vietnamese characters in file. Please save as UTF-8 CSV.',
      'Hãy chọn các cột riêng biệt cho câu hỏi và đáp án.':
          'Please select separate columns for question and answer.',
      'Dòng tiêu đề cần đủ hai cột front,back hoặc Mặt trước,Mặt sau.':
          'Header row must include both front,back or Question,Answer.',
      'Dấu ngoặc kép không đúng định dạng CSV.':
          'Quotes are not in valid CSV format.',
      'Thiếu dấu ngoặc kép đóng; không thể tách an toàn các dòng còn lại.':
          'Missing closing quote; cannot safely parse remaining rows.',
      'Thiếu câu hỏi hoặc đáp án.': 'Missing question or answer.',
      'Mức độ phải là Nhớ, Hiểu hoặc Vận dụng.':
          'Difficulty must be Remember, Understand, or Apply.',
    };
    return map[msg] ?? msg;
  }
}
