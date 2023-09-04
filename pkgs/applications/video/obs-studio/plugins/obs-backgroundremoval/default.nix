{ lib, stdenv, fetchFromGitHub, cmake, obs-studio, opencv, curl, ninja ,
libsForQt5, qt6, callPackage, cudaPackages_11_8, autoPatchelfHook,
addOpenGLRunpath, onnxruntime }:

stdenv.mkDerivation rec {
  pname = "obs-backgroundremoval";
  version = "1.1.5";

  src = fetchFromGitHub {
    owner = "royshil";
    repo = "obs-backgroundremoval";
    rev = "v${version}";
    hash = "";
    fetchSubmodules = true;
  };

  nativeBuildInputs =
    [ cmake cudaPackages_11_8.autoAddOpenGLRunpathHook autoPatchelfHook
      ninja ];

  buildInputs =
    [ obs-studio onnxruntime opencv qt6.qtbase curl ];

  dontWrapQtApps = true;

  env.NIX_CFLAGS_COMPILE = ''
    -I${onnxruntime.dev}/include/onnxruntime/core/providers/tensorrt
    -L${onnxruntime}/lib
    -Wl,--no-undefined
  '';

  # pulled from scripts/PKGBUILD
  cmakeFlags = [
    "-DENABLE_QT=ON"
    "-DENABLE_FRONTEND_API=ON"
    "-DCMAKE_MODULE_PATH=${src}/cmake"
    "-DobsIncludePath=${obs-studio}/include/obs"
    "-DVERSION={$version}"
    "-DUSE_SYSTEM_ONNXRUNTIME=ON"
    "-DUSE_SYSTEM_OPENCV=ON"
    "-DUSE_SYSTEM_CURL=ON"
    "-DOnnxruntime_INCLUDE_DIR=${onnxruntime.dev}/include"
    "-DOnnxruntime_LIBRARIES=${onnxruntime}/lib/libonnxruntime.so"
  ];

  passthru.obsWrapperArguments = [
    "--prefix LD_LIBRARY_PATH : ${onnxruntime}/lib"
    "--prefix LD_LIBRARY_PATH : ${addOpenGLRunpath.driverLink}/lib"
    "--prefix LD_LIBRARY_PATH : ${onnxruntime}/lib"
  ];

  meta = with lib; {
    description =
      "OBS plugin to replace the background in portrait images and video";
    homepage = "https://github.com/royshil/obs-backgroundremoval";
    maintainers = with maintainers; [ zahrun ];
    license = licenses.mit;
    platforms = [ "x86_64-linux" "i686-linux" ];
  };
}
