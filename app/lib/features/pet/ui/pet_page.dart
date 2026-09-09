import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nav/app_page_route.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/swipe_back_dismiss.dart';
import '../logic/pet_notifier.dart';
import 'pet_detail_page.dart';

class PetPage extends ConsumerWidget {
  const PetPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(petNotifierProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('宠物')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addPet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(
                  child: Text(state.error!,
                      style: const TextStyle(color: AppColors.danger)))
              : state.pets.isEmpty
                  ? const Center(
                      child: Text('还没有宠物，点右下角添加',
                          style: TextStyle(color: AppColors.muted)))
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.read(petNotifierProvider.notifier).refresh(),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          for (final p in state.pets)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Material(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => Navigator.push(
                                    context,
                                    AppPageRoute(
                                        builder: (_) => PetDetailPage(pet: p)),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundImage: p.avatarPath != null
                                            ? FileImage(File(p.avatarPath!))
                                            : null,
                                        child: p.avatarPath == null
                                            ? const Icon(Icons.pets_outlined)
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(p.name,
                                                style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                            Text(
                                              p.species == 'cat'
                                                  ? '猫'
                                                  : p.species == 'dog'
                                                      ? '狗'
                                                      : p.species,
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  color: AppColors.muted),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right,
                                          color: AppColors.muted),
                                    ]),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
    );
  }

  void _addPet(BuildContext context, WidgetRef ref) {
    var name = '';
    var species = 'cat';
    showAppModalSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            24,
            16,
            24 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('新增宠物',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextField(
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: '名字', border: OutlineInputBorder()),
                onChanged: (v) => name = v,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: species,
                decoration: const InputDecoration(
                    labelText: '物种', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'cat', child: Text('猫')),
                  DropdownMenuItem(value: 'dog', child: Text('狗')),
                  DropdownMenuItem(value: 'other', child: Text('其他')),
                ],
                onChanged: (v) => setState(() => species = v!),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  if (name.trim().isNotEmpty) {
                    try {
                      await ref
                          .read(petNotifierProvider.notifier)
                          .addPet(name: name.trim(), species: species);
                      if (context.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        showAppToast(context, '添加失败: $e');
                      }
                    }
                  }
                },
                child: const Text('保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
