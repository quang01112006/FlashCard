import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flashcard_sm2/services/csv_service.dart';
import 'package:flashcard_sm2/services/manage_csv_files.dart';
import 'package:flutter_test/flutter_test.dart';

base class _File extends PlatformFile {
  _File(this.name, this.bytes, {this.reportedLength});
  @override
  final String name;
  final Uint8List bytes;
  final int? reportedLength;
  bool wasRead = false;
  @override
  Uri get uri => Uri.parse('content://test/$name');
  @override
  Never get xFile => throw UnimplementedError();
  @override
  int? lengthSync() => reportedLength;
  @override
  Future<int?> length() async => reportedLength;
  @override
  Future<Uint8List> readAsBytes() async {
    wasRead = true;
    return bytes;
  }

  @override
  Stream<Uint8List> readAsByteStream() async* {
    wasRead = true;
    yield bytes;
  }
}

class _Picker extends FilePickerPlatform {
  PlatformFile? picked;
  Uint8List? savedBytes;
  String? savedName;
  String? savedMime;
  Uri? destination;
  FileType? pickedType;
  List<String>? extensions;
  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    pickedType = type;
    extensions = allowedExtensions;
    return picked;
  }

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    savedName = fileName;
    savedBytes = bytes;
    savedMime = mimeType;
    return destination;
  }
}

void main() {
  late FilePickerPlatform original;
  late _Picker picker;
  setUp(() {
    original = FilePickerPlatform.instance;
    picker = _Picker();
    FilePickerPlatform.instance = picker;
  });
  tearDown(() => FilePickerPlatform.instance = original);

  test(
    'Chọn file qua API hiện có, đọc bytes từ content URI và xử lý hủy',
    () async {
      final service = NativeManageCsvFiles();
      expect(await service.pick(), isNull);
      picker.picked = _File('DATA.CSV', Uint8List.fromList([1, 2, 3]));
      final file = (await service.pick())!;
      expect(picker.pickedType, FileType.custom);
      expect(picker.extensions, ['csv']);
      expect(file.name, 'DATA.CSV');
      expect(file.bytes, [1, 2, 3]);
    },
  );

  test('Chặn sai đuôi và file quá lớn trước khi đọc; kiểm tra lại kích thước bytes', () async {
    final service = NativeManageCsvFiles();
    final wrong = _File('wrong.txt', Uint8List(0));
    picker.picked = wrong;
    await expectLater(service.pick(), throwsA(isA<CsvFileException>()));
    expect(wrong.wasRead, isFalse);
    final tooLarge = _File(
      'big.csv',
      Uint8List(0),
      reportedLength: CsvService.maxFileBytes + 1,
    );
    picker.picked = tooLarge;
    await expectLater(service.pick(), throwsA(isA<CsvFileException>()));
    expect(tooLarge.wasRead, isFalse);
    picker.picked = _File(
      'unknown-size.csv',
      Uint8List(CsvService.maxFileBytes + 1),
    );
    await expectLater(service.pick(), throwsA(isA<CsvFileException>()));
  });

  test('Xuất truyền đúng bytes, tên file, MIME và kết quả hủy/lưu', () async {
    final service = NativeManageCsvFiles();
    final bytes = CsvService.exportBytes([]);
    expect(await service.save(bytes, suggestedName: 'test.csv'), isNull);
    picker.destination = Uri.parse('content://documents/flashcards.csv');
    expect(
      await service.save(bytes, suggestedName: 'test.csv'),
      picker.destination,
    );
    expect(picker.savedBytes, bytes);
    expect(picker.savedName, 'test.csv');
    expect(picker.savedMime, 'text/csv');
  });
}
