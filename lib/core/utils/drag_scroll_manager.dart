import 'dart:async';
import 'package:flutter/material.dart';

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