import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'api_service.dart';
import 'cubit.dart';

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

  final Map<int, String> folderNames = const {
    318201: 'Финансы и админ',
    4256: 'Основные проекты',
    317898: 'Тех. разработка',
    318192: 'Клиенты и партнеры',
    318020: 'Школа и оплаты',
    317963: 'Внешние связи',
    317719: 'Отчетность',
    318131: '1С и Вики',
    318155: 'Команда и UI',
    318019: 'Внутренний админ',
    318133: 'Интерфейс и рассылки',
    317836: 'HR и контент',
    318139: 'Развитие сервисов',
  };

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
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        shape: const Border(bottom: BorderSide(color: Color(0xFF222222), width: 1)),
        elevation: 0,
      ),
      body: BlocConsumer<KanbanCubit, KanbanState>(
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
            return _buildBoard(context, state.tasks);
          }
          return const Center(child: Text('Нет данных', style: TextStyle(color: Colors.grey)));
        },
      ),
    );
  }

  Widget _buildBoard(BuildContext context, List<Task> tasks) {
    final uniqueFolderIds = folderNames.keys.toList();

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
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
          },
        ),
        
        child: RawScrollbar(
          controller: _horizontalController,
          thumbVisibility: true,
          trackVisibility: true,
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
              children: uniqueFolderIds.map((folderId) {
                final columnTasks = tasks.where((t) => t.parentId == folderId).toList();
                return Package(
                  folderId: folderId,
                  folderName: folderNames[folderId]!,
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
  final ScrollController _verticalController = ScrollController();

  @override
  void dispose() {
    _verticalController.dispose();
    super.dispose();
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
      child: Column(
        children: [
          
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.folderName.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                Text(
                  '${widget.tasks.length}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          Expanded(
  child: DragTarget<Task>(
    onAccept: (task) {
      final newOrder = widget.tasks.isEmpty ? 1 : widget.tasks.last.order + 1;
      context.read<KanbanCubit>().moveTask(task, widget.folderId, newOrder);
    },
    builder: (context, candidateData, rejectedData) {
      final bool isHoveringAtEnd = candidateData.isNotEmpty;

      return RawScrollbar(
        controller: _verticalController,
          thickness: 8, 
          radius: const Radius.circular(20),
          interactive: true,
          
          thumbColor: Colors.white12,
          
          trackRadius: const Radius.circular(20),
          
          
          fadeDuration: const Duration(milliseconds: 500),
          timeToFade: const Duration(milliseconds: 1000),
        child: ListView( 
          controller: _verticalController,
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            ...widget.tasks.map((t) => widget.buildTaskCard(context, t)).toList(),
            
            
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: isHoveringAtEnd ? 112 : 20, 
              child: isHoveringAtEnd 
                ? Center(
                    child: Container(
                      width: 280,
                      height: 100,
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
        ),
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
    data: task,
    
    feedback: Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 300,
        child: Opacity(
          opacity: 0.8,
          child: _TaskCardWidget(task: task, isDragging: true),
        ),
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
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _handleEditTap() {
    if (isEditing) {
      final newName = _textController.text.trim();
      if (newName.isNotEmpty && newName != widget.task.name) {
        context.read<KanbanCubit>().taskSave(
          widget.task.id, 
          'name', 
          newName
        );
      }
    }
    setState(() {
      isEditing = !isEditing;
    });
  }

  void changeState() {
    isFinished = !isFinished;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: isFinished ? const Color.fromARGB(255, 0, 53, 28) : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isDragging ? Colors.blueAccent : const Color(0xFF2A2A2A),
          width: 1,
        ),
        boxShadow: widget.isDragging 
          ? [BoxShadow(color: Colors.blueAccent.withOpacity(0.2), blurRadius: 15, spreadRadius: 2)]
          : [],
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
                  border: Border.all(
                  color: Colors.white.withOpacity(0.05),
                  width: 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: ListView(
                  children: [
                    isEditing 
                      ? TextField(
                          controller: _textController,
                          autofocus: true,
                          maxLines: null,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFE0E0E0),
                            height: 1.4,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none, 
                          ),
                        )
                      : Text(
                          widget.task.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFE0E0E0),
                            height: 1.4,
                          ),
                        ),
                  ]
                ),
              ),
            ),
            Column(
              children: [
                IconButton(onPressed:() => setState(() {changeState();}), constraints: const BoxConstraints(), padding: const EdgeInsets.all(5), icon: isFinished ? Icon(Icons.check_circle, color: Colors.green, size: 20) : Icon(Icons.check_circle_outline, color: Colors.white24, size: 20)),
                IconButton(
                  onPressed: _handleEditTap, 
                  constraints: const BoxConstraints(), 
                  padding: const EdgeInsets.all(5), 
                  icon: Icon(
                    isEditing ? Icons.save : Icons.edit, 
                    size: 20,
                    color: isEditing ? Colors.blueAccent : Colors.white24
                  )
                ),
                IconButton(onPressed: (){}, constraints: const BoxConstraints(), padding: const EdgeInsets.all(5), icon: const Icon(Icons.delete, size: 20,color: Colors.white24))
              ],
            )
          ],
        ),
      ),
    );
  }
}