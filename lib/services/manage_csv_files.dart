import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'csv_service.dart';

class ManageCsvFile {
  const ManageCsvFile({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
}

abstract interface class ManageCsvFiles {
  Future<ManageCsvFile?> pick();
  Future<Uri?> save(Uint8List bytes, {required String suggestedName});
}

class NativeManageCsvFiles implements ManageCsvFiles {
  @override
  Future<ManageCsvFile?> pick() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Chọn file CSV',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (file == null) return null;
    if (!file.name.toLowerCase().endsWith('.csv')) {
      throw const CsvFileException('Vui lòng chọn file có đuôi .csv.');
    }
    final length = file.lengthSync();
    if (length != null && length > CsvService.maxFileBytes) {
      throw const CsvFileException(
        'File vượt quá 5 MB. Vui lòng chia thành file nhỏ hơn.',
      );
    }
    final buffer = BytesBuilder(copy: false);
    await for (final chunk in file.readAsByteStream()) {
      if (buffer.length + chunk.length > CsvService.maxFileBytes) {
        throw const CsvFileException(
          'File vượt quá 5 MB. Vui lòng chia thành file nhỏ hơn.',
        );
      }
      buffer.add(chunk);
    }
    return ManageCsvFile(name: file.name, bytes: buffer.takeBytes());
  }

  @override
  Future<Uri?> save(Uint8List bytes, {required String suggestedName}) =>
      FilePicker.saveFile(
        fileName: suggestedName,
        bytes: bytes,
        mimeType: 'text/csv',
        dialogTitle: 'Lưu bộ thẻ CSV',
      );
}
