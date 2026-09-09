import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// 人脸 5 点对齐（self-identity #017 修复）。
///
/// MobileFaceNet 是按「关键点对齐到 canonical 112×112」训练的：双眼水平、
/// 鼻尖嘴角落到标准坐标。直接裁人脸框会让偏头/侧脸/取景差异传导进 embedding，
/// 同一个人嵌入大幅漂移 → 本人分被压低、陌生人分被抬高、阈值调不开。
/// 这里用 ML Kit 给的 5 点（双眼/鼻尖/嘴角）求相似变换，把任意姿态的
/// 人脸对齐回模型训练时的标准空间，再采样出 112×112。
///
/// 变换估计 = skimage SimilarityTransform 同款最小二乘（均匀缩放 + 旋转 +
/// 平移，无切变）；逆变换 + 双线性采样生成输出图。
const List<List<double>> kRefPoints = [
  [38.2946, 51.6963], // 左眼
  [73.5318, 51.5014], // 右眼
  [56.0252, 71.7366], // 鼻尖
  [41.5493, 92.3655], // 左嘴角
  [70.7299, 92.2041], // 右嘴角
];

/// 相似变换 [a, b, tx, ty]：p_dst = [[a,-b],[b,a]]·p_src + (tx,ty)。
/// 退化（源点重合，c3=0）→ 返回恒等变换。
List<double> estimateSimilarityTransform(
  List<math.Point<double>> src,
  List<List<double>> dst,
) {
  final n = math.min(src.length, dst.length);
  if (n == 0) return const [1, 0, 0, 0];
  var sxc = 0.0, syc = 0.0, dxc = 0.0, dyc = 0.0;
  for (var i = 0; i < n; i++) {
    sxc += src[i].x;
    syc += src[i].y;
    dxc += dst[i][0];
    dyc += dst[i][1];
  }
  sxc /= n;
  syc /= n;
  dxc /= n;
  dyc /= n;
  // 去均值后的 2D 协方差：c1=点积和（缩放+旋转主项），c2=叉积和（旋转方向），
  // c3=源范数平方。a=c1/c3, b=c2/c3 → 均匀缩放+旋转的最优解。
  var c1 = 0.0, c2 = 0.0, c3 = 0.0;
  for (var i = 0; i < n; i++) {
    final ux = src[i].x - sxc, uy = src[i].y - syc;
    final vx = dst[i][0] - dxc, vy = dst[i][1] - dyc;
    c1 += ux * vx + uy * vy;
    c2 += ux * vy - uy * vx;
    c3 += ux * ux + uy * uy;
  }
  if (c3 < 1e-9) return const [1, 0, 0, 0];
  final a = c1 / c3, b = c2 / c3;
  final tx = dxc - (a * sxc - b * syc);
  final ty = dyc - (b * sxc + a * syc);
  return [a, b, tx, ty];
}

/// 用 [src]（人脸 5 点，原图坐标）做相似变换，把 [full] 对齐到
/// [size]×[size] canonical 人脸图。s² 过小（变换退化）→ null，调用方回退 bbox 裁剪。
img.Image? alignFaceToCanonical(
  img.Image full,
  List<math.Point<double>> src, {
  int size = 112,
  List<List<double>>? ref,
}) {
  final target = ref ?? kRefPoints;
  final t = estimateSimilarityTransform(src, target);
  final a = t[0], b = t[1], tx = t[2], ty = t[3];
  final s2 = a * a + b * b;
  if (s2 < 1e-9) return null;
  // 源点退化（全部重合）时相似变换无意义 → null，调用方走 bbox 裁剪兜底
  if (src.length >= 2) {
    final fx0 = src.first.x, fy0 = src.first.y;
    var spread = 0.0;
    for (final p in src) {
      spread = math.max(spread, (p.x - fx0).abs() + (p.y - fy0).abs());
    }
    if (spread < 1e-3) return null;
  }
  final out = img.Image(width: size, height: size, numChannels: 3);
  // 逆变换采样：p_src = Rᵀ·(p_dst − t) / s²
  for (var u = 0; u < size; u++) {
    for (var v = 0; v < size; v++) {
      final ox = u - tx, oy = v - ty;
      final sx = (a * ox + b * oy) / s2;
      final sy = (-b * ox + a * oy) / s2;
      final (r, g, bl) = _sampleBilinear(full, sx, sy);
      out.setPixelRgb(u, v, r, g, bl);
    }
  }
  return out;
}

/// 双线性采样（坐标越界 clamp 到边缘）。
(int, int, int) _sampleBilinear(img.Image src, double x, double y) {
  int cx(int v) => v < 0 ? 0 : (v > src.width - 1 ? src.width - 1 : v);
  int cy(int v) => v < 0 ? 0 : (v > src.height - 1 ? src.height - 1 : v);
  final x0 = x.floor(), y0 = y.floor();
  final fx = x - x0, fy = y - y0;
  final p00 = src.getPixel(cx(x0), cy(y0));
  final p10 = src.getPixel(cx(x0 + 1), cy(y0));
  final p01 = src.getPixel(cx(x0), cy(y0 + 1));
  final p11 = src.getPixel(cx(x0 + 1), cy(y0 + 1));
  double mix(num a, num b, num c, num d) =>
      a * (1 - fx) * (1 - fy) + b * fx * (1 - fy) + c * (1 - fx) * fy + d * fx * fy;
  final r = mix(p00.r, p10.r, p01.r, p11.r).round().clamp(0, 255).toInt();
  final g = mix(p00.g, p10.g, p01.g, p11.g).round().clamp(0, 255).toInt();
  final bl = mix(p00.b, p10.b, p01.b, p11.b).round().clamp(0, 255).toInt();
  return (r, g, bl);
}
