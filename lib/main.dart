import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cubit/cubit.dart';
import 'dart:async';

import 'task_repository/export.dart';

// Менеджер для автоматического скролла при перетаскивании карточек (Drag-and-Drop).
// Позволяет доске прокручиваться, если карточка поднесена к краю экрана.
class DragScrollManager {
  // Реализация Singleton для доступа к менеджеру из любой части приложения.
  static final DragScrollManager instance = DragScrollManager._internal();
  DragScrollManager._internal();

  // Контроллер для горизонтальной прокрутки всей доски.
  ScrollController? horizontalController;
  // Мапа контроллеров для вертикальной прокрутки каждой отдельной колонки (по ID папки).
  final Map<int, ScrollController> verticalControllers = {};
  // Хранилище RenderBox колонок для определения их границ в глобальных координатах.
  final Map<int, RenderBox?> verticalBoxes = {};

  Timer? _timer;
  Offset? _lastPosition;
  Size? _screenSize;

  // Обновляет текущую позицию перетаскиваемого объекта и запускает таймер скролла (60 FPS).
  void updatePosition(Offset position, Size screenSize) {
    _lastPosition = position;
    _screenSize = screenSize;
    _timer ??= Timer.periodic(const Duration(milliseconds: 16), _scrollTick);
  }

  // Останавливает скролл и полностью сбрасывает таймер при завершении Drag-события.
  void endDrag() {
    _timer?.cancel();
    _timer = null;
    _lastPosition = null;
  }

  // Циклическая проверка необходимости сдвига контроллеров.
  void _scrollTick(Timer timer) {
    if (_lastPosition == null || _screenSize == null) return;
    final pos = _lastPosition!;
    final size = _screenSize!;

    // Вызов проверки для горизонтального скролла всей доски.
    _scrollIfNeeded(horizontalController, pos.dx, size.width);

    // Перебор всех колонок для поиска той, над которой сейчас находится карточка.
    for (var entry in verticalBoxes.entries) {
      final box = entry.value;
      if (box != null && box.attached) {
        try {
          // Перевод глобальной позиции касания в локальную позицию внутри колонки.
          final localPos = box.globalToLocal(pos);
          // Если касание внутри текущей колонки по ширине — скроллим её вертикально.
          if (localPos.dx >= 0 && localPos.dx <= box.size.width) {
            _scrollIfNeeded(verticalControllers[entry.key], localPos.dy, box.size.height, extraPadding: 50);
            break; 
          }
        } catch (_) {}
      }
    }
  }

  // Универсальная логика расчета: если объект у края (100px), двигаем offset контроллера.
  void _scrollIfNeeded(ScrollController? ctrl, double currentPos, double maxPos, {double extraPadding = 0}) {
    if (ctrl != null && ctrl.hasClients) {
      double d = 0;
      // Если близко к левому/верхнему краю.
      if (currentPos < 100 && currentPos > -extraPadding) d = -10; 
      // Если близко к правому/нижнему краю.
      else if (currentPos > maxPos - 100 && currentPos < maxPos + extraPadding) d = 10; 

      if (d != 0) {
        // Выполняем мгновенный сдвиг (jumpTo) с ограничением по границам контента.
        ctrl.jumpTo((ctrl.offset + d).clamp(ctrl.position.minScrollExtent, ctrl.position.maxScrollExtent));
      }
    }
  }
}

void main() {
  runApp(const KpiDriveApp());
}

// Корневой виджет приложения. Устанавливает темную тему и инициализирует Cubit.
class KpiDriveApp extends StatelessWidget {
  const KpiDriveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KPI-DRIVE Kanban',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
      ),
      // Обертка BlocProvider для доступа к бизнес-логике управления задачами.
      home: BlocProvider(
        create: (context) => KanbanCubit(ApiService())..loadTasks(),
        child: const KanbanScreen(),
      ),
    );
  }
}

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
              color: Color(0xFF121212),
              border: Border(right: BorderSide(color: Color(0xFF222222), width: 1)),
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
                  buildTaskCard: _buildTaskCard,
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

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

// Создает обертку Draggable для карточки. Позволяет перетаскивать её и бросать в другие карточки.
Widget _buildTaskCard(BuildContext context, Task task) {
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
        child: Opacity(opacity: 0.8, child: _TaskCardWidget(task: task, isDragging: true)),
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
              child: _TaskCardWidget(task: task, isDragging: false),
            ),
          ],
        );
      },
    ),
  );
}

// Виджет визуального отображения задачи (дизайн карточки).
class _TaskCardWidget extends StatefulWidget {
  final Task task;
  final bool isDragging;

  const _TaskCardWidget({required this.task, required this.isDragging});

  @override
  State<_TaskCardWidget> createState() => _TaskCardWidgetState();
}

class _TaskCardWidgetState extends State<_TaskCardWidget> {
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
  void didUpdateWidget(_TaskCardWidget oldWidget) {
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