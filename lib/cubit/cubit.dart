import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../api_service.dart';

abstract class KanbanState extends Equatable {
  @override
  List<Object> get props => [];
}

class KanbanLoading extends KanbanState {}

class KanbanLoaded extends KanbanState {
  final List<Task> tasks;
  final Map<int, String> folders;
  
  KanbanLoaded(this.tasks, this.folders);

  @override
  List<Object> get props => [tasks, folders];
}

class KanbanError extends KanbanState {
  final String message;
  KanbanError(this.message);
  
  @override
  List<Object> get props => [message];
}

class KanbanCubit extends Cubit<KanbanState> {
  final ApiService apiService;
  List<Task> _cachedTasks = [];
  Map<int, String> _folders = {};

  KanbanCubit(this.apiService) : super(KanbanLoading());

  static const String _storageKey = 'custom_folder_names';
  static const String _localTasksKey = 'local_tasks';

  
  Future<void> _saveLocalTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final localTasks = _cachedTasks.where((t) => t.id < 0).map((t) => {
      'indicator_to_mo_id': t.id,
      'parent_id': t.parentId,
      'name': t.name,
      'order': t.order,
    }).toList();
    await prefs.setString(_localTasksKey, jsonEncode(localTasks));
  }

  Future<void> loadTasks() async {
    try {
      emit(KanbanLoading());
      _cachedTasks = await apiService.fetchTasks();
      
      final prefs = await SharedPreferences.getInstance();

      
      final String? localTasksRaw = prefs.getString(_localTasksKey);
      if (localTasksRaw != null) {
        final List<dynamic> localTasksList = jsonDecode(localTasksRaw);
        _cachedTasks.addAll(localTasksList.map((json) => Task.fromJson(json)));
      }

      
      final String? savedNamesRaw = prefs.getString(_storageKey);
      Map<String, dynamic> savedNames = savedNamesRaw != null ? jsonDecode(savedNamesRaw) : {};

      
      final Set<int> uniquePids = _cachedTasks.map((t) => t.parentId).toSet();
      for (var key in savedNames.keys) {
        uniquePids.add(int.parse(key));
      }
      
      final List<int> sortedPids = uniquePids.toList()..sort();

      
      final Map<int, String> autoFolders = {};
      for (int i = 0; i < sortedPids.length; i++) {
        int pid = sortedPids[i];
        if (savedNames.containsKey(pid.toString())) {
          autoFolders[pid] = savedNames[pid.toString()];
        } else {
          autoFolders[pid] = 'Папка ${i + 1}';
        }
      }
      
      _folders = autoFolders;
      _cachedTasks.sort((a, b) => a.order.compareTo(b.order));
      
      emit(KanbanLoaded(List.from(_cachedTasks), Map.from(_folders)));
    } catch (e) {
      emit(KanbanError("Ошибка загрузки задач: $e"));
    }
  }



  Future<void> renameFolder(int folderId, String newName) async {
    try {
      _folders[folderId] = newName;
      emit(KanbanLoaded(List.from(_cachedTasks), Map.from(_folders)));

      final prefs = await SharedPreferences.getInstance();
      final String? savedNamesRaw = prefs.getString(_storageKey);
      Map<String, dynamic> savedNames = savedNamesRaw != null ? jsonDecode(savedNamesRaw) : {};
      
      savedNames[folderId.toString()] = newName;
      await prefs.setString(_storageKey, jsonEncode(savedNames));
    } catch (e) {
      emit(KanbanError("Не удалось сохранить название папки"));
    }
  }

  Future<void> deleteTask(int taskId) async {
    final previousTasks = List<Task>.from(_cachedTasks);
    try {
      _cachedTasks.removeWhere((t) => t.id == taskId);
      emit(KanbanLoaded(List.from(_cachedTasks), Map.from(_folders)));
      
      
      if (taskId < 0) {
        await _saveLocalTasks();
        return;
      }

      final success = await apiService.deleteTask(taskId);
      if (!success) {
        _cachedTasks = previousTasks;
        emit(KanbanError("Не удалось удалить на сервере."));
        emit(KanbanLoaded(List.from(_cachedTasks), Map.from(_folders)));
      }
    } catch (e) {
      _cachedTasks = previousTasks;
      emit(KanbanError("Сбой при удалении."));
      emit(KanbanLoaded(List.from(_cachedTasks), Map.from(_folders)));
    }
  }

  Future<void> addFolder(String name) async {
    final previousFolders = Map<int, String>.from(_folders);
    try {
      
      final tempId = -DateTime.now().millisecondsSinceEpoch;
      
      _folders = {tempId: name, ..._folders};
      emit(KanbanLoaded(List.from(_cachedTasks), Map.from(_folders)));

      
      final prefs = await SharedPreferences.getInstance();
      final String? savedNamesRaw = prefs.getString(_storageKey);
      Map<String, dynamic> savedNames = savedNamesRaw != null ? jsonDecode(savedNamesRaw) : {};
      savedNames[tempId.toString()] = name;
      await prefs.setString(_storageKey, jsonEncode(savedNames));

    } catch (e) {
      _folders = previousFolders;
      emit(KanbanError('Ошибка в создании папки'));
      emit(KanbanLoaded(List.from(_cachedTasks), Map.from(_folders)));
    }
  }

  Future<void> moveTask(Task task, int newParentId, int newOrder) async { 
    final previousTasks = List<Task>.from(_cachedTasks); 
    final oldParentId = task.parentId; 
    final oldOrder = task.order; 

    int maxOrderInTarget = _cachedTasks.where((t) => t.parentId == newParentId).length; 
    if (oldParentId != newParentId) maxOrderInTarget += 1; 
    if (newOrder > maxOrderInTarget) newOrder = maxOrderInTarget; 

    if (oldParentId == newParentId && oldOrder == newOrder) return; 

    try {
      List<Task> tasksToUpdateOnServer = []; 
      _cachedTasks.removeWhere((t) => t.id == task.id); 

      int finalNewOrder = newOrder;

      
      if (oldParentId == newParentId) { 
        if (oldOrder < newOrder) {
          
          
          finalNewOrder = newOrder - 1;
          for (int i = 0; i < _cachedTasks.length; i++) {
            var t = _cachedTasks[i];
            if (t.parentId == oldParentId && t.order > oldOrder && t.order < newOrder) {
              _cachedTasks[i] = t.copyWith(order: t.order - 1);
              tasksToUpdateOnServer.add(_cachedTasks[i]);
            }
          }
        } else {
          
          finalNewOrder = newOrder;
          for (int i = 0; i < _cachedTasks.length; i++) {
            var t = _cachedTasks[i];
            if (t.parentId == oldParentId && t.order >= newOrder && t.order < oldOrder) {
              _cachedTasks[i] = t.copyWith(order: t.order + 1);
              tasksToUpdateOnServer.add(_cachedTasks[i]);
            }
          }
        }
      } else { 
        
        finalNewOrder = newOrder;
        for (int i = 0; i < _cachedTasks.length; i++) { 
          var t = _cachedTasks[i]; 
          if (t.parentId == oldParentId && t.order > oldOrder) { 
            _cachedTasks[i] = t.copyWith(order: t.order - 1); 
            tasksToUpdateOnServer.add(_cachedTasks[i]); 
          } else if (t.parentId == newParentId && t.order >= newOrder) { 
            _cachedTasks[i] = t.copyWith(order: t.order + 1); 
            tasksToUpdateOnServer.add(_cachedTasks[i]); 
          }
        }
      }

      final updatedTask = task.copyWith(parentId: newParentId, order: finalNewOrder); 
      _cachedTasks.add(updatedTask); 
      tasksToUpdateOnServer.add(updatedTask); 

      _cachedTasks.sort((a, b) => a.order.compareTo(b.order)); 
      emit(KanbanLoaded(List.from(_cachedTasks), Map.from(_folders)));

      
      for (var t in tasksToUpdateOnServer) { 
        if (t.id < 0) continue; 

        if (t.id == task.id) { 
          if (oldParentId != newParentId) { 
            await apiService.saveTaskField(t.id, 'parent_id', newParentId); 
          }
          await apiService.saveTaskField(t.id, 'order', finalNewOrder); 
        } else { 
          await apiService.saveTaskField(t.id, 'order', t.order); 
        }
      }
      await _saveLocalTasks(); 
    } catch (e) { 
      _cachedTasks = previousTasks; 
      emit(KanbanError("Сбой синхронизации. Изменения порядков отменены.")); 
      emit(KanbanLoaded(List.from(_cachedTasks), Map.from(_folders)));
    }
  }

  Future<void> taskSave(int taskId, String fieldName, dynamic fieldValue) async { 
    try {
      if (taskId < 0) {
        
        final index = _cachedTasks.indexWhere((t) => t.id == taskId); 
        if (index != -1 && fieldName == 'name') { 
          _cachedTasks[index] = _cachedTasks[index].editName(name: fieldValue.toString()); 
          emit(KanbanLoaded(List.from(_cachedTasks), Map.from(_folders)));
          await _saveLocalTasks();
        }
        return;
      }

      final success = await apiService.saveTaskField(taskId, fieldName, fieldValue); 
      if (success) { 
        final index = _cachedTasks.indexWhere((t) => t.id == taskId); 
        if (index != -1 && fieldName == 'name') { 
          _cachedTasks[index] = _cachedTasks[index].editName(name: fieldValue.toString()); 
          emit(KanbanLoaded(List.from(_cachedTasks), Map.from(_folders)));
        }
      } else { 
        emit(KanbanError("Сервер не подтвердил сохранение.")); 
      }
    } catch (e) { 
      emit(KanbanError("Сбой синхронизации: $e")); 
    }
  }

  Future<void> addTask(int folderId) async {
    try {
      const String defaultName = "Новая задача";
      final columnTasks = _cachedTasks.where((t) => t.parentId == folderId).toList();
      
      
      final int newOrder = columnTasks.isEmpty ? 1 : columnTasks.map((t) => t.order).reduce((a, b) => a < b ? a : b) - 1;

      final tempTask = Task(id: -DateTime.now().millisecondsSinceEpoch, parentId: folderId, name: defaultName, order: newOrder);
      _cachedTasks.add(tempTask);
      
      
      _cachedTasks.sort((a, b) => a.order.compareTo(b.order));
      
      emit(KanbanLoaded(List.from(_cachedTasks), Map.from(_folders)));
      
      
      await _saveLocalTasks();
    } catch (e) {
      emit(KanbanError("Ошибка при добавлении задачи"));
    }
  }

  Future<void> deleteFolder(int folderId) async {
    try {
      
      _folders.remove(folderId);
      
      
      
      _cachedTasks.removeWhere((t) => t.parentId == folderId);
      
      
      emit(KanbanLoaded(List.from(_cachedTasks), Map.from(_folders)));

      final prefs = await SharedPreferences.getInstance();
      
      
      final String? savedNamesRaw = prefs.getString(_storageKey);
      if (savedNamesRaw != null) {
        Map<String, dynamic> savedNames = jsonDecode(savedNamesRaw);
        savedNames.remove(folderId.toString());
        await prefs.setString(_storageKey, jsonEncode(savedNames));
      }

      
      await _saveLocalTasks();

    } catch (e) {
      emit(KanbanError("Ошибка при удалении папки"));
      
    }
  }
}