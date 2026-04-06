#!/usr/bin/env bash
# Build a CMAKE_PREFIX_PATH tree with headers and CMake packages needed by several
# portfolio CUDA projects (GTest, cxxopts, RapidJSON). Install prefix:
#   ${PORTFOLIO_CMAKE_PREFIX:-/tmp/portfolio-deps}
#
# GTest is pinned to v1.12.0 so CUDA targets that compile as C++11 can still include gtest.h.
#
# Does not install: FFTW, HDF5, system NTL/GMP, or cuPoly (those use distro packages or
# separate install steps).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PORTFOLIO_CMAKE_PREFIX:-/tmp/portfolio-deps}"
WORKDIR="${PORTFOLIO_CMAKE_BUILD_DIR:-/tmp/portfolio-cmake-src}"

mkdir -p "${WORKDIR}"
rm -rf "${PREFIX}"
mkdir -p "${PREFIX}"

clone_shallow() {
  local url="$1" dest="$2"
  rm -rf "${dest}"
  git clone --depth 1 "${url}" "${dest}"
}

# --- GoogleTest v1.12.0 (C++11-friendly for legacy .cu + gtest) ---
rm -rf "${WORKDIR}/googletest"
git clone --depth 1 --branch v1.12.0 https://github.com/google/googletest.git "${WORKDIR}/googletest"
cmake -B "${WORKDIR}/googletest/build" -S "${WORKDIR}/googletest" \
  -DCMAKE_INSTALL_PREFIX="${PREFIX}" -DBUILD_GMOCK=OFF -Dgtest_force_shared_crt=ON
cmake --build "${WORKDIR}/googletest/build" -j"$(nproc 2>/dev/null || echo 4)"
cmake --install "${WORKDIR}/googletest/build"

# --- cxxopts ---
clone_shallow https://github.com/jarro2783/cxxopts.git "${WORKDIR}/cxxopts"
cmake -B "${WORKDIR}/cxxopts/build" -S "${WORKDIR}/cxxopts" \
  -DCMAKE_INSTALL_PREFIX="${PREFIX}" -DCXXOPTS_BUILD_EXAMPLES=OFF -DCXXOPTS_BUILD_TESTS=OFF
cmake --build "${WORKDIR}/cxxopts/build" -j"$(nproc 2>/dev/null || echo 4)"
cmake --install "${WORKDIR}/cxxopts/build"

# --- RapidJSON ---
clone_shallow https://github.com/Tencent/rapidjson.git "${WORKDIR}/rapidjson"
cmake -B "${WORKDIR}/rapidjson/build" -S "${WORKDIR}/rapidjson" \
  -DCMAKE_INSTALL_PREFIX="${PREFIX}" -DRAPIDJSON_BUILD_DOC=OFF \
  -DRAPIDJSON_BUILD_EXAMPLES=OFF -DRAPIDJSON_BUILD_TESTS=OFF
cmake --build "${WORKDIR}/rapidjson/build" -j"$(nproc 2>/dev/null || echo 4)"
cmake --install "${WORKDIR}/rapidjson/build"

echo "Installed CMake deps under: ${PREFIX}"
echo "Run tests with:"
echo "  export PORTFOLIO_CMAKE_PREFIX=${PREFIX}"
echo "  export AUDIT_ROOT=/path/to/clones"
echo "  ${SCRIPT_DIR}/portfolio-repo-tests.sh"
