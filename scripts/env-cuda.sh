# Source this file so CMake and nvcc resolve the CUDA toolkit in minimal environments
# (e.g. scripts, CI, or SSH without full login profiles).
#
#   source scripts/env-cuda.sh
#   CUDA_HOME=/opt/cuda-12.4 source scripts/env-cuda.sh

if [ -z "${CUDA_HOME:-}" ]; then
  if [ -x /usr/local/cuda/bin/nvcc ]; then
    CUDA_HOME=/usr/local/cuda
  elif command -v nvcc >/dev/null 2>&1; then
    _nvcc=$(command -v nvcc)
    CUDA_HOME="$(cd "$(dirname "$_nvcc")/.." && pwd)"
    unset _nvcc
  fi
fi

if [ -z "${CUDA_HOME:-}" ] || [ ! -d "${CUDA_HOME}" ]; then
  echo "env-cuda.sh: set CUDA_HOME to your CUDA toolkit root (nvcc not found)." >&2
  return 1 2>/dev/null || exit 1
fi

if [ ! -x "${CUDA_HOME}/bin/nvcc" ]; then
  echo "env-cuda.sh: missing ${CUDA_HOME}/bin/nvcc" >&2
  return 1 2>/dev/null || exit 1
fi

export CUDA_HOME
export CUDA_PATH="${CUDA_HOME}"
export CUDAToolkit_ROOT="${CUDA_HOME}"
export CUDACXX="${CUDA_HOME}/bin/nvcc"
export PATH="${CUDA_HOME}/bin:${PATH}"

if [ -d "${CUDA_HOME}/lib64" ]; then
  export LD_LIBRARY_PATH="${CUDA_HOME}/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
fi

# Helps CMake FindCUDAToolkit when the compiler is not on default PATH.
export CMAKE_CUDA_COMPILER="${CUDA_HOME}/bin/nvcc"
