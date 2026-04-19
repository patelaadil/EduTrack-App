import 'dart:io';
import 'dart:typed_data';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

Future<String?> saveQrCodeImage(Uint8List bytes, String fileName) async {
  final dir = await getApplicationDocumentsDirectory();
  final qrDir = Directory('${dir.path}/qrs');
  if (!await qrDir.exists()) {
    await qrDir.create(recursive: true);
  }

  final file = File('${qrDir.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  await OpenFilex.open(file.path);
  return file.path;
}
