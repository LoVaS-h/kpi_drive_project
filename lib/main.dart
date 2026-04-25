import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'cubit/cubit.dart';
import 'dart:async';

class DragScrollManager {
  static final DragScrollManager instance = DragScrollManager._internal();
  DragScrollManager._internal();

  ScrollController? horizontalController;
  Map<int, ScrollController> verticalControllers = {};
  Map<int, RenderBox?> verticalBoxes = {};

  Timer? _timer;
  Offset? _lastPosition;
  Size? _screenSize;

  void updatePosition(Offset position, Size screenSize) {
    _lastPosition = position;
    _screenSize = screenSize;
    _timer ??= Timer.periodic(const Duration(milliseconds: 16), _scrollTick);
  }

  void endDrag() {
    _timer?.cancel();
    _timer = null;
    _lastPosition = null;
  }

  void _scrollTick(Timer timer) {
    if (_lastPosition == null || _screenSize == null) return;
    final pos = _lastPosition!;
    final size = _screenSize!;

    
    if (horizontalController != null && horizontalController!.hasClients) {
      double dx = 0;
      if (pos.dx < 100) {
        dx = -10; 
      } else if (pos.dx > size.width - 100){
        dx = 10;
      } 
      
      if (dx != 0) {
        final newOffset = horizontalController!.offset + dx;
        horizontalController!.jumpTo(newOffset.clamp(
          horizontalController!.position.minScrollExtent,
          horizontalController!.position.maxScrollExtent,
        ));
      }
    }

    
    for (var entry in verticalBoxes.entries) {
      final folderId = entry.key;
      final box = entry.value;
      if (box != null && box.attached) {
        try {
          final localPos = box.globalToLocal(pos);
          if (localPos.dx >= 0 && localPos.dx <= box.size.width) {
            final vCtrl = verticalControllers[folderId];
            if (vCtrl != null && vCtrl.hasClients) {
              double dy = 0;
              if (localPos.dy < 100 && localPos.dy > -50) dy = -10; 
              else if (localPos.dy > box.size.height - 100 && localPos.dy < box.size.height + 50) dy = 10; 

              if (dy != 0) {
                final newOffset = vCtrl.offset + dy;
                vCtrl.jumpTo(newOffset.clamp(
                  vCtrl.position.minScrollExtent,
                  vCtrl.position.maxScrollExtent,
                ));
              }
            }
            break; 
          }
        } catch (e) { }
      }
    }
  }
}

void main() {
  runApp(const KpiDriveApp());
}

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
      home: BlocProvider(
        create: (context) => KanbanCubit(ApiService())..loadTasks(),
        child: const KanbanScreen(),
      ),
    );
  }
}

class KanbanScreen extends StatefulWidget {
  const KanbanScreen({super.key});

  @override
  State<KanbanScreen> createState() => _KanbanScreenState();
}

class _KanbanScreenState extends State<KanbanScreen> {
  final ScrollController _horizontalController = ScrollController();

  @override
  void initState() {
    super.initState();
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
        shape: const Border(bottom: BorderSide(color: Color(0xFF222222), width: 1)),
        elevation: 0,
      ),
      body: Row(
        children: [
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

  Widget _buildBoard(BuildContext context, List<Task> tasks, Map<int, String> folders) {
    final folderIds = folders.keys.toList()..sort();

    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topLeft,
          radius: 1.5,
          colors: [Color(0xFF161616), Color(0xFF0A0A0A)],
        ),
      ),
      child: ScrollConfiguration(
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
  
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final GlobalKey _packageKey = GlobalKey();
  final ScrollController _verticalController = ScrollController();
  late List<Task> _currentTasks;

  @override
  void initState() {
    super.initState();
    _currentTasks = List.from(widget.tasks);
    
    
    DragScrollManager.instance.verticalControllers[widget.folderId] = _verticalController;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        DragScrollManager.instance.verticalBoxes[widget.folderId] = 
            _packageKey.currentContext?.findRenderObject() as RenderBox?;
      }
    });
  }

  @override
  void dispose() {
    DragScrollManager.instance.verticalControllers.remove(widget.folderId);
    DragScrollManager.instance.verticalBoxes.remove(widget.folderId);
    _verticalController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant Package oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newTasks = widget.tasks;
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
    for (int i = 0; i < newTasks.length; i++) {
      final task = newTasks[i];
      if (!_currentTasks.any((t) => t.id == task.id)) {
        _currentTasks.insert(i, task);
        _listKey.currentState?.insertItem(i, duration: const Duration(milliseconds: 250));
      }
    }
    _currentTasks = List.from(newTasks);
  }

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
      key: _packageKey,
      child: Column(
        children: [
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
          Flexible(
            child: DragTarget<Task>(
              onAccept: (task) {
                final newOrder = widget.tasks.isEmpty ? 1 : widget.tasks.last.order + 1;
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

Widget _buildTaskCard(BuildContext context, Task task) {
  return LongPressDraggable<Task>(
    key: ValueKey(task.id),
    data: task,
    onDragUpdate: (details) {
      final size = MediaQuery.of(context).size;
      DragScrollManager.instance.updatePosition(details.globalPosition, size);
    },
    onDragEnd: (details) {
      DragScrollManager.instance.endDrag();
    },
    feedback: Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 300,
        child: Opacity(opacity: 0.8, child: _TaskCardWidget(task: task, isDragging: true)),
      ),
    ),
    childWhenDragging: const SizedBox.shrink(), 
    child: DragTarget<Task>(
      onWillAccept: (draggedTask) => draggedTask?.id != task.id,
      onAccept: (draggedTask) {
        context.read<KanbanCubit>().moveTask(draggedTask, task.parentId, task.order);
      },
      builder: (context, candidateData, rejectedData) {
        final bool isHovered = candidateData.isNotEmpty;

        return Column(
          children: [
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

class _TaskCardWidget extends StatefulWidget {
  final Task task;
  final bool isDragging;

  const _TaskCardWidget({required this.task, required this.isDragging});

  @override
  State<_TaskCardWidget> createState() => _TaskCardWidgetState();
}

class _TaskCardWidgetState extends State<_TaskCardWidget> {
  bool isFinished = false;
  bool isEditing = false;
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
    
    
    if (oldWidget.task.name != widget.task.name && !isEditing) {
      _textController.text = widget.task.name;
    }
  }

  
  Future<void> _loadCheckboxState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      isFinished = prefs.getBool('task_status_${widget.task.id}') ?? false;
    });
  }

  
  Future<void> changeState() async { 
    setState(() { isFinished = !isFinished; }); 
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('task_status_${widget.task.id}', isFinished);
  }

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
        color: isFinished ? const Color.fromARGB(255, 0, 53, 28) : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.isDragging ? Colors.blueAccent : const Color(0xFF2A2A2A), width: 1),
        boxShadow: widget.isDragging ? [BoxShadow(color: Colors.blueAccent.withOpacity(0.2), blurRadius: 15, spreadRadius: 2)] : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
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
            Column(
              children: [
                IconButton(onPressed: changeState, constraints: const BoxConstraints(), padding: const EdgeInsets.all(5), icon: isFinished ? const Icon(Icons.check_circle, color: Colors.green, size: 20) : const Icon(Icons.check_circle_outline, color: Colors.white24, size: 20)),
                IconButton(
                  onPressed: _handleEditTap, 
                  constraints: const BoxConstraints(), 
                  padding: const EdgeInsets.all(5), 
                  icon: Icon(isEditing ? Icons.save : Icons.edit, size: 20, color: isEditing ? Colors.blueAccent : Colors.white24)
                ),
                
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