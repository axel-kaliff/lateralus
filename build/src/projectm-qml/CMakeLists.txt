cmake_minimum_required(VERSION 3.24)
project(projectm-qml VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.6 REQUIRED COMPONENTS Quick OpenGL)
find_package(PkgConfig REQUIRED)
pkg_check_modules(PROJECTM REQUIRED IMPORTED_TARGET libprojectM)
pkg_check_modules(PIPEWIRE REQUIRED IMPORTED_TARGET libpipewire-0.3)

qt_standard_project_setup(REQUIRES 6.6)

qt_add_qml_module(projectm-qml
    URI Lateralus.ProjectM
    VERSION 1.0
    PLUGIN_TARGET projectm-qml
    OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml/Lateralus/ProjectM"
    SOURCES
        src/pcmringbuffer.h
        src/pipewirecapture.h
        src/pipewirecapture.cpp
        src/projectmview.h
        src/projectmview.cpp
        src/projectmrenderer.h
        src/projectmrenderer.cpp
)

# The generated qmltyperegistrations.cpp includes headers by basename behind
# __has_include guards — src/ must be on the include path or registration
# silently compiles against nothing.
target_include_directories(projectm-qml PRIVATE src)

target_link_libraries(projectm-qml PRIVATE
    Qt6::Quick
    Qt6::OpenGL
    PkgConfig::PROJECTM
    PkgConfig::PIPEWIRE
)

include(GNUInstallDirs)
set(QML_INSTALL_DIR "${CMAKE_INSTALL_LIBDIR}/qt6/qml/Lateralus/ProjectM")

install(TARGETS projectm-qml DESTINATION "${QML_INSTALL_DIR}")
# qmldir and the generated .qmltypes land in OUTPUT_DIRECTORY at build time.
install(DIRECTORY "${CMAKE_BINARY_DIR}/qml/Lateralus/ProjectM/"
        DESTINATION "${QML_INSTALL_DIR}"
        FILES_MATCHING PATTERN "qmldir" PATTERN "*.qmltypes")
