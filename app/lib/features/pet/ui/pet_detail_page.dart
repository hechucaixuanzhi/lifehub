import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/swipe_back_dismiss.dart';
import '../../../domain/entities/pet.dart';
import '../../../domain/entities/pet_log.dart';
import '../logic/pet_notifier.dart';

/// 宠物详情：四个 Tab（文字 / 体重 / 健康 / 照片），各 Tab 右下角 FAB 记一笔。
class PetDetailPage extends ConsumerStatefulWidget {
  const PetDetailPage({super.key, required this.pet});
  final Pet pet;

  @override
  ConsumerState<PetDetailPage> createState() => _PetDetailPageState();
}

class _PetDetailPageState extends ConsumerState<PetDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(petLogsProvider(widget.pet.id));
    return Scaffold(
      appBar: AppBar(title: Text(widget.pet.name)),
      body: Column(
        children: [
          TabBar(
            controller: _tab,
            tabs: const [
              Tab(text: '文字'),
              Tab(text: '体重'),
              Tab(text: '健康'),
              Tab(text: '照片'),
            ],
            labelColor: AppColors.accent,
            unselectedLabelColor: AppColors.muted,
            indicatorColor: AppColors.accent,
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _LogList(logsAsync, widget.pet, 'text'),
                _LogList(logsAsync, widget.pet, 'weight'),
                _LogList(logsAsync, widget.pet, 'health'),
                _PhotoGrid(logsAsync, widget.pet),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _add(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final idx = _tab.index;
    if (idx == 3) {
      final saved = await _pickAndSave();
      if (saved != null) {
        await ref.read(petRepositoryProvider).addLog(
              petId: widget.pet.id,
              kind: 'photo',
              mediaAssetId: saved,
              content: '',
            );
        if (context.mounted) {
          ref.invalidate(petLogsProvider(widget.pet.id));
          await ref.read(petLogsProvider(widget.pet.id).future);
        }
      }
      return;
    }
    final kind = ['text', 'weight', 'health'][idx];
    final ctrl = TextEditingController();
    final title = switch (kind) {
      'weight' => '体重 (kg)',
      'health' => '健康笔记',
      _ => '文字记录',
    };
    final isWeight = kind == 'weight';
    if (!context.mounted) return;
    await showAppModalSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          24,
          16,
          24 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: isWeight
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.multiline,
              maxLines: isWeight ? 1 : 3,
              decoration: InputDecoration(
                  labelText: title, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                final text = ctrl.text.trim();
                if (text.isNotEmpty) {
                  if (isWeight) {
                    final kg = double.tryParse(text);
                    if (kg != null) {
                      await ref.read(petRepositoryProvider).addLog(
                            petId: widget.pet.id,
                            kind: 'weight',
                            value: kg,
                            content: '',
                          );
                    }
                  } else {
                    await ref.read(petRepositoryProvider).addLog(
                          petId: widget.pet.id,
                          kind: kind,
                          content: text,
                        );
                  }
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ref.invalidate(petLogsProvider(widget.pet.id));
                    await ref.read(petLogsProvider(widget.pet.id).future);
                  }
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _pickAndSave() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return null;
    final dir = await getApplicationDocumentsDirectory();
    final petDir = Directory('${dir.path}/pets/${widget.pet.id}');
    await petDir.create(recursive: true);
    final name = '${DateTime.now().microsecondsSinceEpoch}.jpg';
    final saved = await File(picked.path).copy('${petDir.path}/$name');
    return saved.path;
  }
}

class _LogList extends ConsumerWidget {
  const _LogList(this.logsAsync, this.pet, this.kind);
  final AsyncValue<List<PetLog>> logsAsync;
  final Pet pet;
  final String kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return logsAsync.when(
      data: (logs) {
        final items = logs.where((l) => l.kind == kind).toList();
        if (items.isEmpty) {
          return const Center(
              child: Text('暂无记录', style: TextStyle(color: AppColors.muted)));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final l = items[i];
            final when = _when(l.occurredAt);
            final isPhoto = kind == 'photo';
            if (kind == 'weight') {
              return ListTile(
                leading: const Icon(Icons.monitor_weight_outlined),
                title: Text('${l.value} kg'),
                subtitle: Text(when),
                trailing: _editBtn(context, ref, l),
              );
            }
            return ListTile(
              leading: Icon(kind == 'health'
                  ? Icons.health_and_safety_outlined
                  : Icons.notes_outlined),
              title: Text(l.content.isEmpty ? '(空)' : l.content),
              subtitle: Text(when),
              trailing: isPhoto ? null : _editBtn(context, ref, l),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('加载失败: $e'),
    );
  }

  Widget? _editBtn(BuildContext context, WidgetRef ref, PetLog log) {
    return IconButton(
      icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.muted),
      tooltip: '编辑',
      onPressed: () => _edit(context, ref, log),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, PetLog log) async {
    final isWeight = log.kind == 'weight';
    final ctrl = TextEditingController(
        text: isWeight
            ? '${log.value}'
            : (log.content.isEmpty ? '' : log.content));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isWeight ? '编辑体重' : '编辑记录'),
        content: TextField(
          controller: ctrl,
          keyboardType: isWeight
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.multiline,
          maxLines: isWeight ? 1 : 3,
          decoration: InputDecoration(labelText: isWeight ? '体重 (kg)' : '内容'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('保存')),
        ],
      ),
    );
    if (ok == true) {
      final text = ctrl.text.trim();
      if (isWeight) {
        final kg = double.tryParse(text);
        if (kg != null) {
          await ref.read(petNotifierProvider.notifier).updateLog(
                logId: log.id,
                content: '',
                value: kg,
              );
        }
      } else if (text.isNotEmpty) {
        await ref.read(petNotifierProvider.notifier).updateLog(
              logId: log.id,
              content: text,
            );
      }
      if (context.mounted) {
        ref.invalidate(petLogsProvider(pet.id));
      }
    }
  }

  String _when(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid(this.logsAsync, this.pet);
  final AsyncValue<List<PetLog>> logsAsync;
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    return logsAsync.when(
      data: (logs) {
        final photos = logs
            .where((l) => l.kind == 'photo' && l.mediaAssetId != null)
            .toList();
        if (photos.isEmpty) {
          return const Center(
              child: Text('暂无照片', style: TextStyle(color: AppColors.muted)));
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: photos.length,
          itemBuilder: (_, i) => ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(photos[i].mediaAssetId!),
              fit: BoxFit.cover,
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('加载失败: $e'),
    );
  }
}
