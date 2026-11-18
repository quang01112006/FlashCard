/// Chữ dùng trong luồng tạo/chỉnh thẻ AI. Dùng cờ ngôn ngữ chung của controller.
class ManageAiStrings {
  const ManageAiStrings(this.isEnglish);
  final bool isEnglish;

  String text(String vietnamese) =>
      isEnglish ? (_english[vietnamese] ?? vietnamese) : vietnamese;
  String error(String message) {
    if (!isEnglish) return message;
    if (message.startsWith('Không thể tạo thẻ AI (HTTP ')) {
      final status = RegExp(r'HTTP (\d+)').firstMatch(message)?.group(1);
      return 'Could not generate AI cards (HTTP $status). Please try again later.';
    }
    return _english[message] ?? 'The operation failed. Please try again.';
  }

  String deck(String name) => '${text('Bộ nhận:')} $name';
  String count(int count) => isEnglish ? '$count cards' : '$count thẻ';
  String selected(int count, int total) =>
      isEnglish ? '$count/$total cards selected' : 'Đã chọn $count/$total thẻ';
  String save(int count) =>
      isEnglish ? 'Save $count selected cards' : 'Lưu $count thẻ đã chọn';
  String saved(int count) =>
      isEnglish ? 'Saved $count cards.' : 'Đã lưu $count thẻ.';
  String requiredField(String label) => isEnglish
      ? 'Please enter ${label.toLowerCase()}.'
      : 'Vui lòng nhập ${label.toLowerCase()}.';
  String invalidChoice(String label) => isEnglish
      ? 'Please select a valid ${label.toLowerCase()}.'
      : 'Vui lòng chọn ${label.toLowerCase()} hợp lệ.';

  static const _english = {
    'Tạo thẻ AI': 'Create cards with AI',
    'Xem trước thẻ': 'Preview cards',
    'Bộ nhận:': 'Destination deck:',
    'Bộ thẻ không còn tồn tại': 'This deck no longer exists',
    'Nội dung có thể chưa chính xác. Hãy kiểm tra và chỉnh sửa trước khi dùng để học.':
        'AI content may be inaccurate. Review and edit it before studying.',
    'Chủ đề hoặc kiến thức': 'Topic or study material',
    'Ví dụ: các kỹ thuật luộc trứng':
        'For example: techniques for boiling eggs',
    'Vui lòng nhập chủ đề hoặc kiến thức.':
        'Please enter a topic or study material.',
    'Số thẻ': 'Number of cards',
    'Mức độ': 'Difficulty',
    'Nhớ': 'Remember',
    'Hiểu': 'Understand',
    'Vận dụng': 'Apply',
    'Tạo thêm bản tiếng Anh': 'Include English translations',
    'Đang tạo...': 'Generating...',
    'Tạo bản nháp': 'Generate drafts',
    'Hãy kiểm tra và chỉnh sửa nội dung AI trước khi lưu.':
        'Review and edit the AI content before saving.',
    'Đổi yêu cầu': 'Change request',
    'Chỉnh thẻ': 'Edit card',
    'Câu hỏi': 'Question',
    'Đáp án': 'Answer',
    'Câu hỏi tiếng Anh': 'English question',
    'Đáp án tiếng Anh': 'English answer',
    'Đang lưu...': 'Saving...',
    'Lưu thẻ': 'Save card',
    'Bỏ bản nháp?': 'Discard drafts?',
    'Các thẻ chưa lưu sẽ bị bỏ.': 'Unsaved cards will be discarded.',
    'Tiếp tục xem': 'Keep reviewing',
    'Bỏ bản nháp': 'Discard drafts',
    'Không thể tạo bản nháp. Vui lòng thử lại.':
        'Could not generate drafts. Please try again.',
    'Không thể lưu thẻ. Vui lòng thử lại.':
        'Could not save cards. Please try again.',
    'Chưa cấu hình địa chỉ dịch vụ AI.':
        'The AI service address has not been configured.',
    'Đã đạt giới hạn yêu cầu. Vui lòng chờ rồi thử lại.':
        'Request limit reached. Please wait and try again.',
    'Gemini đang tạm thời quá tải hoặc không khả dụng. Hãy chờ một lúc rồi thử lại.':
        'Gemini is temporarily busy or unavailable. Please wait and try again.',
    'Khu vực máy chủ AI hiện chưa được Gemini hỗ trợ. Cần kiểm tra vị trí dịch vụ.': 'Gemini does not support the current server region. Check the service location.',
    'Dịch vụ AI chưa được cấu hình đầy đủ trên Cloudflare.':
        'The AI service configuration on Cloudflare is incomplete.',
    'Khóa Gemini trên dịch vụ AI không hợp lệ.':
        'The Gemini API key on the AI service is invalid.',
    'Gemini từ chối truy cập. Cần kiểm tra quyền của khóa API.':
        'Gemini denied access. Check the API key permissions.',
    'Model Gemini đang cấu hình không khả dụng.':
        'The configured Gemini model is unavailable.',
    'Gemini không chấp nhận yêu cầu. Cần kiểm tra cấu hình dịch vụ AI.':
        'Gemini rejected the request. Check the AI service configuration.',
    'Gemini chưa trả về đủ thẻ hợp lệ. Hãy thử lại với ít thẻ hơn.':
        'Gemini did not return enough valid cards. Try requesting fewer cards.',
    'Kết nối AI quá lâu. Vui lòng thử lại.':
        'The AI request timed out. Please try again.',
    'Dữ liệu AI trả về không hợp lệ. Vui lòng thử lại.':
        'The AI response is invalid. Please try again.',
    'Không thể kết nối dịch vụ AI. Kiểm tra mạng rồi thử lại.': 'Could not connect to the AI service. Check your connection and try again.',
    'Thêm thẻ': 'Add card',
    'Sửa thẻ': 'Edit card',
    'Bỏ thay đổi?': 'Discard changes?',
    'Nội dung bạn vừa nhập chưa được lưu.': 'Your changes have not been saved.',
    'Tiếp tục nhập': 'Keep editing',
    'Bỏ thay đổi': 'Discard changes',
    'Đáp án & giải thích': 'Answer and explanation',
    'Nhóm trong bộ (tùy chọn)': 'Group in deck (optional)',
    'Tiếng Anh (tùy chọn)': 'English (optional)',
    'Chọn gợi ý hoặc nhập tên chủ đề mới.':
        'Select a suggestion or enter a new topic.',
  };
}
