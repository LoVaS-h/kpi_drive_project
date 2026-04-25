Overview

KPI-DRIVE Kanban is a desktop/web-oriented task management application designed for productivity. It provides a fluid user experience for organizing tasks into folders (columns) with advanced drag-and-drop capabilities.
Key Features

    State Management: Powered by flutter_bloc for predictable and reactive UI updates.

    Advanced Drag & Drop: Custom implementation allowing users to move tasks between columns with visual drop-placeholders.

    Intelligent Auto-Scroll: Includes a DragScrollManager that automatically scrolls the board horizontally or vertically when a task is dragged near the edges.

    Folder Management: Create, rename, and delete task columns (folders) dynamically.

    Persistence: Local state management using shared_preferences for task completion statuses.

    Modern UI: A sleek, dark-mode interface with radial gradients and micro-animations using AnimatedList.

Tech Stack

    Framework: Flutter

    State Management: Cubit (BLoC)

    Local Storage: Shared Preferences

    Architecture: Feature-first modular structure (UI, Logic, Data layers).

How to Run

    Ensure you have the Flutter SDK installed.

    Clone the repository.

    Run flutter pub get.

    Execute flutter run -d chrome (or your preferred desktop emulator).
