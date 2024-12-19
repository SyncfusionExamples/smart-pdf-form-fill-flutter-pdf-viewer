import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

///To save the pdf file in the device
class FileSaveHelper {
  ///To save the pdf file in the device
  static Future<void> saveFile(List<int> bytes, String fileName) async {
    String? path;
    if (Platform.isIOS || Platform.isLinux || Platform.isWindows) {
      final Directory directory = await getApplicationSupportDirectory();
      path = directory.path;
    } else if (Platform.isAndroid) {
      final Directory? directory = await getExternalStorageDirectory();
      if (directory != null) {
        path = directory.path;
      } else {
        final Directory directory = await getApplicationSupportDirectory();
        path = directory.path;
      }
    } else {
      path = await PathProviderPlatform.instance.getApplicationSupportPath();
    }
    final File file = File('$path${Platform}$fileName');
    await file.writeAsBytes(bytes, flush: true);
  }
}
