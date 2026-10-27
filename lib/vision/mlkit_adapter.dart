import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'ocr_models.dart';
import 'quad.dart';

Quad _quadOf(List<math.Point<int>> corners, Rect box) => corners.length == 4
    ? Quad.fromPoints([
        for (final p in corners) Offset(p.x.toDouble(), p.y.toDouble()),
      ])
    : Quad.fromRect(box);

List<OcrLine> ocrLinesFrom(RecognizedText text) => [
  for (final block in text.blocks)
    for (final line in block.lines)
      OcrLine(line.text, _quadOf(line.cornerPoints, line.boundingBox), [
        for (final e in line.elements)
          OcrElement(e.text, _quadOf(e.cornerPoints, e.boundingBox)),
      ]),
];

const _orientationDegrees = {
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

/// A camera frame ready for ML Kit plus the coordinate space its results come
/// back in, which depends on platform and sensor rotation.
class CameraFrameInput {
  const CameraFrameInput(this.inputImage, this.resultSpace, this.mirrorX);

  final InputImage inputImage;
  final Size resultSpace;
  final bool mirrorX;

  static ImageFormatGroup get preferredFormat =>
      Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888;

  static CameraFrameInput? fromCameraImage(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) {
    final sensor = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensor);
    } else if (Platform.isAndroid) {
      final compensation = _orientationDegrees[deviceOrientation];
      if (compensation == null) return null;
      final degrees = camera.lensDirection == CameraLensDirection.front
          ? (sensor + compensation) % 360
          : (sensor - compensation + 360) % 360;
      rotation = InputImageRotationValue.fromRawValue(degrees);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    final w = image.width.toDouble();
    final h = image.height.toDouble();
    final sideways =
        rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg;
    // Android reports results in the rotated (upright) frame; iOS keeps the
    // buffer's own width/height.
    final resultSpace = sideways && Platform.isAndroid
        ? Size(h, w)
        : Size(w, h);
    final mirrorX = switch (rotation) {
      InputImageRotation.rotation270deg => true,
      InputImageRotation.rotation90deg => false,
      _ => camera.lensDirection == CameraLensDirection.front,
    };

    return CameraFrameInput(
      InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(w, h),
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      ),
      resultSpace,
      mirrorX,
    );
  }
}
