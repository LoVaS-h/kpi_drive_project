part of 'cubit.dart';

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