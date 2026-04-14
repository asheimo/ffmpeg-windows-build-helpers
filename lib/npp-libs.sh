#!/usr/bin/env bash
# npp-libs.sh — installs NVIDIA Performance Primitives (NPP) headers,
# CUDA runtime headers, and Windows import libraries (.a) for cross-compilation.
# Required by ffmpeg --enable-libnpp for GPU-side pixel format conversion,
# which keeps subtitle compositing fully on the GPU pipeline (overlay_cuda).
#
# All components downloaded from NVIDIA redist archives — no toolkit install needed.
# https://developer.download.nvidia.com/compute/cuda/redist/

# Guard against being sourced more than once
[[ -n "${NPP_LIBS_SH_LOADED:-}" ]] && return
NPP_LIBS_SH_LOADED=1

# build_npp_libs()
# Downloads NPP and CUDA runtime Windows archives, installs headers and
# generates mingw-compatible .a import libraries from the Windows DLLs.
# Version controlled by NPP_LIBS_VERSION in versions.conf.
# Skips install if already completed successfully.
build_npp_libs() {
  local libs_version="${NPP_LIBS_VERSION:?NPP_LIBS_VERSION not set in versions.conf}"
  local cudart_version="${CUDART_VERSION:?CUDART_VERSION not set in versions.conf}"
  local nvcc_version="${NVCC_HEADERS_VERSION:?NVCC_HEADERS_VERSION not set in versions.conf}"

  local npp_archive="libnpp-windows-x86_64-${libs_version}-archive.zip"
  local cudart_archive="cuda_cudart-windows-x86_64-${cudart_version}-archive.zip"
  local nvcc_archive="cuda_nvcc-linux-x86_64-${nvcc_version}-archive.tar.xz"
  local npp_url="https://developer.download.nvidia.com/compute/cuda/redist/libnpp/windows-x86_64/${npp_archive}"
  local cudart_url="https://developer.download.nvidia.com/compute/cuda/redist/cuda_cudart/windows-x86_64/${cudart_archive}"
  local nvcc_url="https://developer.download.nvidia.com/compute/cuda/redist/cuda_nvcc/linux-x86_64/${nvcc_archive}"

  local touch_name
  touch_name="$(get_touchfile_name "already_installed_npp_libs_${libs_version}")"

  if [[ -f "$touch_name" ]]; then
    echo "  [install] Already installed, skipping."
    return
  fi

  echo ""
  echo "  NOTICE: The following steps will download NVIDIA proprietary software."
  echo "  By using the software you agree to comply with the terms of the license"
  echo "  agreement that accompanies the software. If you do not agree to the terms"
  echo "  of the license agreement, do not use the software."
  echo ""

  local downloads_dir="$SCRIPT_DIR/downloads"
  mkdir -p "$downloads_dir"

  # Step 1: Download and extract libnpp Windows archive
  if [[ ! -f "$downloads_dir/$npp_archive" ]]; then
    echo "  [download] Downloading NPP Windows archive..."
    curl "$npp_url" -L --retry 5 -o "$downloads_dir/$npp_archive"
  else
    echo "  [download] Already have $npp_archive, skipping."
  fi

  local npp_extract="$downloads_dir/libnpp-windows-extract"
  if [[ ! -d "$npp_extract" ]]; then
    echo "  [download] Extracting $npp_archive..."
    mkdir -p "$npp_extract"
    unzip -q "$downloads_dir/$npp_archive" -d "$npp_extract"
  else
    echo "  [download] Already extracted NPP, skipping."
  fi

  # Step 2: Download and extract cuda_cudart Windows archive (provides cuda_runtime.h)
  if [[ ! -f "$downloads_dir/$cudart_archive" ]]; then
    echo "  [download] Downloading CUDA runtime headers..."
    curl "$cudart_url" -L --retry 5 -o "$downloads_dir/$cudart_archive"
  else
    echo "  [download] Already have $cudart_archive, skipping."
  fi

  local cudart_extract="$downloads_dir/cuda-cudart-windows-extract"
  if [[ ! -d "$cudart_extract" ]]; then
    echo "  [download] Extracting $cudart_archive..."
    mkdir -p "$cudart_extract"
    unzip -q "$downloads_dir/$cudart_archive" -d "$cudart_extract"
  else
    echo "  [download] Already extracted CUDA runtime, skipping."
  fi

  # Step 3: Download and extract cuda_nvcc Linux archive (provides crt/ headers)
  if [[ ! -f "$downloads_dir/$nvcc_archive" ]]; then
    echo "  [download] Downloading CUDA nvcc headers (crt/)..."
    curl "$nvcc_url" -L --retry 5 -o "$downloads_dir/$nvcc_archive"
  else
    echo "  [download] Already have $nvcc_archive, skipping."
  fi

  local nvcc_extract="$downloads_dir/cuda-nvcc-extract"
  if [[ ! -d "$nvcc_extract" ]]; then
    echo "  [download] Extracting $nvcc_archive..."
    mkdir -p "$nvcc_extract"
    tar -xJf "$downloads_dir/$nvcc_archive" -C "$nvcc_extract"
  else
    echo "  [download] Already extracted CUDA nvcc headers, skipping."
  fi

  # Step 4: Copy headers to BUILD_PREFIX
  echo "  [install] Copying NPP headers..."
  mkdir -p "${BUILD_PREFIX}/include"
  cp -r "$npp_extract/libnpp-windows-x86_64-${libs_version}-archive/include/"* "${BUILD_PREFIX}/include/"

  echo "  [install] Copying CUDA runtime headers..."
  cp -r "$cudart_extract/cuda_cudart-windows-x86_64-${cudart_version}-archive/include/"* "${BUILD_PREFIX}/include/"

  echo "  [install] Copying CUDA nvcc crt headers..."
  cp -r "$nvcc_extract/cuda_nvcc-linux-x86_64-${nvcc_version}-archive/include/crt" "${BUILD_PREFIX}/include/"

  # Step 5: Generate mingw-compatible .a import libs from Windows DLLs.
  # gendef reads the DLL export table and writes a .def file.
  # dlltool generates a .a import library from the .def file.
  # ffmpeg configure checks for -lnppig, -lnppicc etc. so names must match exactly.
  echo "  [dlltool] Generating NPP import libraries..."
  mkdir -p "${BUILD_PREFIX}/lib"

  local dll_dir="$npp_extract/libnpp-windows-x86_64-${libs_version}-archive/bin"
  local dlltool="${CROSS_PREFIX}dlltool"
  local gendef
  gendef="$(dirname "$(command -v "${CROSS_PREFIX}dlltool")")/gendef"

  local -A dll_to_lib=(
    ["nppc64_12.dll"]="libnppc.a"
    ["nppial64_12.dll"]="libnppial.a"
    ["nppicc64_12.dll"]="libnppicc.a"
    ["nppidei64_12.dll"]="libnppidei.a"
    ["nppif64_12.dll"]="libnppif.a"
    ["nppig64_12.dll"]="libnppig.a"
    ["nppim64_12.dll"]="libnppim.a"
    ["nppist64_12.dll"]="libnppist.a"
    ["nppisu64_12.dll"]="libnppisu.a"
    ["nppitc64_12.dll"]="libnppitc.a"
    ["npps64_12.dll"]="libnpps.a"
  )

  for dll in "${!dll_to_lib[@]}"; do
    local lib="${dll_to_lib[$dll]}"
    local def_file="${BUILD_PREFIX}/lib/${dll%.dll}.def"
    echo "    $dll -> $lib"
    "$gendef" - "$dll_dir/$dll" > "$def_file"
    "$dlltool" -m i386:x86-64 -D "$dll" -d "$def_file" -l "${BUILD_PREFIX}/lib/${lib}"
    rm -f "$def_file"
  done

  mkdir -p "$(dirname "$touch_name")"
  touch "$touch_name"

  # Copy NPP DLLs to release folder alongside ffmpeg.exe
  echo "  [install] Copying NPP DLLs to release folder..."
  mkdir -p "$SCRIPT_DIR/release"
  cp "$dll_dir"/*.dll "$SCRIPT_DIR/release/"

  echo "  [install] NPP headers and import libraries installed."
}
