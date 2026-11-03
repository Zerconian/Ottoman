# Build environment for ottoman-shell (Qt 6 / CMake). Same Fedora release as the OS image so the binary
# links against the runtime the image ships. Rebuilt rarely; used by scripts/build-shell.sh and the OS image.
FROM quay.io/fedora/fedora:44
RUN dnf -y install cmake ninja-build gcc-c++ qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtwayland-devel && dnf clean all
