{ stdenv
, lib
, addOpenGLRunpath
, fetchFromGitHub
, fetchFromGitLab
, fetchpatch
, fetchurl
, symlinkJoin
, Foundation
, abseil-cpp
, cmake
, cudaPackages_11_8
, libpng
, nlohmann_json
, nsync
, pkg-config
, python3Packages
, re2
, zlib
, microsoft-gsl
, iconv
, gtest
, protobuf3_21
, pythonSupport ? true
, tensorrtSupport ? true }:

let
  howard-hinnant-date = fetchFromGitHub {
    owner = "HowardHinnant";
    repo = "date";
    rev = "v2.4.1";
    sha256 = "sha256-BYL7wxsYRI45l8C3VwxYIIocn5TzJnBtU0UZ9pHwwZw=";
  };

  eigen = fetchFromGitLab {
    owner = "libeigen";
    repo = "eigen";
    rev = "d10b27fe37736d2944630ecd7557cefa95cf87c9";
    sha256 = "sha256-Lmco0s9gIm9sIw7lCr5Iewye3RmrHEE4HLfyzRkQCm0=";
  };

  mp11 = fetchFromGitHub {
    owner = "boostorg";
    repo = "mp11";
    rev = "boost-1.79.0";
    sha256 = "sha256-ZxgPDLvpISrjpEHKpLGBowRKGfSwTf6TBfJD18yw+LM=";
  };

  safeint = fetchFromGitHub {
    owner = "dcleblanc";
    repo = "safeint";
    rev = "ff15c6ada150a5018c5ef2172401cb4529eac9c0";
    sha256 = "sha256-PK1ce4C0uCR4TzLFg+elZdSk5DdPCRhhwT3LvEwWnPU=";
  };

  pytorch_cpuinfo = fetchFromGitHub {
    owner = "pytorch";
    repo = "cpuinfo";
    # There are no tags in the repository
    rev = "5916273f79a21551890fd3d56fc5375a78d1598d";
    sha256 = "sha256-nXBnloVTuB+AVX59VDU/Wc+Dsx94o92YQuHp3jowx2A=";
  };

  flatbuffers = fetchFromGitHub {
    owner = "google";
    repo = "flatbuffers";
    rev = "v1.12.0";
    sha256 = "sha256-L1B5Y/c897Jg9fGwT2J3+vaXsZ+lfXnskp8Gto1p/Tg=";
  };

  gtest' = gtest.overrideAttrs (oldAttrs: rec {
    version = "1.13.0";
    src = fetchFromGitHub {
      owner = "google";
      repo = "googletest";
      rev = "v${version}";
      hash = "sha256-LVLEn+e7c8013pwiLzJiiIObyrlbBHYaioO/SWbItPQ=";
    };
    });

  cuda_joined = symlinkJoin {
    name = "cuda-joined-for-onnxruntime";
    paths = [ cudaPackages_11_8.cudatoolkit cudaPackages_11_8.cudnn ]
      ++ lib.optionals tensorrtSupport [
        cudaPackages_11_8.tensorrt
        cudaPackages_11_8.tensorrt.dev
      ];
  };

  onnx-tensorrt = fetchFromGitHub {
    owner = "onnx";
    repo = "onnx-tensorrt";
    rev = "ba6a4fb34fdeaa3613bf981610c657e7b663a699";
    sha256 = "sha256-BcvkX0hX3AmogTFwILs86/MuITkknfuCAaaOuBKRjv8=";
    fetchSubmodules = true;
  };

  cutlass = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "cutlass";
    rev = "v3.0.0";
    sha256 = "sha256-YPD5Sy6SvByjIcGtgeGH80TEKg2BtqJWSg46RvnJChY=";
  };

  pytorch-cpuinfo = fetchFromGitHub {
    owner = "pytorch";
    repo = "cpuinfo";
    rev = "5916273f79a21551890fd3d56fc5375a78d1598d";
    sha256 = "sha256-nXBnloVTuB+AVX59VDU/Wc+Dsx94o92YQuHp3jowx2A=";
  };
  
in
cudaPackages_11_8.backendStdenv.mkDerivation rec {
  pname = "onnxruntime";
  version = "1.15.1";

  __noChroot = true;
  
  src = fetchFromGitHub {
    url = "https://github.com/microsoft/onnxruntime.git";
    owner = "microsoft";
    repo = "onnxruntime";
    rev = "v${version}";
    sha256 = "sha256-SnHo2sVACc++fog7Tg6f2LK/Sv/EskFzN7RZS7D113s=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    cmake
    pkg-config
    python3Packages.python
    protobuf3_21
  ] ++ lib.optionals pythonSupport (with python3Packages; [
    setuptools
    wheel
    pip
    pythonOutputDistHook
  ]) ++ lib.optionals tensorrtSupport [
    cudaPackages_11_8.autoAddOpenGLRunpathHook
  ];

  buildInputs = [
    libpng
    zlib
    nlohmann_json
    nsync
    re2
    microsoft-gsl
  ] ++ lib.optionals pythonSupport [
    python3Packages.numpy
    python3Packages.pybind11
    python3Packages.packaging
  ] ++ lib.optionals stdenv.isDarwin [
    Foundation
    iconv
  ] ++ lib.optionals tensorrtSupport [
    cuda_joined
  ];

  nativeCheckInputs = lib.optionals pythonSupport (with python3Packages; [
    gtest'
    pytest
    sympy
    onnx
  ]);

  # TODO: build server, and move .so's to lib output
  # Python's wheel is stored in a separate dist output
  outputs = [ "out" "dev" ] ++ lib.optionals pythonSupport [ "dist" ];

  enableParallelBuilding = true;

  cmakeDir = "../cmake";

  cmakeFlags = [
    "--compile-no-warning-as-error"
    "-DABSL_ENABLE_INSTALL=ON"
    "-DCMAKE_BUILD_TYPE=RELEASE"
    "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
    "-DFETCHCONTENT_QUIET=OFF"
    "-DFETCHCONTENT_SOURCE_DIR_ABSEIL_CPP=${abseil-cpp.src}"
    "-DFETCHCONTENT_SOURCE_DIR_DATE=${howard-hinnant-date}"
    "-DFETCHCONTENT_SOURCE_DIR_EIGEN=${eigen}"
    "-DFETCHCONTENT_SOURCE_DIR_FLATBUFFERS=${flatbuffers}"
    "-DFETCHCONTENT_SOURCE_DIR_GOOGLE_NSYNC=${nsync.src}"
    "-DFETCHCONTENT_SOURCE_DIR_MP11=${mp11}"
    "-DFETCHCONTENT_SOURCE_DIR_ONNX=${python3Packages.onnx.src}"
    "-DFETCHCONTENT_SOURCE_DIR_PYTORCH_CPUINFO=${pytorch_cpuinfo}"
    "-DFETCHCONTENT_SOURCE_DIR_RE2=${re2.src}"
    "-DFETCHCONTENT_SOURCE_DIR_SAFEINT=${safeint}"
    "-DFETCHCONTENT_TRY_FIND_PACKAGE_MODE=ALWAYS"
    "-Donnxruntime_BUILD_SHARED_LIB=ON"
    "-Donnxruntime_BUILD_UNIT_TESTS=ON"
    "-Donnxruntime_ENABLE_LTO=ON"
    "-Donnxruntime_USE_FULL_PROTOBUF=OFF"
  ] ++ lib.optionals pythonSupport [
    "-Donnxruntime_ENABLE_PYTHON=ON"
  ] ++ lib.optionals tensorrtSupport [
    "-Donnxruntime_USE_CUDA=ON"
    "-DCUDA_CUDA_LIBRARY=${cuda_joined}/lib/stubs"
    "-Donnxruntime_CUDA_HOME=${cuda_joined}"
    "-Donnxruntime_CUDNN_HOME=${cuda_joined}/lib"
    "-Donnxruntime_USE_TENSORRT_BUILTIN_PARSER=ON"
    "-DFETCHCONTENT_SOURCE_DIR_ONNX_TENSORRT=${onnx-tensorrt}"
    "-Donnxruntime_USE_TENSORRT=ON"
    "-Donnxruntime_TENSORRT_HOME=${cuda_joined}"
    "-DTENSORRT_HOME=${cuda_joined}"
    "-DTENSORRT_INCLUDE_DIR=${cuda_joined}/include"
    "-DFETCHCONTENT_SOURCE_DIR_GSL=${microsoft-gsl.src}"
    "-DFETCHCONTENT_SOURCE_DIR_CUTLASS=${cutlass}"
    "-DFETCHCONTENT_SOURCE_DIR_PYTORCH_CPUINFO=${pytorch-cpuinfo}"

    # https://arnon.dk/matching-sm-architectures-arch-and-gencode-for-various-nvidia-cards/
    # Quadro M is 50, GTX 1050 is 60
    #"-DCMAKE_CUDA_ARCHITECTURES=60"

    # https://github.com/microsoft/onnxruntime/blob/main/onnxruntime/python/tools/transformers/models/stable_diffusion/README.md (things before Turing can't handle this stuff)
    "-Donnxruntime_USE_FLASH_ATTENTION=OFF"
    "-Donnxruntime_ENABLE_CPU_FP16_OPS=OFF"
    "-Donnxruntime_DISABLE_CONTRIB_OPS=ON"
    "-Donnxruntime_USE_ROCM=OFF"
  ];

  doCheck = false;

  postPatch = ''
    substituteInPlace cmake/libonnxruntime.pc.cmake.in \
      --replace '$'{prefix}/@CMAKE_INSTALL_ @CMAKE_INSTALL_
  '' + lib.optionalString (stdenv.hostPlatform.system == "aarch64-linux") ''
    # https://github.com/NixOS/nixpkgs/pull/226734#issuecomment-1663028691
    rm -v onnxruntime/test/optimizer/nhwc_transformer_test.cc
  '';

  # see onnxruntime's python tools/ci_build/build.py
  preBuild = lib.optionalString tensorrtSupport ''
    export ORT_TENSORRT_MAX_WORKSPACE_SIZE=1073741824
    export ORT_TENSORRT_MAX_PARTITION_ITERATIONS=1000
    export ORT_TENSORRT_MIN_SUBGRAPH_SIZE=1
    export ORT_TENSORRT_FP16_ENABLE=0
    export ORT_DISABLE_TRT_FLASH_ATTENTION=1
  '';
  
  postBuild = lib.optionalString pythonSupport ''
    python ../setup.py bdist_wheel
  '';

  preCheck = lib.optionalString tensorrtSupport ''
    export LD_LIBRARY_PATH=${addOpenGLRunpath.driverLink}/lib
    export ORT_DISABLE_TRT_FLASH_ATTENTION=1
  '';

  postInstall = ''
    # perform parts of `tools/ci_build/github/linux/copy_strip_binary.sh`
    install -m644 -Dt $out/include \
      ../include/onnxruntime/core/framework/provider_options.h \
      ../include/onnxruntime/core/providers/cpu/cpu_provider_factory.h \
      ../include/onnxruntime/core/session/onnxruntime_*.h
  '';

  passthru = {
    protobuf = protobuf3_21;
    tests = lib.optionalAttrs pythonSupport {
      python = python3Packages.onnxruntime;
    };
  };

  meta = with lib; {
    description = "Cross-platform, high performance scoring engine for ML models";
    longDescription = ''
      ONNX Runtime is a performance-focused complete scoring engine
      for Open Neural Network Exchange (ONNX) models, with an open
      extensible architecture to continually address the latest developments
      in AI and Deep Learning. ONNX Runtime stays up to date with the ONNX
      standard with complete implementation of all ONNX operators, and
      supports all ONNX releases (1.2+) with both future and backwards
      compatibility.
    '';
    homepage = "https://github.com/microsoft/onnxruntime";
    changelog = "https://github.com/microsoft/onnxruntime/releases/tag/v${version}";
    # https://github.com/microsoft/onnxruntime/blob/master/BUILD.md#architectures
    platforms = platforms.unix;
    license = licenses.mit;
    maintainers = with maintainers; [ jonringer puffnfresh ck3d cbourjau ];
  };
}
