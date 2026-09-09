import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

/// 头像/聊天背景上传前的标准成品。
///
/// 不沿用相册文件名或 MIME：裁剪组件可能把 JPG 实际转换成 PNG，如果仍声明
/// image/jpeg，服务端返回的 Content-Type 会和真实字节冲突，部分 Android 解码器
/// 会直接显示空白。
class NormalizedMediaUpload {
  const NormalizedMediaUpload({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final String fileName;
  final String mimeType;
  final int width;
  final int height;

  double get aspect => width / height;
}

/// 把相册来源统一成裁剪组件稳定支持的 PNG，并烘焙 EXIF 方向。
///
/// 常见 JPG/PNG/WebP 先由 package:image 处理；HEIC/HEIF 等平台原生可解码
/// 格式走 Flutter 引擎兜底，再转 PNG。图片选择器已负责第一次限边，这里仍做
/// 2048px 保护，避免超大照片在裁剪页占用过多内存。
Future<Uint8List> prepareImageForCropping(Uint8List source) async {
  if (source.isEmpty) throw const FormatException('图片内容为空');

  final decoded = _tryDecode(source);
  if (decoded != null) {
    final oriented = img.bakeOrientation(decoded);
    final resized = _resizeToFit(oriented, maxWidth: 2048, maxHeight: 2048);
    return Uint8List.fromList(img.encodePng(resized, level: 6));
  }

  // HEIC/HEIF 等由 Android/iOS 图片解码器处理。
  ui.Codec? codec;
  ui.Image? frameImage;
  try {
    codec = await ui.instantiateImageCodec(source);
    final frame = await codec.getNextFrame();
    frameImage = frame.image;
    final data = await frameImage.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw const FormatException('图片转换失败');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } on Object catch (error) {
    throw FormatException('不支持或已损坏的图片格式：$error');
  } finally {
    frameImage?.dispose();
    codec?.dispose();
  }
}

/// 统一裁剪成品与上传声明：
/// - 头像：1:1 方图 PNG（保留透明图兼容性），最长边 1024；
/// - 背景：竖屏裁剪结果 JPEG，最长边 2560，减少手机和后端存储压力。
NormalizedMediaUpload normalizeCroppedMedia(
  Uint8List cropped, {
  required bool isAvatar,
}) {
  final decoded = _tryDecode(cropped);
  if (decoded == null) throw const FormatException('裁剪结果不是有效图片');
  var image = img.bakeOrientation(decoded);

  if (isAvatar) {
    // 即便未来替换裁剪组件，也在数据边界强制方图，避免圆图/长图污染所有头像入口。
    if (image.width != image.height) {
      final side = image.width < image.height ? image.width : image.height;
      image = img.copyCrop(
        image,
        x: (image.width - side) ~/ 2,
        y: (image.height - side) ~/ 2,
        width: side,
        height: side,
      );
    }
    image = _resizeToFit(image, maxWidth: 1024, maxHeight: 1024);
    return NormalizedMediaUpload(
      bytes: Uint8List.fromList(img.encodePng(image, level: 6)),
      fileName: 'character-avatar.png',
      mimeType: 'image/png',
      width: image.width,
      height: image.height,
    );
  }

  image = _resizeToFit(image, maxWidth: 1440, maxHeight: 2560);
  return NormalizedMediaUpload(
    bytes: Uint8List.fromList(img.encodeJpg(image, quality: 90)),
    fileName: 'character-chat-background.jpg',
    mimeType: 'image/jpeg',
    width: image.width,
    height: image.height,
  );
}

img.Image? _tryDecode(Uint8List bytes) {
  try {
    return img.decodeImage(bytes);
  } on Object {
    // 个别 image 解码器会在极短或损坏字节上抛 RangeError，而不是返回 null。
    // 对调用方统一表现为“不支持/无效格式”。
    return null;
  }
}

img.Image _resizeToFit(
  img.Image source, {
  required int maxWidth,
  required int maxHeight,
}) {
  final widthScale = maxWidth / source.width;
  final heightScale = maxHeight / source.height;
  final scale = widthScale < heightScale ? widthScale : heightScale;
  if (scale >= 1) return source;
  return img.copyResize(
    source,
    width: (source.width * scale).round(),
    height: (source.height * scale).round(),
    interpolation: img.Interpolation.cubic,
  );
}
