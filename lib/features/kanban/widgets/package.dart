import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_project/core/utils/drag_scroll_manager.dart';

import '../../../task_repository/export.dart';
import '../cubit/cubit.dart';

// Виджет колонки (папки). Управляет анимациями списка и вертикальным скроллом.
class Package extends StatefulWidget {
  final int folderId;
  final String folderName;
  final List<Task> tasks;
  final Widget Function(BuildContext, Task) buildTaskCard;

  const Package({
    super.key,
    required this.folderId,
    required this.folderName,
    required this.tasks,
    required this.buildTaskCard,
  });

  @override
  State<Package> createState() => _PackageState();
}

class _PackageState extends State<Package> {
  // Ключ для управления AnimatedList (вставка/удаление с анимацией).
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  // Ключ для получения размеров и позиции колонки.
  final GlobalKey _packageKey = GlobalKey();
  final ScrollController _verticalController = ScrollController();
  late List<Task> _currentTasks;

  @override
  void initState() {
    super.initState();
    _currentTasks = List.from(widget.tasks);
    
    // Регистрация контроллера колонки для системы автоскролла.
    DragScrollManager.instance.verticalControllers[widget.folderId] = _verticalController;
    // Сохранение ссылки на RenderBox после отрисовки кадра.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        DragScrollManager.instance.verticalBoxes[widget.folderId] = 
            _packageKey.currentContext?.findRenderObject() as RenderBox?;
      }
    });
  }

  @override
  void dispose() {
    // Очистка ссылок в менеджере при удалении колонки.
    DragScrollManager.instance.verticalControllers.remove(widget.folderId);
    DragScrollManager.instance.verticalBoxes.remove(widget.folderId);
    _verticalController.dispose();
    super.dispose();
  }

  // Метод отслеживания изменений в списке задач для запуска анимаций.
  @override
  void didUpdateWidget(covariant Package oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newTasks = widget.tasks;
    
    // 1. Поиск и анимация удаления задач, которых больше нет в списке.
    for (int i = 0; i < _currentTasks.length; i++) {
      final task = _currentTasks[i];
      if (!newTasks.any((t) => t.id == task.id)) {
        _currentTasks.removeAt(i);
        _listKey.currentState?.removeItem(
          i,
          (context, animation) => SizeTransition(
            sizeFactor: animation,
            child: widget.buildTaskCard(context, task),
          ),
          duration: const Duration(milliseconds: 250),
        );
        i--;
      }
    }
    // 2. Поиск и анимация добавления новых задач.
    for (int i = 0; i < newTasks.length; i++) {
      final task = newTasks[i];
      if (!_currentTasks.any((t) => t.id == task.id)) {
        _currentTasks.insert(i, task);
        _listKey.currentState?.insertItem(i, duration: const Duration(milliseconds: 250));
      }
    }
    _currentTasks = List.from(newTasks);
  }

  // Вызов диалога для изменения имени папки.
  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: widget.folderName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Переименовать папку"),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Отмена")),
          TextButton(
            onPressed: () {
              context.read<KanbanCubit>().renameFolder(widget.folderId, controller.text);
              Navigator.pop(ctx);
            },
            child: const Text("Сохранить"),
          ),
        ],
      ),
    );
  }

  // Вызов диалога подтверждения удаления папки.
  void _deleteFolder() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Удалить папку?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Все задачи в этой папке также будут удалены из локального списка.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Отмена", style: TextStyle(color: Colors.blueAccent)),
          ),
          TextButton(
            onPressed: () {
              context.read<KanbanCubit>().deleteFolder(widget.folderId);
              Navigator.pop(ctx);
            },
            child: const Text("Удалить", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: MediaQuery.of(context).size.height * 0.9,
      margin: const EdgeInsets.only(right: 20.0),
      decoration: BoxDecoration(
        color: const Color(0xFF121212).withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF222222), width: 1),
      ),
      key: _packageKey, // Привязка ключа для RenderBox.
      child: Column(
        children: [
          // Шапка колонки (имя, редактирование, удаление).
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 12,),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(
                      widget.folderName.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueAccent, letterSpacing: 1.1),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _showRenameDialog(context),
                  icon: const Icon(Icons.edit, size: 22, color: Colors.white38),
                  padding: EdgeInsets.zero,
                ),
                IconButton(
                  onPressed: () => _deleteFolder(),
                  icon: const Icon(Icons.delete, size: 22, color: Colors.white38),
                  padding: EdgeInsets.zero,
                ),
                Text('${widget.tasks.length}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          // Кнопка для создания новой задачи в этой колонке.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: InkWell(
              onTap: () => context.read<KanbanCubit>().addTask(widget.folderId),
              child: Container(
                height: 50,
                  decoration: BoxDecoration(
                    color:  const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color:  Color(0xFF2A2A2A), width: 1),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.05), width: 1),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 5,),
                        const Icon(Icons.add, size: 24),
                      ],
                    ),
                  ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          // Список задач с поддержкой DragTarget (прием падающих карточек).
          Flexible(
            child: DragTarget<Task>(
              // Событие приземления карточки в самый низ колонки.
              onAccept: (task) {
                final int taskCount = widget.tasks.length;
                final bool isSameFolder = task.parentId == widget.folderId;
                final int newOrder = taskCount == 0 ? 1 : (isSameFolder ? taskCount : taskCount + 1);
                context.read<KanbanCubit>().moveTask(task, widget.folderId, newOrder);
              },
              builder: (context, candidateData, rejectedData) {
                final bool isHoveringAtEnd = candidateData.isNotEmpty;
                return Column(
                  children: [
                    Expanded(
                      child: AnimatedList(
                        key: _listKey,
                        controller: _verticalController,
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        initialItemCount: _currentTasks.length,
                        padding: const EdgeInsets.only(bottom: 16),
                        itemBuilder: (context, index, animation) {
                          return SizeTransition(
                            sizeFactor: animation,
                            child: widget.buildTaskCard(context, _currentTasks[index]),
                          );
                        },
                      ),
                    ),
                    // Визуальный индикатор (пустое место) в конце списка при наведении.
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: isHoveringAtEnd ? 112 : 20,
                      child: isHoveringAtEnd 
                        ? Center(
                            child: Container(
                              width: 280, height: 100,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.blueAccent.withOpacity(0.3), style: BorderStyle.none),
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.white.withOpacity(0.02),
                              ),
                            ),
                          ) 
                        : const SizedBox.shrink(),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}