#!/bin/bash
#MSYS2用ffmpeg dllビルドスクリプト
#Visual Studioへの環境変数を通しておくこと
#pacman -S base-devel mingw-w64-i686-toolchain mingw-w64-x86_64-toolchain
#pacman -S p7zip git nasm python
#そのほかにcmake(windows版)のインストールが必要
NJOBS=$(($NUMBER_OF_PROCESSORS>16?16:$NUMBER_OF_PROCESSORS))
BUILD_DIR=$HOME/build_ffmpeg_dll
CMAKE_PATH="/C/Program Files/CMake/bin/cmake.exe"
PATCHES_DIR=$HOME/patches

mkdir -p $BUILD_DIR
mkdir -p $BUILD_DIR/src
cd $BUILD_DIR/src

BUILD_ALL="FALSE"
SSE4_2="FALSE"
UPDATE_FFMPEG="FALSE"
FOR_BITRATE="FALSE"
ENABLE_SWSCALE="FALSE"

# [ bitrate, swscale ]
TARGET_BUILD=""


while getopts "ast:u" OPT
do
  case $OPT in
    "a" ) BUILD_ALL="TRUE" ;;
    "s" ) SSE4_2="TRUE" ;;
    "t" ) TARGET_BUILD=$OPTARG ;;
    "u" ) UPDATE_FFMPEG="TRUE" ;;
  esac
done


if [ "$TARGET_BUILD" = "swscale" ]; then
    ENABLE_SWSCALE="TRUE"
elif [ "$TARGET_BUILD" = "bitrate" ]; then
    FOR_BITRATE="TRUE"
fi

# [ "x86", "x64" ]
if [ $MSYSTEM = "MINGW32" ]; then
    TARGET_ARCH="x86"
    VC_ARCH="win32"
    FFMPEG_ARCH="i686"
else
    TARGET_ARCH="x64"
    VC_ARCH="x64"
    FFMPEG_ARCH="x86_64"
fi

INSTALL_DIR=$BUILD_DIR/$TARGET_ARCH/build

if [ $TARGET_ARCH = "x64" ]; then
    BUILD_CCFLAGS="-O3 -mtune=sandybridge -msse2 -fexcess-precision=fast -mfpmath=sse -ffast-math -fomit-frame-pointer -ffunction-sections -fno-ident -I${INSTALL_DIR}/include"
    BUILD_CCFLAGS_SSE=$BUILD_CCFLAGS
    BUILD_LDFLAGS="-Wl,--gc-sections -Wl,--strip-all -static -static-libgcc -static-libstdc++ -L${INSTALL_DIR}/lib"
elif [ $TARGET_ARCH = "x86" ]; then
    BUILD_CCFLAGS="-m32 -mtune=sandybridge -msse2 -fexcess-precision=fast -mfpmath=sse -ffast-math -fomit-frame-pointer -ffunction-sections -fno-ident -mstackrealign -I${INSTALL_DIR}/include" 
    BUILD_CCFLAGS_SSE="-m32 -mtune=sandybridge -msse -fexcess-precision=fast -mfpmath=sse -ffast-math -fomit-frame-pointer -ffunction-sections -fno-ident -mstackrealign -I${INSTALL_DIR}/include"
    BUILD_LDFLAGS="-Wl,--gc-sections -Wl,--strip-all -static -static-libgcc -static-libstdc++ -L${INSTALL_DIR}/lib"
else
    echo "invalid TARGET_ARCH: ${TARGET_ARCH}"
    exit
fi

FFMPEG_DIR_NAME="ffmpeg_dll"
FFMPEG_SSE="-msse2"
if [ $SSE4_2 = "TRUE" ]; then
    FFMPEG_DIR_NAME="ffmpeg_dll_sse42"
    FFMPEG_SSE="-msse4.2 -mpopcnt"
fi
if [ $FOR_BITRATE = "TRUE" ]; then
    FFMPEG_DIR_NAME="ffmpeg_dll_small"
    BUILD_CCFLAGS="-Os ${BUILD_CCFLAGS}"
    BUILD_CCFLAGS_SSE="-Os ${BUILD_CCFLAGS_SSE}"
else
    BUILD_CCFLAGS="-O3 ${BUILD_CCFLAGS}"
    BUILD_CCFLAGS_SSE="-O3 ${BUILD_CCFLAGS_SSE}"
fi
if [ $ENABLE_SWSCALE = "TRUE" ]; then
    FFMPEG_DIR_NAME="ffmpeg_dll_swscale"
fi
if [ $BUILD_ALL != "FALSE" ]; then
    UPDATE_FFMPEG="TRUE"
fi

echo TARGET_ARCH=$TARGET_ARCH
echo BUILD_ALL=$BUILD_ALL
echo SSE4_2=$SSE4_2
echo UPDATE_FFMPEG=$UPDATE_FFMPEG
echo FOR_BITRATE=$FOR_BITRATE
echo ENABLE_SWSCALE=$ENABLE_SWSCALE

#--- ソースのダウンロード ---------------------------------------
if [ -d "ffmpeg" ]; then
    if [ $UPDATE_FFMPEG != "FALSE" ]; then
        cd ffmpeg
        make uninstall && make distclean &> /dev/null
        git pull
        cd ..
    fi
else
    UPDATE_FFMPEG=TRUE
    git clone git://source.ffmpeg.org/ffmpeg.git ffmpeg
fi

if [ ! -d "libpng-1.6.34" ]; then
    wget ftp://ftp-osl.osuosl.org/pub/libpng/src/libpng16/libpng-1.6.34.tar.xz
    tar xf libpng-1.6.34.tar.xz
fi

if [ ! -d "bzip2-1.0.6" ]; then
    wget http://www.bzip.org/1.0.6/bzip2-1.0.6.tar.gz
    tar xf bzip2-1.0.6.tar.gz
fi

if [ ! -d "expat-2.2.5" ]; then
    wget https://github.com/libexpat/libexpat/releases/download/R_2_2_5/expat-2.2.5.tar.bz2
    tar xf expat-2.2.5.tar.bz2
fi

if [ ! -d "freetype-2.7.1" ]; then
    wget https://download.savannah.gnu.org/releases/freetype/freetype-2.7.1.tar.gz
    tar xf freetype-2.7.1.tar.gz
fi

if [ ! -d "libiconv-1.14" ]; then
    wget http://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.14.tar.gz
    tar xf libiconv-1.14.tar.gz
fi

#2.12.6でないといろいろ面倒 -> 2.12.1もだめ, 2.13.0もだめ
if [ ! -d "fontconfig-2.12.6" ]; then
    wget https://www.freedesktop.org/software/fontconfig/release/fontconfig-2.12.6.tar.gz
    tar xf fontconfig-2.12.6.tar.gz
fi

if [ ! -d "fribidi-1.0.1" ]; then
    wget https://github.com/fribidi/fribidi/releases/download/v1.0.1/fribidi-1.0.1.tar.bz2
    tar xf fribidi-1.0.1.tar.bz2
fi

if [ ! -d "libass-0.14.0" ]; then
    wget https://github.com/libass/libass/releases/download/0.14.0/libass-0.14.0.tar.gz
    tar xf libass-0.14.0.tar.gz
fi

if [ ! -d "libogg-1.3.3" ]; then
    wget http://downloads.xiph.org/releases/ogg/libogg-1.3.3.tar.gz
    tar xf libogg-1.3.3.tar.gz
fi

if [ ! -d "libvorbis-1.3.5" ]; then
    wget http://downloads.xiph.org/releases/vorbis/libvorbis-1.3.5.tar.gz
    tar xf libvorbis-1.3.5.tar.gz
fi

if [ ! -d "opus-1.2.1" ]; then
    wget https://archive.mozilla.org/pub/opus/opus-1.2.1.tar.gz
    tar xf opus-1.2.1.tar.gz
fi

if [ ! -d "speex-1.2.0" ]; then
    wget http://downloads.xiph.org/releases/speex/speex-1.2.0.tar.gz
    tar xf speex-1.2.0.tar.gz
fi

if [ ! -d "lame-3.100" ]; then
    wget https://jaist.dl.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz
    tar xf lame-3.100.tar.gz
fi

if [ ! -d "twolame-0.3.13" ]; then
    wget http://downloads.sourceforge.net/twolame/twolame-0.3.13.tar.gz
    tar xf twolame-0.3.13.tar.gz
fi

if [ ! -d "libsndfile-1.0.28" ]; then
    wget http://www.mega-nerd.com/libsndfile/files/libsndfile-1.0.28.tar.gz
    tar xf libsndfile-1.0.28.tar.gz
fi

if [ ! -d "soxr-0.1.2-Source" ]; then
    wget http://nchc.dl.sourceforge.net/project/soxr/soxr-0.1.2-Source.tar.xz
    tar xf soxr-0.1.2-Source.tar.xz
fi

if [ ! -d "wavpack-5.1.0" ]; then
    wget http://www.wavpack.com/wavpack-5.1.0.tar.bz2
    tar xf wavpack-5.1.0.tar.bz2
fi

# if [ ! -d "gperf-3.0.4" ]; then
    # wget http://ftp.gnu.org/gnu/gperf/gperf-3.0.4.tar.gz
    # tar xf gperf-3.0.4.tar.gz
# fi

# if [ ! -d "gmp-6.1.0" ]; then
    # wget https://gmplib.org/download/gmp/gmp-6.1.0.tar.xz --no-check-certificate
    # tar xf gmp-6.1.0.tar.xz
# fi

# if [ ! -d "nettle-2.7.1" ]; then
    # wget ftp://ftp.gnu.org/gnu/nettle/nettle-2.7.1.tar.gz
    # tar xf nettle-2.7.1.tar.gz
# fi

# if [ ! -d "gnutls-3.3.19" ]; then
    # wget ftp://ftp.gnutls.org/gcrypt/gnutls/v3.4/gnutls-3.3.19.tar.xz
    # tar xf gnutls-3.3.19.tar.xz
# fi

# --- 出力先の古いデータを削除 ----------------------
if [ -d $FFMPEG_DIR_NAME ]; then
    rm -rf $FFMPEG_DIR_NAME
fi

if [ $UPDATE_FFMPEG != "FALSE" ] && [ -d ffmpeg_test ]; then
    rm -rf ffmpeg_test
fi

if [ $BUILD_ALL != "FALSE" ]; then
    rm -rf $BUILD_DIR/$TARGET_ARCH
fi

# --- 出力先を準備 --------------------------------------
if [ ! -d $BUILD_DIR/$TARGET_ARCH ]; then
    mkdir $BUILD_DIR/$TARGET_ARCH
fi
cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d ffmpeg_test ]; then
    cp -r ../src/ffmpeg ffmpeg_test
fi
cp -r ../src/ffmpeg $FFMPEG_DIR_NAME
  
  #$BUILD_DIR/src/soxr* $BUILD_DIR/src/nettle* $BUILD_DIR/src/gnutls*


# --- ビルド開始 対象のフォルダがなければビルドを行う -----------
# if [ ! -d "zlib" ]; then
    # cd $BUILD_DIR/$TARGET_ARCH
    # find ../src/ -type d -name "zlib-*" | xargs -i cp -r {} ./zlib
    # cd $BUILD_DIR/$TARGET_ARCH/zlib
    # CFLAGS="${BUILD_CCFLAGS}" \
    # CPPFLAGS="${BUILD_CCFLAGS}" \
    # CXXFLAGS="${BUILD_CCFLAGS}" \
    # make -f win32/Makefile.gcc
    # rm -f $INSTALL_DIR/lib/libz.a
    # rm -f $INSTALL_DIR/include/zlib.h $INSTALL_DIR/include/zconf.h
    # cp libz.a $INSTALL_DIR/lib/
    # cp zlib.h zconf.h $INSTALL_DIR/include/
# fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "bzip2" ]; then
    find ../src/ -type d -name "bzip2-*" | xargs -i cp -r {} ./bzip2
    cd ./bzip2
    patch -p1 < $PATCHES_DIR/bzip2-makefile.diff
    CFLAGS="${BUILD_CCFLAGS}" \
    CPPFLAGS="${BUILD_CCFLAGS}" \
    CXXFLAGS="${BUILD_CCFLAGS}" \
    make -j$NJOBS && make PREFIX=$INSTALL_DIR install
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "libpng" ]; then
    find ../src/ -type d -name "libpng-*" | xargs -i cp -r {} ./libpng
    cd ./libpng
    CFLAGS="${BUILD_CCFLAGS}" \
    CPPFLAGS="${BUILD_CCFLAGS}" \
    CXXFLAGS="${BUILD_CCFLAGS}" \
    ./configure \
    --prefix=$INSTALL_DIR \
    --enable-static \
    --disable-shared
    make -j$NJOBS && make install
fi

# cd $BUILD_DIR/$TARGET_ARCH
# if [ ! -d "gperf" ]; then
    # find ../src/ -type d -name "gperf-*" | xargs -i cp -r {} ./gperf
    #libiconvにgperf.exeが必要
    #3.0.4必須 (3.1だと、fontconfigでエラーが出る場合がある)
    # cd ./gperf
    # CFLAGS="${BUILD_CCFLAGS}" \
    # CPPFLAGS="${BUILD_CCFLAGS}" \
    # CXXFLAGS="${BUILD_CCFLAGS}" \
    # ./configure \
    # --prefix=$INSTALL_DIR \
    # --enable-static \
    # --disable-shared
    # make -j$NJOBS
    # texがないとのエラーが出るが無視する
    # make install
# fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "expat" ]; then
    find ../src/ -type d -name "expat-*" | xargs -i cp -r {} ./expat
    cd ./expat
    CFLAGS="${BUILD_CCFLAGS}" \
    CPPFLAGS="${BUILD_CCFLAGS}" \
    CXXFLAGS="${BUILD_CCFLAGS}" \
    ./configure \
    --prefix=$INSTALL_DIR \
    --enable-static \
    --disable-shared \
    --without-docbook
    make -j$NJOBS && make install
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "freetype" ]; then
    find ../src/ -type d -name "freetype-*" | xargs -i cp -r {} ./freetype
    #msys側のzlib(zlib.h, zconf.h, libz.a, libz.pcを消さないとうまくいかない)
    #あるいはconfigure後に、build/unix/unix-cc.mk内の
    #CFLAGSから-IC:/.../MSYS/includeとLDFLAGSの-LC:/.../MSYS/libを消す
    cd ./freetype
    BZIP2_CFLAGS=" -I${INSTALL_DIR}/include" \
    BZIP2_LIBS="-L${INSTALL_DIR}/lib -lbz2" \
    LIBPNG_CFLAGS=" -I${INSTALL_DIR}/include" \
    LIBPNG_LIBS="-L${INSTALL_DIR}/lib -lpng -lz" \
    CFLAGS="${BUILD_CCFLAGS}" \
    CPPFLAGS="${BUILD_CCFLAGS}" \
    CXXFLAGS="${BUILD_CCFLAGS}" \
    ./configure \
    --prefix=$INSTALL_DIR \
    --enable-static \
    --disable-shared \
    --with-png=yes \
    --with-zlib=no \
    --with-bzip2=yes
    make -j$NJOBS && make install
    sed -i -e "s/ -lfreetype$/ -lfreetype -liconv -lpng -lbz2 -lz/g" $INSTALL_DIR/lib/pkgconfig/freetype2.pc
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "libiconv" ]; then
    find ../src/ -type d -name "libiconv-*" | xargs -i cp -r {} ./libiconv
    cd ./libiconv
    gzip -dc $PATCHES_DIR/libiconv-1.14-ja-1.patch.gz | patch -p1
    PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
    CFLAGS="${BUILD_CCFLAGS} -fgnu89-inline" \
    CPPFLAGS="${BUILD_CCFLAGS} -fgnu89-inline" \
    ./configure \
    --prefix=$INSTALL_DIR \
    --enable-static \
    --disable-shared
    make -j$NJOBS && make install
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "fontconfig" ]; then
    find ../src/ -type d -name "fontconfig-*" | xargs -i cp -r {} ./fontconfig
    cd ./fontconfig
    #/c/ProgramAnother/python27/x86/Scripts/pip install lxml
    #autoreconf -fvi
    #pythonは2.7系を使用する
    #fontconfigはSSE2を有効にしない
    #SSE2を有効にすると、なぜかundefined reference to `_mm_mfence'が出る
    autoreconf -fvi
    FREETYPE_CFLAGS=-I$INSTALL_DIR/include/freetype2 \
    FREETYPE_LIBS="-L$INSTALL_DIR/lib -lfreetype" \
    CFLAGS="${BUILD_CCFLAGS_SSE}" \
    CPPFLAGS="${BUILD_CCFLAGS_SSE}" \
    CXXFLAGS="${BUILD_CCFLAGS_SSE}" \
    ./configure \
    --prefix=$INSTALL_DIR \
    --disable-shared \
    --enable-static \
    --enable-iconv --with-libiconv-includes=$INSTALL_DIR/include \
    --disable-docs \
    --disable-libxml2
    make -j$NJOBS && make install
    #pkgconfig情報を書き換える
    sed -i -e "s/ -lfontconfig$/ -lfontconfig -lexpat -lpng -lz/g" $INSTALL_DIR/lib/pkgconfig/fontconfig.pc
    sed -i -e "s/ -lfreetype$/ -lfreetype -liconv -lpng -lz/g" $INSTALL_DIR/lib/pkgconfig/fontconfig.pc
    sed -i -e "s/^Requires:[ \f\n\r\t]\+freetype2/Requires: freetype2 libpng/g" $INSTALL_DIR/lib/pkgconfig/fontconfig.pc
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "fribidi" ]; then
    find ../src/ -type d -name "fribidi-*" | xargs -i cp -r {} ./fribidi
    cd ./fribidi
    autoreconf -fvi
    PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
    CFLAGS="${BUILD_CCFLAGS}" \
    CPPFLAGS="${BUILD_CCFLAGS}" \
    ./configure \
    --prefix=$INSTALL_DIR \
    --enable-static \
    --enable-shared=no
    make -j$NJOBS && make install
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "libass" ]; then
    find ../src/ -type d -name "libass-*" | xargs -i cp -r {} ./libass
    if [ -d "libass_dll" ]; then
        rm -rf libass_dll
    fi
    cp -r ./libass ./libass_dll
    cd ./libass
    autoreconf -fvi
    PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
    CFLAGS="${BUILD_CCFLAGS} -I${INSTALL_DIR}/include" \
    CPPFLAGS="${BUILD_CCFLAGS} -L${INSTALL_DIR}/lib -liconv" \
    ./configure \
    --prefix=$INSTALL_DIR \
    --enable-static \
    --enable-shared=no
    make -j$NJOBS && make install

    cd $BUILD_DIR/$TARGET_ARCH/libass_dll
    autoreconf -fvi
    PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
    CC="gcc -static-libgcc -static-libstdc++" \
    CFLAGS="${BUILD_CCFLAGS}" \
    CPPFLAGS="${BUILD_CCFLAGS}" \
    LDFLAGS="-L${INSTALL_DIR}/lib -static-libgcc -static-libstdc++ -Wl,-Bstatic -Wl,-lm,-liconv,-lfreetype,-lfribidi,-lfontconfig,-lexpat,-lfreetype,-lpng,-lbz2,-lz" \
    ./configure \
    --prefix=$INSTALL_DIR \
    --enable-static=no \
    --enable-shared=yes
    #実行したコマンドを出力するように
    sed -i -e 's/AM_DEFAULT_VERBOSITY = 0/AM_DEFAULT_VERBOSITY = 1/g' libass/Makefile
    make -j$NJOBS
    cd libass
    # ../libtool --tag=CC   --mode=link gcc -std=gnu99 \
    # -D_GNU_SOURCE \
    # ${BUILD_CCFLAGS} \
    # -I${INSTALL_DIR}/include/freetype2 \
    # -I${INSTALL_DIR}/include/fribidi \
    # -I${INSTALL_DIR}/include \
    # -I${INSTALL_DIR}/include/freetype2 \
    # -no-undefined -version-info 8:0:3 -export-symbols ./libass.sym  -o libass.la -rpath ${INSTALL_DIR}/lib \
    # `find ./ -name "*.lo" | tr '\n' ' '` \
    # -L${INSTALL_DIR}/lib \
    # -static -static-libgcc -static-libstdc++ \
    # -Wl,-lm,-liconv,-lfreetype,-lfribidi,-lfontconfig,-lexpat,-lfreetype,-lpng,-lbz2,-lz \
    # -Wl,--output-def,libass.def -Wl,-s -Wl,-gc-sections
    # sed -i -e "s/ @[^ ]*//" libass.def

    LIBASS_DEF_FILENAME=`find ./.libs/libass-*.dll`.def
    LIBASS_DEF_FILENAME=${LIBASS_DEF_FILENAME/.dll.def/.def}
    cp -f `find ./.libs/libass-*.dll`.def ${LIBASS_DEF_FILENAME}
    cp -f ${LIBASS_DEF_FILENAME} .
    LIBASS_DEF_FILENAME=`basename $LIBASS_DEF_FILENAME`
    sed -i -e "s/ @[^ ]*//" ${LIBASS_DEF_FILENAME}
    LIBASS_LIB_FILENAME=$(basename $LIBASS_DEF_FILENAME .def).lib
    lib.exe -machine:$TARGET_ARCH -def:$LIBASS_DEF_FILENAME -out:$LIBASS_LIB_FILENAME
    cp `find ./.libs/libass-*.dll` .
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "opus" ]; then
    find ../src/ -type d -name "opus-*" | xargs -i cp -r {} ./opus
    cd ./opus
    autoreconf -fvi
    CFLAGS="${BUILD_CCFLAGS}" \
    CPPFLAGS="${BUILD_CCFLAGS}" \
    CXXFLAGS="${BUILD_CCFLAGS}" \
    ./configure \
    --prefix=$INSTALL_DIR \
    --enable-static=yes \
    --enable-shared=no \
    --enable-fixed-point \
    --disable-doc \
    --disable-extra-programs
    make -j$NJOBS && make install
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "libogg" ]; then
    find ../src/ -type d -name "libogg-*" | xargs -i cp -r {} ./libogg
    cd ./libogg
    autoreconf -fvi
    CFLAGS="${BUILD_CCFLAGS}" \
    CPPFLAGS="${BUILD_CCFLAGS}" \
    LDFLAGS="${BUILD_LDFLAGS}" \
    PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
    ./configure --prefix=$INSTALL_DIR \
        --disable-shared
    make -j$NJOBS && make install-strip
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "libvorbis" ]; then
    find ../src/ -type d -name "libvorbis-*" | xargs -i cp -r {} ./libvorbis
    cd ./libvorbis
    CFLAGS="${BUILD_CCFLAGS}" \
    CPPFLAGS="${BUILD_CCFLAGS}" \
    LDFLAGS="${BUILD_LDFLAGS}" \
    PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
    ./configure --prefix=$INSTALL_DIR \
        --disable-shared
    make -j$NJOBS && make install-strip
    sed -i -e "s/^Requires.private/Requires/g" $INSTALL_DIR/lib/pkgconfig/vorbis.pc
    sed -i -e "s/^Requires.private/Requires/g" $INSTALL_DIR/lib/pkgconfig/vorbisfile.pc
    sed -i -e "s/^Requires.private/Requires/g" $INSTALL_DIR/lib/pkgconfig/vorbisenc.pc
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "speex" ]; then
    find ../src/ -type d -name "speex-*" | xargs -i cp -r {} ./speex
    cd ./speex
    autoreconf -fvi
    CFLAGS="${BUILD_CCFLAGS}" \
    CPPFLAGS="${BUILD_CCFLAGS}" \
    LDFLAGS="${BUILD_LDFLAGS}" \
    PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
    ./configure --prefix=$INSTALL_DIR \
        --disable-shared
    make -j$NJOBS
    make install-strip
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "lame" ]; then
    find ../src/ -type d -name "lame-*" | xargs -i cp -r {} ./lame
    cd ./lame
    patch -p1 < $PATCHES_DIR/lame-3.100-parse_c.diff
    CFLAGS="${BUILD_CCFLAGS}" \
    CPPFLAGS="${BUILD_CCFLAGS}" \
    LDFLAGS="${BUILD_LDFLAGS}" \
     ./configure \
     --prefix=$INSTALL_DIR \
     --disable-shared \
     --enable-static \
     --disable-decoder
    make install -j$NJOBS
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "libsndfile" ]; then
    find ../src/ -type d -name "libsndfile-*" | xargs -i cp -r {} ./libsndfile
    cd ./libsndfile
    CFLAGS="${BUILD_CCFLAGS}" \
    CPPFLAGS="${BUILD_CCFLAGS}" \
    LDFLAGS="${BUILD_LDFLAGS}" \
     ./configure \
     --prefix=$INSTALL_DIR \
     --disable-shared \
     --enable-static
    make install -j$NJOBS
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "twolame" ]; then
    find ../src/ -type d -name "twolame-*" | xargs -i cp -r {} ./twolame
    cd ./twolame
    patch -p1 < $PATCHES_DIR/twolame-0.3.13-mingw.diff
    PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
    CFLAGS="${BUILD_CCFLAGS}" \
    CPPFLAGS="${BUILD_CCFLAGS}" \
    LDFLAGS="${BUILD_LDFLAGS}" \
     ./configure \
     --prefix=$INSTALL_DIR \
     --disable-shared \
     --enable-static
    make install -j$NJOBS
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "soxr" ]; then
    find ../src/ -type d -name "soxr-*" | xargs -i cp -r {} ./soxr
    cd ./soxr
    "${CMAKE_PATH}" -G "MSYS Makefiles" \
    -D BUILD_SHARED_LIBS:BOOL=FALSE \
    -D CMAKE_C_FLAGS_RELEASE:STRING="${BUILD_CCFLAGS}" \
    -D CMAKE_EXE_LINKER_FLAGS_RELEASE:STRING="${BUILD_LDFLAGS}" \
    -D WITH_OPENMP:BOOL=NO \
    -D BUILD_TESTS:BOOL=NO \
    -D CMAKE_INSTALL_PREFIX=$INSTALL_DIR \
    .
    make install -j$NJOBS
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "wavpack" ]; then
    find ../src/ -type d -name "wavpack-*" | xargs -i cp -r {} ./wavpack
    cd ./wavpack
    autoreconf -fvi
    CFLAGS="${BUILD_CCFLAGS}" \
    CPPFLAGS="${BUILD_CCFLAGS}" \
    LDFLAGS="${BUILD_LDFLAGS}" \
     ./configure \
     --prefix=$INSTALL_DIR \
     --disable-shared \
     --enable-static
    make install -j$NJOBS
fi

# cd $BUILD_DIR/$TARGET_ARCH
# if [ ! -d "gmp" ]; then
    # find ../src/ -type d -name "gmp-*" | xargs -i cp -r {} ./gmp
    # cd ./gmp
    # PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
    # CFLAGS="${BUILD_CCFLAGS}" \
    # CPPFLAGS="${BUILD_CCFLAGS}" \
    # LDFLAGS="${BUILD_LDFLAGS}" \
     # ./configure \
     # --prefix=$INSTALL_DIR \
     # --disable-shared \
     # --enable-static
     # make install -j$NJOBS
 # fi

# cd $BUILD_DIR/$TARGET_ARCH
# if [ ! -d "nettle" ]; then
    # find ../src/ -type d -name "nettle-*" | xargs -i cp -r {} ./nettle
    # cd ./nettle
    # PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
    # CFLAGS="${BUILD_CCFLAGS}" \
    # CPPFLAGS="${BUILD_CCFLAGS}" \
    # LDFLAGS="${BUILD_LDFLAGS}" \
     # ./configure \
     # --prefix=$INSTALL_DIR \
     # --disable-shared \
     # --enable-static --disable-openssl
    # make install -j$NJOBS
# fi

# cd $BUILD_DIR/$TARGET_ARCH/gnutls
# PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
# CFLAGS="${BUILD_CCFLAGS}" \
# CPPFLAGS="${BUILD_CCFLAGS}" \
# LDFLAGS="${BUILD_LDFLAGS}" \
# ./configure \
# --prefix=$INSTALL_DIR \
# --disable-shared --disable-cxx \
# --disable-openssl-compatibility \
# --disable-doc --disable-gtk-doc-html \
# --with-included-libtasn1 --without-p11-kit
# sed -i.orig -e "/Libs.private:/s/$/ -lcrypt32/" lib/gnutls.pc
# make install -j$NJOBS

if [ $FOR_BITRATE = "FALSE" ]; then
    cd $BUILD_DIR/$TARGET_ARCH/ffmpeg_test
    if [ ! -e ./ffmpeg.exe ]; then
        PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
        ./configure \
        --prefix==${INSTALL_DIR}/$FFMPEG_DIR_NAME \
        --arch="${TARGET_ARCH}" \
        --target-os="mingw32" \
        --disable-doc \
        --disable-avdevice \
        --disable-hwaccels \
        --disable-devices \
        --disable-debug \
        --disable-network \
        --disable-amd3dnow \
        --disable-amd3dnowext \
        --disable-xop \
        --disable-fma4 \
        --disable-bsfs \
        --disable-aesni \
        --extra-cflags="${BUILD_CCFLAGS} -I${INSTALL_DIR}/include ${FFMPEG_SSE}" \
        --extra-ldflags="${BUILD_LDFLAGS} -L${INSTALL_DIR}/lib"
        make -j$NJOBS
    fi

    ./ffmpeg.exe -encoders | grep '^ A.\{5\} ' | cut -d' ' -f3 > ffmpeg_audenc_list.txt
    ./ffmpeg.exe -encoders | grep '^ S.\{5\} ' | cut -d' ' -f3 >> ffmpeg_audenc_list.txt
    ./configure --list-encoders | tr '\t' '\n' | grep -v '^\s*$' | sort > ./configure_enc_list.txt
    CONFIGURE_AUDENC_LIST=`python $HOME/build_get_audlist.py ffmpeg_audenc_list.txt ./configure_enc_list.txt`

    ./ffmpeg.exe -filters | grep -v 'V->V' | cut -d' ' -f3 > ffmpeg_audfilter_list.txt
    ./configure --list-filters | tr '\t' '\n' | grep -v '^\s*$' | sort > ./configure_filter_list.txt
    CONFIGURE_AUDFILTER_LIST=`python $HOME/build_get_audlist.py ffmpeg_audfilter_list.txt ./configure_filter_list.txt`
fi

if [ $ENABLE_SWSCALE = "TRUE" ]; then
    SWSCALE_ARG="--enable-swscale"
else
    SWSCALE_ARG="--disable-swscale"
fi

cd $BUILD_DIR/$TARGET_ARCH/$FFMPEG_DIR_NAME
if [ $FOR_BITRATE = "TRUE" ]; then
PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
./configure \
--prefix=${BUILD_DIR}/$FFMPEG_DIR_NAME/$TARGET_ARCH \
--arch="${FFMPEG_ARCH}" \
--target-os="mingw32" \
--disable-programs \
--disable-doc \
$SWSCALE_ARG \
--disable-postproc \
--disable-avdevice \
--disable-hwaccels \
--disable-devices \
--disable-swresample \
--disable-avfilter \
--disable-network \
--disable-debug \
--disable-static \
--disable-amd3dnow \
--disable-amd3dnowext \
--disable-encoders \
--disable-muxers \
--disable-xop \
--disable-fma4 \
--disable-w32threads \
--disable-pthreads \
--disable-dxva2 \
--disable-d3d11va \
--enable-shared \
--disable-xlib \
--enable-small \
--extra-cflags="${BUILD_CCFLAGS} -I${INSTALL_DIR}/include ${FFMPEG_SSE}" \
--extra-ldflags="${BUILD_LDFLAGS} -L${INSTALL_DIR}/lib"
else
PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
./configure \
--prefix=${BUILD_DIR}/$FFMPEG_DIR_NAME/tmp/$TARGET_ARCH \
--arch="${FFMPEG_ARCH}" \
--target-os="mingw32" \
--disable-programs \
--disable-doc \
$SWSCALE_ARG \
--disable-postproc \
--disable-hwaccels \
--disable-outdevs \
--disable-debug \
--disable-static \
--disable-amd3dnow \
--disable-amd3dnowext \
--disable-xop \
--disable-fma4 \
--disable-aesni \
--disable-w32threads \
--disable-dxva2 \
--disable-d3d11va \
--enable-pthreads \
--enable-bsfs \
--enable-swresample \
--enable-shared \
--disable-encoders \
--enable-encoder=$CONFIGURE_AUDENC_LIST,libmp3lame,libopus,libtwolame,libvorbis,libwavpack,libspeex \
--disable-decoder=vorbis \
--disable-filters \
--enable-filter=$CONFIGURE_AUDFILTER_LIST \
--enable-libvorbis \
--enable-libspeex \
--enable-libmp3lame \
--enable-libtwolame \
--enable-fontconfig \
--enable-libfreetype \
--enable-libsoxr \
--enable-libwavpack \
--enable-libopus \
--extra-cflags="${BUILD_CCFLAGS} -I${INSTALL_DIR}/include ${FFMPEG_SSE}" \
--extra-ldflags="${BUILD_LDFLAGS} -L${INSTALL_DIR}/lib"
fi
make -j$NJOBS && make install

if [ $FOR_BITRATE != "TRUE" ]; then
    mkdir -p $BUILD_DIR/$FFMPEG_DIR_NAME/include
    mkdir -p $BUILD_DIR/$FFMPEG_DIR_NAME/lib/$VC_ARCH
    cp -f -r $BUILD_DIR/$FFMPEG_DIR_NAME/tmp/$TARGET_ARCH/include/* $BUILD_DIR/$FFMPEG_DIR_NAME/include
    cp -f -r $BUILD_DIR/$FFMPEG_DIR_NAME/tmp/$TARGET_ARCH/bin/*     $BUILD_DIR/$FFMPEG_DIR_NAME/lib/$VC_ARCH
    cp -f -r $BUILD_DIR/$FFMPEG_DIR_NAME/tmp/$TARGET_ARCH/lib/*     $BUILD_DIR/$FFMPEG_DIR_NAME/lib/$VC_ARCH
    rm -rf   $BUILD_DIR/$FFMPEG_DIR_NAME/tmp
    
    cp -f -r $BUILD_DIR/$TARGET_ARCH/libass_dll/libass/libass-*.dll $BUILD_DIR/$FFMPEG_DIR_NAME/lib/$VC_ARCH
    cp -f -r $BUILD_DIR/$TARGET_ARCH/libass_dll/libass/libass-*.def $BUILD_DIR/$FFMPEG_DIR_NAME/lib/$VC_ARCH
    cp -f -r $BUILD_DIR/$TARGET_ARCH/libass_dll/libass/libass-*.lib $BUILD_DIR/$FFMPEG_DIR_NAME/lib/$VC_ARCH
    cp -f -r $INSTALL_DIR/include/ass $BUILD_DIR/$FFMPEG_DIR_NAME/include
fi

cd $BUILD_DIR/src
if [ $UPDATE_FFMPEG != "FALSE" ]; then
    rm -f ffmpeg_lgpl_src.7z
    echo "compressing src file..."
    7z a -y -t7z -mx=9 -mmt=off -x\!'*.tar.gz' -x\!'*.tar.bz2' -x\!'*.tar.xz' -xr\!'.git' ffmpeg_lgpl_src.7z \
     $BUILD_DIR/src/ffmpeg* $BUILD_DIR/src/opus* $BUILD_DIR/src/libogg* $BUILD_DIR/src/libvorbis* \
     $BUILD_DIR/src/lame* $BUILD_DIR/src/libsndfile* $BUILD_DIR/src/twolame* $BUILD_DIR/src/soxr* $BUILD_DIR/src/speex* \
     $BUILD_DIR/src/expat* $BUILD_DIR/src/freetype* $BUILD_DIR/src/libiconv* $BUILD_DIR/src/fontconfig* \
     $BUILD_DIR/src/libpng* $BUILD_DIR/src/libass* $BUILD_DIR/src/bzip2* $BUILD_DIR/src/wavpack* \
      > /dev/null
fi

