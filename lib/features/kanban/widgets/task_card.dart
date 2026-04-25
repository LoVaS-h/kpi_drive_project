import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/drag_scroll_manager.dart';
import '../../../task_repository/export.dart';
import '../cubit/cubit.dart';

// Создает обертку Draggable для карточки. Позволяет перетаскивать её и бросать в другие карточки.
Widget buildTaskCard(BuildContext context, Task task) {
  return LongPressDraggable<Task>(
    key: ValueKey(task.id),
    data: task,
    // Уведомление менеджера автоскролла о перемещении пальца/курсора.
    onDragUpdate: (details) {
      final size = MediaQuery.of(context).size;
      DragScrollManager.instance.updatePosition(details.globalPosition, size);
    },
    // Остановка автоскролла при отпускании.
    onDragEnd: (details) {
      DragScrollManager.instance.endDrag();
    },
    // Вид карточки, который "летит" за пальцем.
    feedback: Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 300,
        child: Opacity(opacity: 0.8, child: TaskCardWidget(task: task, isDragging: true)),
      ),
    ),
    // Вид карточки на старом месте во время перетаскивания (скрываем её).
    childWhenDragging: const SizedBox.shrink(), 
    // Каждая карточка сама является целью для другой (DragTarget) для реализации вставки между ними.
    child: DragTarget<Task>(
      onWillAccept: (draggedTask) => draggedTask?.id != task.id,
      onAccept: (draggedTask) {
        // Перемещаем перетаскиваемую задачу в позицию текущей задачи.
        context.read<KanbanCubit>().moveTask(draggedTask, task.parentId, task.order);
      },
      builder: (context, candidateData, rejectedData) {
        final bool isHovered = candidateData.isNotEmpty;

        return Column(
          children: [
            // Анимированный отступ при наведении другой карточки "сверху".
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              height: isHovered ? 112 : 0, 
              width: double.infinity,
              child: isHovered 
                ? Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 2),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.blueAccent.withOpacity(0.05),
                    ),
                  )
                : const SizedBox.shrink(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
              child: TaskCardWidget(task: task, isDragging: false),
            ),
          ],
        );
      },
    ),
  );
}

// Виджет визуального отображения задачи (дизайн карточки).
class TaskCardWidget extends StatefulWidget {
  final Task task;
  final bool isDragging;

  const TaskCardWidget({super.key, required this.task, required this.isDragging});

  @override
  State<TaskCardWidget> createState() => _TaskCardWidgetState();
}

class _TaskCardWidgetState extends State<TaskCardWidget> {
  bool isFinished = false; // Статус выполнения.
  bool isEditing = false; // Режим редактирования текста.
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.task.name);
    _loadCheckboxState(); 
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TaskCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Синхронизация текста, если задача изменилась извне (не во время печати).
    if (oldWidget.task.name != widget.task.name && !isEditing) {
      _textController.text = widget.task.name;
    }
  }

  // Загрузка состояния чекбокса из локального хранилища устройства.
  Future<void> _loadCheckboxState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      isFinished = prefs.getBool('task_status_${widget.task.id}') ?? false;
    });
  }

  // Сохранение и переключение состояния выполнения.
  Future<void> changeState() async { 
    setState(() { isFinished = !isFinished; }); 
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('task_status_${widget.task.id}', isFinished);
  }

  // Переключение режима правки текста и сохранение на сервер/в Cubit.
  void _handleEditTap() {
    if (isEditing) {
      final newName = _textController.text.trim();
      if (newName.isNotEmpty && newName != widget.task.name) {
        context.read<KanbanCubit>().taskSave(widget.task.id, 'name', newName);
      }
    }
    setState(() { isEditing = !isEditing; });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 102,
      decoration: BoxDecoration(
        // Окрашиваем фон в зеленый при завершении задачи.
        color: isFinished ? const Color.fromARGB(255, 0, 53, 28) : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        // Синяя обводка при перетаскивании.
        border: Border.all(color: widget.isDragging ? Colors.blueAccent : const Color(0xFF2A2A2A), width: 1),
        boxShadow: widget.isDragging ? [BoxShadow(color: Colors.blueAccent.withOpacity(0.2), blurRadius: 15, spreadRadius: 2)] : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            // Левая часть: название или текстовое поле.
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: ListView(
                  children: [
                    isEditing 
                      ? TextField(
                          controller: _textController,
                          autofocus: true, maxLines: null,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFFE0E0E0), height: 1.4),
                          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.zero, border: InputBorder.none),
                        )
                      : Text(
                          widget.task.name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFFE0E0E0), height: 1.4),
                        ),
                  ]
                ),
              ),
            ),
            // Кнопки действий.
            Column(
              children: [
                // Кнопка статуса "Выполнено".
                IconButton(onPressed: changeState, constraints: const BoxConstraints(), padding: const EdgeInsets.all(5), icon: isFinished ? const Icon(Icons.check_circle, color: Colors.green, size: 20) : const Icon(Icons.check_circle_outline, color: Colors.white24, size: 20)),
                // Кнопка "Редактировать / Сохранить".
                IconButton(
                  onPressed: _handleEditTap, 
                  constraints: const BoxConstraints(), 
                  padding: const EdgeInsets.all(5), 
                  icon: Icon(isEditing ? Icons.save : Icons.edit, size: 20, color: isEditing ? Colors.blueAccent : Colors.white24)
                ),
                // Кнопка удаления задачи.
                IconButton(
                  onPressed: () {
                    context.read<KanbanCubit>().deleteTask(widget.task.id);
                  }, 
                  constraints: const BoxConstraints(), 
                  padding: const EdgeInsets.all(5), 
                  icon: const Icon(Icons.delete, size: 20, color: Colors.white24)
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}