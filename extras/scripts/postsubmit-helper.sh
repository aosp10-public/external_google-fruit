#!/bin/bash -x

set -e

# This only exists in OS X, but it doesn't cause issues in Linux (the dir doesn't exist, so it's
# ignored).
export PATH="/usr/local/opt/coreutils/libexec/gnubin:$PATH"

case $COMPILER in
gcc-4.8)
    export CC=gcc-4.8
    export CXX=g++-4.8 
    ;;
    
gcc-4.9)
    export CC=gcc-4.9
    export CXX=g++-4.9
    ;;
    
gcc-5)
    export CC=gcc-5
    export CXX=g++-5
    ;;
    
gcc-6)
    export CC=gcc-6
    export CXX=g++-6
    ;;
    
clang-3.5)
    export CC=clang-3.5
    export CXX=clang++-3.5
    ;;

clang-3.6)
    export CC=clang-3.6
    export CXX=clang++-3.6
    ;;

clang-3.7)
    export CC=clang-3.7
    export CXX=clang++-3.7
    ;;

clang-3.8)
    export CC=clang-3.8
    export CXX=clang++-3.8
    ;;

clang-3.9)
    export CC=clang-3.9
    export CXX=clang++-3.9
    ;;

clang-4.0)
    case "$OS" in
    linux)
        export CC=clang-4.0
        export CXX=clang++-4.0
        ;;
    osx)
        export CC=/usr/local/opt/llvm/bin/clang-4.0
        export CXX=/usr/local/opt/llvm/bin/clang++
        ;;
    *) echo "Error: unexpected OS: $OS"; exit 1 ;;
    esac
    ;;

clang-default)
    export CC=clang
    export CXX=clang++
    ;;

bazel)
    ;;

*)
    echo "Unrecognized value of COMPILER: $COMPILER"
    exit 1
esac

run_make() {
  make -j$N_JOBS
}

if [[ "${COMPILER}" != "bazel" ]]
then
    echo CXX version: $($CXX --version)
    echo C++ Standard library location: $(echo '#include <vector>' | $CXX -x c++ -E - | grep 'vector\"' | awk '{print $3}' | sed 's@/vector@@;s@\"@@g' | head -n 1)
    echo Normalized C++ Standard library location: $(readlink -f $(echo '#include <vector>' | $CXX -x c++ -E - | grep 'vector\"' | awk '{print $3}' | sed 's@/vector@@;s@\"@@g' | head -n 1))

    case "$1" in
    DebugPlain)           CMAKE_ARGS=(-DCMAKE_BUILD_TYPE=Debug   -DCMAKE_CXX_FLAGS="$STLARG -O2") ;;
    DebugPlainNoPch)      CMAKE_ARGS=(-DCMAKE_BUILD_TYPE=Debug   -DCMAKE_CXX_FLAGS="$STLARG -O2" -DFRUIT_TESTS_USE_PRECOMPILED_HEADERS=OFF) ;;
    DebugAsan)            CMAKE_ARGS=(-DCMAKE_BUILD_TYPE=Debug   -DCMAKE_CXX_FLAGS="$STLARG -O0 -fsanitize=address") ;;
    DebugAsanNoPch)       CMAKE_ARGS=(-DCMAKE_BUILD_TYPE=Debug   -DCMAKE_CXX_FLAGS="$STLARG -O0 -fsanitize=address" -DFRUIT_TESTS_USE_PRECOMPILED_HEADERS=OFF) ;;
    DebugAsanUbsan)       CMAKE_ARGS=(-DCMAKE_BUILD_TYPE=Debug   -DCMAKE_CXX_FLAGS="$STLARG -O0 -fsanitize=address,undefined") ;;
    DebugAsanUbsanNoPch)  CMAKE_ARGS=(-DCMAKE_BUILD_TYPE=Debug   -DCMAKE_CXX_FLAGS="$STLARG -O0 -fsanitize=address,undefined" -DFRUIT_TESTS_USE_PRECOMPILED_HEADERS=OFF) ;;
    DebugValgrind)        CMAKE_ARGS=(-DCMAKE_BUILD_TYPE=Debug   -DCMAKE_CXX_FLAGS="$STLARG -O2"     -DRUN_TESTS_UNDER_VALGRIND=TRUE) ;;
    DebugValgrindNoPch)   CMAKE_ARGS=(-DCMAKE_BUILD_TYPE=Debug   -DCMAKE_CXX_FLAGS="$STLARG -O2"     -DRUN_TESTS_UNDER_VALGRIND=TRUE -DFRUIT_TESTS_USE_PRECOMPILED_HEADERS=OFF) ;;
    ReleasePlain)         CMAKE_ARGS=(-DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_FLAGS="$STLARG -Werror") ;;
    ReleasePlainNoPch)    CMAKE_ARGS=(-DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_FLAGS="$STLARG -Werror" -DFRUIT_TESTS_USE_PRECOMPILED_HEADERS=OFF) ;;
    ReleaseValgrind)      CMAKE_ARGS=(-DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_FLAGS="$STLARG -Werror" -DRUN_TESTS_UNDER_VALGRIND=TRUE) ;;
    ReleaseValgrindNoPch) CMAKE_ARGS=(-DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_FLAGS="$STLARG -Werror" -DRUN_TESTS_UNDER_VALGRIND=TRUE -DFRUIT_TESTS_USE_PRECOMPILED_HEADERS=OFF) ;;
    *) echo "Error: you need to specify one of the supported postsubmit modes (see postsubmit.sh)."; exit 1 ;;
    esac

    rm -rf build
    mkdir build
    cd build
    cmake .. "${CMAKE_ARGS[@]}"
    echo
    echo "Content of CMakeFiles/CMakeError.log:"
    if [ -f "CMakeFiles/CMakeError.log" ]
    then
      cat CMakeFiles/CMakeError.log
    fi
    echo
    run_make

    cd examples
    run_make
    cd ..

    cd tests
    run_make
    cd ..
    
    # This is intentionally not run from the tests/ directory, we want to ignore the pytest.ini there.
    case "$OS" in
    linux)
        py.test-3 -n auto -r a ;;
    osx)
        py.test -n auto -r a ;;
    *) echo "Error: unexpected OS: $OS"; exit 1 ;;
    esac

    make install
else
    # COMPILER=bazel
    
    BAZEL_FLAGS=("--force_python=PY3")
    case "$1" in
    DebugPlain)      ;;
    ReleasePlain)    BAZEL_FLAGS+=("-c" "opt") ;;
    *) echo "Error: you need to specify one of the supported postsubmit modes (see postsubmit.sh)."; exit 1 ;;
    esac

    cd extras/bazel_root/third_party/fruit
    bazel build "${BAZEL_FLAGS[@]}" :fruit examples/... tests/...
    bazel test "${BAZEL_FLAGS[@]}" --test_output=errors tests/...
fi
