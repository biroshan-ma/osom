import 'dart:io';
import 'package:image/image.dart';

void main(List<String> args) {
  final inputPath = 'assets/images/logo_2048.png';
  final out512 = 'assets/images/play_store_icon_512.png';
  final outFeature = 'assets/images/feature_graphic_1024x500.png';

  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    stderr.writeln('Input file not found: $inputPath');
    exit(2);
  }

  final bytes = inputFile.readAsBytesSync();
  final image = decodeImage(bytes);
  if (image == null) {
    stderr.writeln('Failed to decode image: $inputPath');
    exit(3);
  }

  // Create 512x512 icon (fit and pad if needed)
  final icon512 = copyResize(image, width: 512, height: 512, interpolation: Interpolation.cubic);
  final outIcon512 = File(out512);
  outIcon512.createSync(recursive: true);
  outIcon512.writeAsBytesSync(encodePng(icon512));
  stdout.writeln('Wrote $out512');

  // Create feature graphic 1024x500
  // First resize to width 1024 preserving aspect ratio
  final resizedWidth1024 = copyResize(image, width: 1024, interpolation: Interpolation.cubic);

  // If resized height >= 500, center-crop to 1024x500
  Image feature;
  if (resizedWidth1024.height >= 500) {
    final startY = ((resizedWidth1024.height - 500) / 2).round();
    feature = copyCrop(resizedWidth1024, 0, startY, 1024, 500);
  } else {
    // If height is less than 500 (unlikely for source 2048x2048), pad vertically
    feature = Image(1024, 500);
    // Fill with transparent
    fill(feature, getColor(0, 0, 0, 0));
    final offsetY = ((500 - resizedWidth1024.height) / 2).round();
    copyInto(feature, resizedWidth1024, dstX: 0, dstY: offsetY);
  }

  final outFeatureFile = File(outFeature);
  outFeatureFile.createSync(recursive: true);
  outFeatureFile.writeAsBytesSync(encodePng(feature));
  stdout.writeln('Wrote $outFeature');
}
