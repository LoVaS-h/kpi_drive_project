import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../task_repository/export.dart';

part 'states.dart';

class KanbanCubit extends Cubit<KanbanState> {
  final ApiService apiService;
  List<Task> _cachedTasks = [];
  Map<int, String> _folders = {};

  KanbanCubit(this.apiService) : super(KanbanLoading());

  static const String _storageKey = 'custom_folder_names';
  static const String _localTasksKey = 'local_tasks';
  
  // Получение экземпляра локального хранилища
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  // Вспомогательный метод для обновления UI текущими данными
  void _emitLoaded() => emit(KanbanLoaded(List.from(_cachedTasks), Map.from(_folders)));

  // Загрузка кастомных имен папок из памяти устройства
  Future<Map<String, dynamic>> _getSavedFolders() async {
    final savedRaw = (await _prefs).getString(_storageKey);
    return savedRaw != null ? jsonDecode(savedRaw) : {};
  }

  // Сохранение кастомных имен папок в память устройства
  Future<void> _updateSavedFolders(Map<String, dynamic> data) async {
    (await _prefs).setString(_storageKey, jsonEncode(data));
  }

  // Сохранение локально созданных задач (с отрицательными ID) в память
  Future<void> _saveLocalTasks() async {
    final localTasks = _cachedTasks.where((t) => t.id < 0).map((t) => {
      'indicator_to_mo_id': t.id,
      'parent_id': t.parentId,
      'name': t.name,
      'order': t.order,
    }).toList();
    (await _prefs).setString(_localTasksKey, jsonEncode(localTasks));
  }

  // Инициализация данных: загрузка с сервера + локальный кэш + имена папок
  Future<void> loadTasks() async {
    try {
      emit(KanbanLoading());
      _cachedTasks = await apiService.fetchTasks();
      
      final prefs = await _prefs;
      final String? localTasksRaw = prefs.getString(_localTasksKey);
      
      if (localTasksRaw != null) {
        final List<dynamic> localTasksList = jsonDecode(localTasksRaw);
        _cachedTasks.addAll(localTasksList.map((j) => Task.fromJson(j)));
      }

      final savedNames = await _getSavedFolders();

      final uniquePids = {..._cachedTasks.map((t) => t.parentId), ...savedNames.keys.map(int.parse)}.toList()..sort();

      _folders = {
        for (int i = 0; i < uniquePids.length; i++)
          uniquePids[i]: savedNames[uniquePids[i].toString()] ?? 'Папка ${i + 1}'
      };
      
      _cachedTasks.sort((a, b) => a.order.compareTo(b.order));
      _emitLoaded();
    } catch (e) {
      emit(KanbanError("Ошибка загрузки задач: $e"));
    }
  }

  // Локальное переименование папки (колонки)
  Future<void> renameFolder(int folderId, String newName) async {
    try {
      _folders[folderId] = newName;
      _emitLoaded();

      final savedNames = await _getSavedFolders();
      savedNames[folderId.toString()] = newName;
      await _updateSavedFolders(savedNames);
    } catch (e) {
      emit(KanbanError("Не удалось сохранить название папки"));
    }
  }

  // Локальное удаление папки и всех задач внутри неё
  Future<void> deleteFolder(int folderId) async {
    try {
      _folders.remove(folderId);
      _cachedTasks.removeWhere((t) => t.parentId == folderId);
      _emitLoaded();

      final savedNames = await _getSavedFolders();
      if (savedNames.remove(folderId.toString()) != null) {
        await _updateSavedFolders(savedNames);
      }
      await _saveLocalTasks();
    } catch (e) {
      emit(KanbanError("Ошибка при удалении папки"));
    }
  }

  // Создание новой задачи в конкретной колонке (пока только локально)
  Future<void> addTask(int folderId) async {
    try {
      final columnTasks = _cachedTasks.where((t) => t.parentId == folderId);
      final int newOrder = columnTasks.isEmpty 
          ? 1 
          : columnTasks.map((t) => t.order).fold(columnTasks.first.order, (min, e) => e < min ? e : min) - 1;

      final tempTask = Task(id: -DateTime.now().millisecondsSinceEpoch, parentId: folderId, name: "Новая задача", order: newOrder);
      
      _cachedTasks
        ..add(tempTask)
        ..sort((a, b) => a.order.compareTo(b.order));
      
      _emitLoaded();
      await _saveLocalTasks();
    } catch (e) {
      emit(KanbanError("Ошибка при добавлении задачи"));
    }
  }

  // Удаление задачи (с сервера, если ID положительный, иначе только из кэша)
  Future<void> deleteTask(int taskId) async {
    final previousTasks = List<Task>.from(_cachedTasks);
    try {
      _cachedTasks.removeWhere((t) => t.id == taskId);
      _emitLoaded();

      if (taskId < 0) {
        await _saveLocalTasks();
        return;
      }

      final success = await apiService.deleteTask(taskId);
      if (!success) throw Exception("Не удалось удалить на сервере.");
      
    } catch (e) {
      _cachedTasks = previousTasks;
      emit(KanbanError("Сбой при удалении."));
      _emitLoaded();
    }
  }

  // Сохранение изменений в полях задачи (синхронизация с сервером и памятью)
  Future<void> taskSave(int taskId, String fieldName, dynamic fieldValue) async { 
    try {
      if (taskId > 0) {
        final success = await apiService.saveTaskField(taskId, fieldName, fieldValue); 
        if (!success) {
          emit(KanbanError("Сервер не подтвердил сохранение."));
          return;
        }
      }

      final index = _cachedTasks.indexWhere((t) => t.id == taskId); 
      if (index != -1 && fieldName == 'name') { 
        _cachedTasks[index] = _cachedTasks[index].copyWith(name: fieldValue.toString()); 
        _emitLoaded();
        if (taskId < 0) await _saveLocalTasks();
      }
    } catch (e) { 
      emit(KanbanError("Сбой синхронизации: $e")); 
    }
  }

  // Создание новой пустой колонки (папки) локально
  Future<void> addFolder(String name) async {
    final previousFolders = Map<int, String>.from(_folders);
    try {
      final tempId = -DateTime.now().millisecondsSinceEpoch;
      _folders = {tempId: name, ..._folders};
      _emitLoaded();

      final savedNames = await _getSavedFolders();
      savedNames[tempId.toString()] = name;
      await _updateSavedFolders(savedNames);
    } catch (e) {
      _folders = previousFolders;
      emit(KanbanError('Ошибка в создании папки'));
      _emitLoaded();
    }
  }

  // Логика перемещения задачи (Drag-and-Drop) с пересчетом порядковых номеров
  Future<void> moveTask(Task task, int newParentId, int newOrder) async { 
    final previousTasks = List<Task>.from(_cachedTasks); 
    final oldParent = task.parentId; 
    final oldOrder = task.order; 

    // Расчет корректного индекса в пределах новой колонки
    final targetColTasks = _cachedTasks.where((t) => t.parentId == newParentId && t.id != task.id).toList();
    int maxAllowedOrder = targetColTasks.length + 1;
    int finalOrder = newOrder.clamp(1, maxAllowedOrder);

    if (oldParent == newParentId && oldOrder == finalOrder) return; 

    try {
      final List<Task> toUpdate = []; 
      _cachedTasks.removeWhere((t) => t.id == task.id); 

      if (oldParent == newParentId) { 
        // Логика смещения внутри одной колонки
        final movingDown = oldOrder < finalOrder;

        for (int i = 0; i < _cachedTasks.length; i++) {
          var t = _cachedTasks[i];
          if (t.parentId == oldParent) {
            if (movingDown && t.order > oldOrder && t.order <= finalOrder) {
              _cachedTasks[i] = t.copyWith(order: t.order - 1);
              toUpdate.add(_cachedTasks[i]);
            } 
            else if (!movingDown && t.order >= finalOrder && t.order < oldOrder) {
              _cachedTasks[i] = t.copyWith(order: t.order + 1);
              toUpdate.add(_cachedTasks[i]);
            }
          }
        }
      } else { 
        // Логика перемещения между разными колонками
        for (int i = 0; i < _cachedTasks.length; i++) { 
          var t = _cachedTasks[i]; 
          if (t.parentId == oldParent && t.order > oldOrder) { 
            _cachedTasks[i] = t.copyWith(order: t.order - 1); 
            toUpdate.add(_cachedTasks[i]); 
          } 
          else if (t.parentId == newParentId && t.order >= finalOrder) { 
            _cachedTasks[i] = t.copyWith(order: t.order + 1); 
            toUpdate.add(_cachedTasks[i]); 
          }
        }
      }

      // Обновление локального списка и уведомление UI
      final updatedTask = task.copyWith(parentId: newParentId, order: finalOrder); 
      _cachedTasks.add(updatedTask); 
      toUpdate.add(updatedTask); 
      _cachedTasks.sort((a, b) => a.order.compareTo(b.order)); 
      _emitLoaded();

      // Сохранение изменений на сервере и в памяти устройства
      for (var t in toUpdate.where((t) => t.id > 0)) { 
        if (t.id == task.id && oldParent != newParentId) { 
          await apiService.saveTaskField(t.id, 'parent_id', newParentId); 
        }
        await apiService.saveTaskField(t.id, 'order', t.order); 
      }
      await _saveLocalTasks(); 
    } catch (e) { 
      // Откат изменений при ошибке
      _cachedTasks = previousTasks; 
      emit(KanbanError("Сбой синхронизации.")); 
      _emitLoaded();
    }
  }
}