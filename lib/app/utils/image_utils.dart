import 'dart:io';
import 'package:image/image.dart' as img;

Future<File> minifyImage(File imageFile, {int width = 64}) async {
  final cmd = img.Command()
    ..decodeImageFile(imageFile.path)
    ..copyResize(width: width)
    ..writeToFile(imageFile.path);
  await cmd.executeThread();
  return imageFile;
}