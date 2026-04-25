import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'features/kanban/cubit/cubit.dart';
import 'features/kanban/screens/kanban_screen.dart';
import 'task_repository/export.dart';

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
      // Обертка BlocProvider для доступа к бизнес-логике управления задачами.
      home: BlocProvider(
        create: (context) => KanbanCubit(ApiService())..loadTasks(),
        child: const KanbanScreen(),
      ),
    );
  }
}