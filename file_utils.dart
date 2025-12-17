// lib/helpers/file_utils.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Save bytes (or an existing file) into the app documents directory
/// and return the absolute local path.
Future<String> saveFileToAppDir({required List<int> bytes, required String originalName}) async {
  final docs = await getApplicationDocumentsDirectory();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final safeName = originalName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final filename = '$timestamp\_$safeName';
  final file = File(p.join(docs.path, filename));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<String> copyFileToAppDir(File sourceFile) async {
  final docs = await getApplicationDocumentsDirectory();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final safeName = p.basename(sourceFile.path).replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final dest = File(p.join(docs.path, '$timestamp\_$safeName'));
  return await sourceFile.copy(dest.path).then((f) => f.path);
}
