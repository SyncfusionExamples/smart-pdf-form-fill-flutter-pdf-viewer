import 'dart:async';
import 'dart:convert';

import 'package:web/web.dart';

class FileSaveHelper {
  ///To download the pdf file to the device
  static Future<void> saveFile(List<int> bytes, String fileName) async {
    HTMLAnchorElement()
      ..href =
          'data:application/octet-stream;charset=utf-16le;base64,${base64.encode(bytes)}'
      ..setAttribute('download', fileName)
      ..click();
  }
}
