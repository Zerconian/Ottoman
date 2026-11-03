cmake_minimum_required(VERSION 3.21)
project(ottoman-shell VERSION 0.1 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Qml Quick)
qt_standard_project_setup(REQUIRES 6.5)
qt_add_executable(ottoman-shell src/main.cpp src/AppModel.cpp src/Sway.cpp)
# QML files live in qml/; without aliases Qt registers them under a nested path and "Main" is not found
# (first VM run 2026-11-03: 'Module "Ottoman" contains no type named "Main"', shell restart loop).
set_source_files_properties(qml/Main.qml PROPERTIES QT_RESOURCE_ALIAS Main.qml)
set_source_files_properties(qml/Tile.qml PROPERTIES QT_RESOURCE_ALIAS Tile.qml)
qt_add_qml_module(ottoman-shell URI Ottoman VERSION 1.0
  QML_FILES qml/Main.qml qml/Tile.qml
  RESOURCE_PREFIX /)
target_link_libraries(ottoman-shell PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick)
install(TARGETS ottoman-shell RUNTIME DESTINATION libexec/ottoman)
