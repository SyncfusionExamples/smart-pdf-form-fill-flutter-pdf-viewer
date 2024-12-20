import 'dart:io';

import 'package:path_provider/path_provider.dart';

///To save the pdf file in the device
class FileSaveHelper {
  ///To save the pdf file in the device
  static Future<String> saveFile(List<int> bytes, String fileName) async {
    final Directory directory = await getApplicationSupportDirectory();
    final File file =
        File('${directory.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  }
}
