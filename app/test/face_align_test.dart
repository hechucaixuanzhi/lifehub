import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lifehub/features/ai/services/face_align.dart';

/// 验证 5 点相似变换数学（self-identity 对齐修复）：
/// 1. canonical→canonical 恒等；
/// 2. 平移/缩放/旋转输入能近似还原参考点；
/// 3. alignFaceToCanonical 产出 112×112、采样不出越界；
/// 4. 退化输入（点重合）不崩、回退 null。
void main() {
  group('estimateSimilarityTransform', () {
    test('canonical -> canonical 为恒等', () {
      final src = [for (final p in kRefPoints) math.Point<double>(p[0], p[1])];
      final t = estimateSimilarityTransform(src, kRefPoints);
      expect(t[0], closeTo(1, 1e-9)); // a ≈ 1
      expect(t[1], closeTo(0, 1e-9)); // b ≈ 0
      expect(t[2], closeTo(0, 1e-6)); // tx ≈ 0
      expect(t[3], closeTo(0, 1e-6)); // ty ≈ 0
    });

    test('整体平移 + 0.8 缩放能被还原（src→canonical 需放大 1/0.8）', () {
      // src = 0.8·ref + (100,200)：源脸更小 → 变换应放大回 canonical 尺度
      final src = [
        for (final p in kRefPoints)
          math.Point<double>(p[0] * 0.8 + 100, p[1] * 0.8 + 200),
      ];
      final t = estimateSimilarityTransform(src, kRefPoints);
      final s = math.sqrt(t[0] * t[0] + t[1] * t[1]);
      expect(s, closeTo(1 / 0.8, 1e-6));
      // 平移：t = dst_mean − R·src_mean = −(100,200)·(1/0.8)/... = (−125,−250)
      expect(t[2], closeTo(-125, 1e-4));
      expect(t[3], closeTo(-250, 1e-4));
    });

    test('旋转 +30° 能被还原（src 顺时针转回 canonical → b 为负）', () {
      final th = math.pi / 6; // 30°
      final rot = [
        for (final p in kRefPoints)
          math.Point<double>(
            p[0] * math.cos(th) - p[1] * math.sin(th),
            p[0] * math.sin(th) + p[1] * math.cos(th),
          ),
      ];
      final t = estimateSimilarityTransform(rot, kRefPoints);
      final a = t[0], b = t[1];
      expect(a, closeTo(math.cos(th), 1e-6));
      expect(b, closeTo(-math.sin(th), 1e-6)); // 逆旋转回 canonical
    });

    test('退化（点全部重合）返回恒等、不崩', () {
      final src = List.filled(5, const math.Point<double>(10, 10));
      final t = estimateSimilarityTransform(src, kRefPoints);
      expect(t, [1, 0, 0, 0]);
    });
  });

  group('alignFaceToCanonical', () {
    img.Image syntheticFace() {
      // 200×200 黑底，在参考点周围画白点 → 采样后 canonical 对应位置应为亮色
      final im = img.Image(width: 200, height: 200, numChannels: 3);
      for (final p in kRefPoints) {
        for (var dx = -2; dx <= 2; dx++) {
          for (var dy = -2; dy <= 2; dy++) {
            im.setPixelRgb((p[0] + dx).round(), (p[1] + dy).round(), 255, 255, 255);
          }
        }
      }
      return im;
    }

    test('canonical 输入 → 输出 112×112，五官位置为亮色', () {
      final im = syntheticFace();
      final src = [for (final p in kRefPoints) math.Point<double>(p[0], p[1])];
      final out = alignFaceToCanonical(im, src)!;
      expect(out.width, 112);
      expect(out.height, 112);
      // 左眼 canonical (38.3, 51.7) 附近应接近白
      final eye = out.getPixel(38, 52);
      expect(eye.r, greaterThan(200));
    });

    test('输入放大到 2 倍 + 平移 → 关键点仍对齐到 canonical 亮色', () {
      final im = img.Image(width: 400, height: 400, numChannels: 3);
      for (final p in kRefPoints) {
        final x = (p[0] * 2 + 50).round(), y = (p[1] * 2 + 80).round();
        for (var dx = -3; dx <= 3; dx++) {
          for (var dy = -3; dy <= 3; dy++) {
            im.setPixelRgb(x + dx, y + dy, 255, 255, 255);
          }
        }
      }
      final src = [for (final p in kRefPoints) math.Point<double>(p[0] * 2 + 50, p[1] * 2 + 80)];
      final out = alignFaceToCanonical(im, src)!;
      final eye = out.getPixel(38, 52);
      expect(eye.r, greaterThan(200));
    });

    test('退化点重合 → 返回 null（走 bbox 兜底）', () {
      final im = img.Image(width: 100, height: 100, numChannels: 3);
      final src = List.filled(5, const math.Point<double>(50, 50));
      expect(alignFaceToCanonical(im, src), isNull);
    });
  });
}
