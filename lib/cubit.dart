import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'api_service.dart';

abstract class KanbanState extends Equatable {
  @override
  List<Object> get props => [];
}

class KanbanLoading extends KanbanState {}

class KanbanLoaded extends KanbanState {
  final List<Task> tasks;
  KanbanLoaded(this.tasks);

  @override
  List<Object> get props => [tasks];
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

  KanbanCubit(this.apiService) : super(KanbanLoading());

  Future<void> loadTasks() async {
    try {
      emit(KanbanLoading());
      _cachedTasks = await apiService.fetchTasks();

      _cachedTasks.sort((a, b) => a.order.compareTo(b.order));
      emit(KanbanLoaded(List.from(_cachedTasks)));
    } catch (e) {
      emit(KanbanError("Ошибка загрузки задач: $e"));
    }
  }

  Future<void> moveTask(Task task, int newParentId, int newOrder) async {
    final previousTasks = List<Task>.from(_cachedTasks);
    final oldParentId = task.parentId;
    final oldOrder = task.order;
    int maxOrderInTarget = _cachedTasks.where((t) => t.parentId == newParentId).length;
    if (oldParentId != newParentId) {
      maxOrderInTarget += 1; 
    }
    if (newOrder > maxOrderInTarget) {
      newOrder = maxOrderInTarget;
    }
    if (oldParentId == newParentId && oldOrder == newOrder) return;
    try {
      List<Task> tasksToUpdateOnServer = [];
      _cachedTasks.removeWhere((t) => t.id == task.id);
      if (oldParentId == newParentId) {
        for (int i = 0; i < _cachedTasks.length; i++) {
          var t = _cachedTasks[i];
          if (t.parentId == oldParentId) {
            if (oldOrder < newOrder && t.order > oldOrder && t.order <= newOrder) {
              _cachedTasks[i] = t.copyWith(order: t.order - 1);
              tasksToUpdateOnServer.add(_cachedTasks[i]);
            } 
            else if (oldOrder > newOrder && t.order >= newOrder && t.order < oldOrder) {
              _cachedTasks[i] = t.copyWith(order: t.order + 1);
              tasksToUpdateOnServer.add(_cachedTasks[i]);
            }
          }
        }
      } else {
        for (int i = 0; i < _cachedTasks.length; i++) {
          var t = _cachedTasks[i];
          if (t.parentId == oldParentId && t.order > oldOrder) {
            _cachedTasks[i] = t.copyWith(order: t.order - 1);
            tasksToUpdateOnServer.add(_cachedTasks[i]);
          } 
          else if (t.parentId == newParentId && t.order >= newOrder) {
            _cachedTasks[i] = t.copyWith(order: t.order + 1);
            tasksToUpdateOnServer.add(_cachedTasks[i]);
          }
        }
      }
      
      final updatedTask = task.copyWith(parentId: newParentId, order: newOrder);
      _cachedTasks.add(updatedTask);
      tasksToUpdateOnServer.add(updatedTask); 

      _cachedTasks.sort((a, b) => a.order.compareTo(b.order));
      emit(KanbanLoaded(List.from(_cachedTasks)));

      for (var t in tasksToUpdateOnServer) {
        if (t.id == task.id) {
          if (oldParentId != newParentId) {
            await apiService.saveTaskField(t.id, 'parent_id', newParentId);
          }
          await apiService.saveTaskField(t.id, 'order', newOrder);
        } else {
          await apiService.saveTaskField(t.id, 'order', t.order);
        }
      }
    } catch (e) {
      _cachedTasks = previousTasks;
      emit(KanbanError("Сбой синхронизации. Изменения порядков отменены."));
      emit(KanbanLoaded(List.from(_cachedTasks)));
    }
  }

  Future<void> taskSave(int taskId, String fieldName, dynamic fieldValue) async {
  try {
    final success = await apiService.saveTaskField(taskId, fieldName, fieldValue);
    if (success) {
      final index = _cachedTasks.indexWhere((t) => t.id == taskId);
      if (index != -1 && fieldName == 'name') {
        _cachedTasks[index] = _cachedTasks[index].editName(name: fieldValue.toString());
        emit(KanbanLoaded(List.from(_cachedTasks)));
      }
    } else {
      emit(KanbanError("Сервер не подтвердил сохранение."));
    }
  } catch (e) {
    emit(KanbanError("Сбой синхронизации: $e"));
  }
  }
}