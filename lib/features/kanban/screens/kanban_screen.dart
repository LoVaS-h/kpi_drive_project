import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/drag_scroll_manager.dart';
import '../../../task_repository/export.dart';
import '../cubit/cubit.dart';
import '../widgets/export.dart';

// Главный экран Kanban-доски.
class KanbanScreen extends StatefulWidget {
  const KanbanScreen({super.key});

  @override
  State<KanbanScreen> createState() => _KanbanScreenState();
}

class _KanbanScreenState extends State<KanbanScreen> {
  // Основной контроллер для горизонтального перемещения между колонками.
  final ScrollController _horizontalController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Связываем локальный контроллер с глобальным менеджером автоскролла.
    DragScrollManager.instance.horizontalController = _horizontalController;
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        centerTitle: false,
        title: const Text(
          'KPI-DRIVE / KANBAN',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 20, color: Colors.white),
        ),
        // Нижняя граница шапки.
        shape: const Border(bottom: BorderSide(color: Color(0xFF222222), width: 1)),
        elevation: 0,
      ),
      body: Row(
        children: [
          // Левый Sidebar для действий над всей доской (например, создание папок).
          Container(
            width: 64,
            decoration: const BoxDecoration(
              color: const Color(0xFF121212),
              border: const Border(right: BorderSide(color: Color(0xFF222222), width: 1)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 20),
                IconButton(
                  tooltip: 'Добавить папку',
                  icon: const Icon(Icons.create_new_folder, color: Colors.blueAccent, size: 28),
                  onPressed: () {
                    context.read<KanbanCubit>().addFolder("Папка");
                  },
                ),
                const Spacer(),
              ],
            ),
          ),
          // Основная область доски с обработкой состояний загрузки/ошибки.
          Expanded(
            child: BlocConsumer<KanbanCubit, KanbanState>(
              listener: (context, state) {
                if (state is KanbanError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.message), backgroundColor: Colors.redAccent),
                  );
                }
              },
              builder: (context, state) {
                if (state is KanbanLoading) {
                  return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
                } else if (state is KanbanLoaded) {
                  return _buildBoard(context, state.tasks, state.folders);
                }
                return const Center(child: Text('Нет данных', style: TextStyle(color: Colors.grey)));
              },
            ),
          ),
        ],
      ),
    );
  }

  // Рендерит саму доску с горизонтальным скроллом и кастомным Scrollbar.
  Widget _buildBoard(BuildContext context, List<Task> tasks, Map<int, String> folders) {
    final folderIds = folders.keys.toList()..sort();

    return Container(
      decoration: const BoxDecoration(
        // Дизайнерский градиент фона.
        gradient: RadialGradient(
          center: Alignment.topLeft,
          radius: 1.5,
          colors: [Color(0xFF161616), Color(0xFF0A0A0A)],
        ),
      ),
      child: ScrollConfiguration(
        // Позволяет скроллить мышкой и тачпадом на десктопе.
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad},
        ),
        child: RawScrollbar(
          controller: _horizontalController,
          thumbVisibility: true,
          thickness: 10,
          radius: const Radius.circular(20),
          interactive: true,
          thumbColor: Colors.blueAccent,
          trackColor: Colors.white12,
          trackRadius: const Radius.circular(20),
          fadeDuration: const Duration(milliseconds: 500),
          timeToFade: const Duration(milliseconds: 1000),
          scrollbarOrientation: ScrollbarOrientation.top,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 40),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: folderIds.map((folderId) {
                // Фильтруем задачи для конкретной колонки.
                final columnTasks = tasks.where((t) => t.parentId == folderId).toList();
                return Package(
                  folderId: folderId,
                  folderName: folders[folderId]!,
                  tasks: columnTasks,
                  buildTaskCard: buildTaskCard, // Используем публичную функцию из task_card.dart
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}