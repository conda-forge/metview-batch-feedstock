#!/usr/bin/env bash

set -e
set -x

env | sort
ls -l /usr/bin
ls -l $BUILD_PREFIX/bin

if [[ "$c_compiler" == "gcc" ]]; then
  export PATH="${PATH}:${BUILD_PREFIX}/${HOST}/sysroot/usr/lib"
fi

export PYTHON=
export LDFLAGS="$LDFLAGS -L$PREFIX/lib -Wl,-rpath,$PREFIX/lib"
export CFLAGS="$CFLAGS -fPIC -I$PREFIX/include"


mkdir ../build && cd ../build

# do not run the 'inline' tests, as they are expected to fail
CTEST_OPTIONS="--exclude-regex inline"

if [[ $(uname) == Linux ]]; then
    # rpcgen searches for cpp in /lib/cpp and /cpp.
    # It's possible to pass a path to rpcgen using `-Y` but this is a directory path - rpcgen
    # expects a `cpp` binary inside that directory.
    # $CPP on conda-forge is a path to a binary of form `x86_64-conda_cos6-linux-gnu-cpp` which
    # causes rpcgen to fail to find it.
    # Therefore we create a symlink which rpcgen can use.
    ln -s "$CPP" ./cpp
    export CPP="$PWD/cpp"
    RPCGEN_USE_CPP_ENV=1
    RPCGEN_PATH_FLAGS="-DRPCGEN_PATH=/usr/bin;$BUILD_PREFIX/bin"
else
    RPCGEN_USE_CPP_ENV=0
fi


# for osx-arm64 to avoid using the arm64 version, which will not run on the build machine
# because it's cross-compiling
echo "${CONDA_BUILD_CROSS_COMPILATION:-}"
echo "${CROSSCOMPILING_EMULATOR}"
if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" && "${CROSSCOMPILING_EMULATOR}" == "" ]]; then
#export PATH=/usr/local/opt/curl/bin/$PATH
export FIND_PROG_FLAGS="-DCMAKE_PROGRAM_PATH=$BUILD_PREFIX/bin;/usr/bin"
export STATION_DB_FLAGS="-DENABLE_STATIONS_DB=OFF"
RPCGEN_PATH_FLAGS="-DRPCGEN_PATH=/usr/bin"
ln -s "$CPP_FOR_BUILD" ./cpp
export CPP="$PWD/cpp"
RPCGEN_USE_CPP_ENV=1
file /usr/bin/rpcgen
find / -name rpcgen
else
export FIND_PROG_FLAGS=""
export STATION_DB_FLAGS=""
fi

which curl
#file `which curl`



cmake ${CMAKE_ARGS} -D CMAKE_INSTALL_PREFIX=$PREFIX \
      -D CMAKE_BUILD_TYPE=Release \
      -D ENABLE_ECKIT_CMD=OFF \
      -D ENABLE_DOCS=0 \
      -D ENABLE_FORTRAN=OFF \
      -D ENABLE_METVIEW_FORTRAN=OFF \
      -D ENABLE_UI=OFF \
      -D RPCGEN_USE_CPP_ENV=$RPCGEN_USE_CPP_ENV \
      -D ECBUILD_LOG_LEVEL=DEBUG \
      -D ENABLE_SSL=OFF \
      -D ENABLE_MKL=OFF \
      -D ENABLE_LAPACK=OFF \
      -D ENABLE_ECKIT_CMD=OFF \
      -D ENABLE_BZIP2=OFF \
      -D ENABLE_MPI=OFF \
      -D INSTALL_LIB_DIR=lib \
      -D METVIEW_INSTALL_EXE_BIN_DIR=bin \
      $RPCGEN_PATH_FLAGS \
      $FIND_PROG_FLAGS \
      $STATION_DB_FLAGS \
      $SRC_DIR

make -j $CPU_COUNT VERBOSE=1

# temporary fix to ensure the data files required for the regrid.mv test are where they should be:
cp $SRC_DIR/metview/test/data/z_for_spectra.grib metview/test/macros/

cd metview
if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" != "1" || "${CROSSCOMPILING_EMULATOR}" != "" ]]; then
ctest --output-on-failure -j $CPU_COUNT ${CTEST_OPTIONS}
fi
cd ..
make install

ls -l $PREFIX
ls -l $PREFIX/bin
ls -l $PREFIX/lib
ls -l $PREFIX/lib/metview-bundle
ls -l $PREFIX/lib/metview-bundle/bin
