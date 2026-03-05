import 'dart:io';
import 'package:image/image.dart';

/// Pads and scales the existing 2048 PNG into a transparent 2048x2048 foreground
/// suitable for adaptive icons. Usage:
///   dart run tools/pad_icon.dart [scale]
/// Example: dart run tools/pad_icon.dart 0.7

void main(List<String> args) {
  final srcPath = 'assets/images/logo_2048.png';
  final outPath = 'assets/images/icon_foreground.png';
  final scale = args.isNotEmpty ? double.tryParse(args[0]) ?? 0.7 : 0.7;
  final canvasSize = 2048;

  final srcFile = File(srcPath);
  if (!srcFile.existsSync()) {
    stderr.writeln('Source not found: $srcPath');
    exit(2);
  }

  final src = decodeImage(srcFile.readAsBytesSync());
  if (src == null) {
    stderr.writeln('Failed to decode PNG: $srcPath');
    exit(3);
  }

  // Compute target size while preserving aspect ratio
  final targetW = (canvasSize * scale).round();
  final targetH = (src.height * targetW / src.width).round();

  final resized = copyResize(src, width: targetW, height: targetH, interpolation: Interpolation.cubic);

  // Create transparent canvas with 4 channels (RGBA). Pixels default to 0 => transparent.
  final canvas = Image(width: canvasSize, height: canvasSize, numChannels: 4);

  final dx = ((canvasSize - resized.width) / 2).round();
  final dy = ((canvasSize - resized.height) / 2).round();

  // Composite resized onto center of canvas
  compositeImage(canvas, resized, dstX: dx, dstY: dy, blend: BlendMode.direct);

  final outFile = File(outPath);
  outFile.createSync(recursive: true);
  outFile.writeAsBytesSync(encodePng(canvas));
  stdout.writeln('Wrote padded foreground: $outPath (scale=${scale.toStringAsFixed(2)})');
}
