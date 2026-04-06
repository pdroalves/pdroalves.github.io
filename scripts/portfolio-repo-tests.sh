#!/usr/bin/env bash
# Strict compile + test audit for portfolio GitHub repos (see src/content/portfolio.yaml).
# Requires: CUDA env (source env-cuda.sh), Node/pnpm, git, cmake, etc.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env-cuda.sh
source "${SCRIPT_DIR}/env-cuda.sh"

# Optional: aggregate CMAKE_PREFIX_PATH for FIND_PACKAGE (GTest, cxxopts, RapidJSON, cuPoly, …).
# Example: build deps with scripts/bootstrap-portfolio-cmake-deps.sh, then:
#   export PORTFOLIO_CMAKE_PREFIX=/tmp/portfolio-deps
if [ -n "${PORTFOLIO_CMAKE_PREFIX:-}" ] && [ -d "${PORTFOLIO_CMAKE_PREFIX}/lib/cmake" ]; then
  export CMAKE_PREFIX_PATH="${PORTFOLIO_CMAKE_PREFIX}:${CMAKE_PREFIX_PATH:-}"
elif [ -d "${CXXOPTS_PREFIX:-/tmp/portfolio-cxxopts-prefix}/lib/cmake/cxxopts" ]; then
  export CMAKE_PREFIX_PATH="${CXXOPTS_PREFIX:-/tmp/portfolio-cxxopts-prefix}:${CMAKE_PREFIX_PATH:-}"
fi

if [ -n "${PORTFOLIO_CMAKE_PREFIX:-}" ] && [ -d "${PORTFOLIO_CMAKE_PREFIX}/include/rapidjson" ]; then
  export CPATH="${PORTFOLIO_CMAKE_PREFIX}/include:${CPATH:-}"
fi

# Parent directory of the cloned repositories (each repo is a direct child).
# Example: AUDIT_ROOT=/tmp/portfolio-clones ./scripts/portfolio-repo-tests.sh
AUDIT_ROOT="${AUDIT_ROOT:-$(pwd)}"
LOG="${AUDIT_ROOT}/logs"
mkdir -p "${LOG}"
SUMMARY="${LOG}/TEST_SUMMARY.txt"
SUMMARY_LOCK="${LOG}/.summary.lock"
: > "${SUMMARY}"
: > "${SUMMARY_LOCK}"

cmake_build_test() {
  local srcdir="$1"
  cd "${srcdir}" || exit 2
  rm -rf build
  cmake -B build -S . \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_COMPILER="${CUDA_HOME}/bin/nvcc"
  cmake --build build -j"$(nproc 2>/dev/null || echo 4)"
  local n
  n=$(ctest --test-dir build -N 2>/dev/null | awk '/Total Tests:/ {print $3}')
  if [ -z "${n:-}" ] || [ "$n" = "0" ]; then
    echo "FAIL: CTest reports 0 tests (configure incomplete or project has no CTest tests)"
    exit 1
  fi
  ctest --test-dir build --output-on-failure
}

run_repo() {
  local name="$1"
  local log="${LOG}/${name}.log"
  local ec=0
  (
    set -euo pipefail
    echo "=== ${name} ==="
    date -Iseconds
    case "${name}" in
      farewell-core)
        cd "${AUDIT_ROOT}/farewell-core"
        npm ci
        npm run compile
        npm test
        ;;
      chainchat)
        cd "${AUDIT_ROOT}/chainchat"
        pnpm install --frozen-lockfile 2>/dev/null || pnpm install
        pnpm run compile 2>/dev/null || pnpm run hardhat:compile
        pnpm test
        ;;
      OhMyCriterion)
        cd "${AUDIT_ROOT}/OhMyCriterion"
        bash -n ohmycriterion.sh
        chmod +x ohmycriterion.sh
        ./ohmycriterion.sh --help >/dev/null
        ;;
      fhe-aes-on-gpu-cpp)
        cmake_build_test "${AUDIT_ROOT}/fhe-aes-on-gpu-cpp"
        ;;
      cupoly)
        cmake_build_test "${AUDIT_ROOT}/cupoly"
        ;;
      cuyashe)
        cd "${AUDIT_ROOT}/cuyashe"
        make -j"$(nproc 2>/dev/null || echo 4)" tests
        if [ -x bin/test ]; then
          ./bin/test --run_test=* 2>/dev/null || ./bin/test
        else
          echo "FAIL: bin/test missing after build"
          exit 1
        fi
        ;;
      encrypted-mongodb)
        cd "${AUDIT_ROOT}/encrypted-mongodb/src/orelewi"
        make clean 2>/dev/null || true
        make -j"$(nproc 2>/dev/null || echo 4)"
        ./tests/test_ore
        ./tests/test_ore_blk
        ;;
      spog-ckks)
        cmake_build_test "${AUDIT_ROOT}/spog-ckks"
        ;;
      spog-bfv)
        cmake_build_test "${AUDIT_ROOT}/spog-bfv"
        ;;
      aoa)
        cmake_build_test "${AUDIT_ROOT}/aoa/aoa-dgt"
        cmake_build_test "${AUDIT_ROOT}/aoa/aoa-ntt"
        ;;
      aoa-logistic-regression)
        cmake_build_test "${AUDIT_ROOT}/aoa-logistic-regression"
        ;;
      *)
        echo "unknown repo ${name}"
        exit 2
        ;;
    esac
  ) >"${log}" 2>&1 || ec=$?
  (
    flock 200
    if [ "${ec}" -eq 0 ]; then
      echo "PASS|${name}|see ${log}" >> "${SUMMARY}"
    else
      echo "FAIL|${name}|exit ${ec}|see ${log}" >> "${SUMMARY}"
    fi
  ) 200>>"${SUMMARY_LOCK}"
  return "${ec}"
}

export -f run_repo cmake_build_test
export AUDIT_ROOT LOG SUMMARY SUMMARY_LOCK

repos=(
  farewell-core
  chainchat
  OhMyCriterion
  fhe-aes-on-gpu-cpp
  cupoly
  cuyashe
  encrypted-mongodb
  spog-ckks
  spog-bfv
  aoa
  aoa-logistic-regression
)

max_jobs="${PORTFOLIO_TEST_JOBS:-3}"
running=0
for name in "${repos[@]}"; do
  while [ "$(jobs -rp 2>/dev/null | wc -l)" -ge "${max_jobs}" ]; do
    sleep 0.3
  done
  run_repo "${name}" &
done
wait

echo "--- done ---"
cat "${SUMMARY}"
