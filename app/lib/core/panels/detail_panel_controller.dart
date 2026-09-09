import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 详情面板请求类型（内容区底部弹出面板，对齐原型 detailpanel）。
sealed class PanelRequest {
  const PanelRequest();
}

class HabitPanelRequest extends PanelRequest {
  const HabitPanelRequest(this.habitId);
  final String habitId;
}

class StudyPanelRequest extends PanelRequest {
  const StudyPanelRequest(this.resourceId);
  final String resourceId;
}

class ExercisePanelRequest extends PanelRequest {
  const ExercisePanelRequest(this.typeId);
  final String typeId;
}

/// DetailPanelController — Shell 内内容区底部面板的开关控制器。
/// openX 由各页面网格的双击装配；面板内容由 Shell 按请求类型构建。
class DetailPanelController extends Notifier<PanelRequest?> {
  @override
  PanelRequest? build() => null;

  void open(PanelRequest request) => state = request;

  void close() => state = null;

  void toggle(PanelRequest request) {
    state = state == null ? request : null;
  }
}

final detailPanelProvider =
    NotifierProvider<DetailPanelController, PanelRequest?>(
  DetailPanelController.new,
);
