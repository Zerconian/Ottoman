cmake_minimum_required(VERSION 3.21)
project(ottoman-shell VERSION 0.1 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Qml Quick Network DBus)
qt_standard_project_setup(REQUIRES 6.5)
qt_add_executable(ottoman-shell src/main.cpp src/AppModel.cpp src/Sway.cpp src/Jellyfin.cpp src/ItemModel.h src/System.cpp src/ScreenSaverService.cpp src/ShellControl.cpp)
# QML files live in qml/; without aliases Qt registers them under a nested path and "Main" is not found
# (first VM run 2026-11-03: 'Module "Ottoman" contains no type named "Main"', shell restart loop).
set_source_files_properties(qml/Main.qml PROPERTIES QT_RESOURCE_ALIAS Main.qml)
set_source_files_properties(qml/Tile.qml PROPERTIES QT_RESOURCE_ALIAS Tile.qml)
set_source_files_properties(qml/Card.qml PROPERTIES QT_RESOURCE_ALIAS Card.qml)
set_source_files_properties(qml/SignIn.qml PROPERTIES QT_RESOURCE_ALIAS SignIn.qml)
set_source_files_properties(qml/Field.qml PROPERTIES QT_RESOURCE_ALIAS Field.qml)
set_source_files_properties(qml/Keyboard.qml PROPERTIES QT_RESOURCE_ALIAS Keyboard.qml)
set_source_files_properties(qml/OptionList.qml PROPERTIES QT_RESOURCE_ALIAS OptionList.qml)
set_source_files_properties(qml/Settings.qml PROPERTIES QT_RESOURCE_ALIAS Settings.qml)
set_source_files_properties(qml/Saver.qml PROPERTIES QT_RESOURCE_ALIAS Saver.qml)
set_source_files_properties(qml/FirstRun.qml PROPERTIES QT_RESOURCE_ALIAS FirstRun.qml)
set_source_files_properties(qml/TileMenu.qml PROPERTIES QT_RESOURCE_ALIAS TileMenu.qml)
set_source_files_properties(qml/AddApp.qml PROPERTIES QT_RESOURCE_ALIAS AddApp.qml)
set_source_files_properties(qml/Dialog.qml PROPERTIES QT_RESOURCE_ALIAS Dialog.qml)
# Default RESOURCE_PREFIX (/qt/qml) keeps the embedded module on the engine's import path. A custom
# prefix only worked when run from the build tree, where Qt found the loose qmldir beside the binary
# (2026-11-03: image run failed, offscreen check from build/ passed).
qt_add_qml_module(ottoman-shell URI Ottoman VERSION 1.0
  QML_FILES qml/Main.qml qml/Tile.qml qml/Card.qml qml/SignIn.qml qml/Field.qml qml/Keyboard.qml qml/OptionList.qml qml/Settings.qml qml/Saver.qml qml/FirstRun.qml qml/TileMenu.qml qml/AddApp.qml qml/Dialog.qml)
target_link_libraries(ottoman-shell PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::Network Qt6::DBus)
install(TARGETS ottoman-shell RUNTIME DESTINATION libexec/ottoman)
