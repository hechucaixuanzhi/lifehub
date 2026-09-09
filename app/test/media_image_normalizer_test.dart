import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lifehub/features/ai/services/media_image_normalizer.dart';

void main() {
  test('avatar is square PNG with matching metadata', () {
    final source = img.Image(width: 120, height: 80);
    img.fill(source, color: img.ColorRgb8(20, 120, 220));

    final result = normalizeCroppedMedia(
      Uint8List.fromList(img.encodePng(source)),
      isAvatar: true,
    );

    expect(result.mimeType, 'image/png');
    expect(result.fileName, endsWith('.png'));
    expect(result.bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(result.width, 80);
    expect(result.height, 80);
    expect(result.aspect, 1);
  });

  test('chat background is JPEG with matching metadata and aspect', () {
    final source = img.Image(width: 90, height: 160);
    img.fill(source, color: img.ColorRgb8(240, 180, 80));

    final result = normalizeCroppedMedia(
      Uint8List.fromList(img.encodePng(source)),
      isAvatar: false,
    );

    expect(result.mimeType, 'image/jpeg');
    expect(result.fileName, endsWith('.jpg'));
    expect(result.bytes.take(2), [0xFF, 0xD8]);
    expect(result.width, 90);
    expect(result.height, 160);
    expect(result.aspect, closeTo(9 / 16, 0.0001));
  });

  test('invalid cropped bytes are rejected before upload', () {
    expect(
      () =>
          normalizeCroppedMedia(Uint8List.fromList([1, 2, 3]), isAvatar: true),
      throwsFormatException,
    );
  });
}
