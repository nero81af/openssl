#!/usr/bin/env bash
# Builds OpenSSL 3.5.9 (Apache-2.0, this checkout: branch rom_manager of nero81af/openssl) for arm64-v8a and
# x86_64 as ONE shared library,
# src/RomManager/Android/app/src/main/jniLibs/<abi>/libssl.so (static libssl + libcrypto, SONAME libssl.so).
# The .NET crypto shim linked into librommanagerkotlin.so dlopens "libssl.so" at runtime and looks up the
# libssl and libcrypto symbols in it (SMBLibrary needs them for NTLMv2 and SMB2/3 signing).
# Needs: perl (Git Bash has it), the Android NDK (NDK=... to override; its make is used).
set -euo pipefail

API=30
ABIS="arm64-v8a x86_64"

HERE="$(cd "$(dirname "$0")" && pwd)"
SDK="${ANDROID_SDK_ROOT:-$HOME/AppData/Local/Android/Sdk}"
NDK="${NDK:-$(ls -d "$SDK"/ndk/* | sort -V | tail -1)}"
SRC="$(dirname "$HERE")"
JNILIBS="$HERE/../../../src/RomManager/Android/app/src/main/jniLibs"

case "$(uname -s)" in
	MINGW*|MSYS*|CYGWIN*) HOST=windows-x86_64; EXE=.exe ;;
	Darwin)               HOST=darwin-x86_64;  EXE= ;;
	*)                    HOST=linux-x86_64;   EXE= ;;
esac
BIN="$NDK/toolchains/llvm/prebuilt/$HOST/bin"
MAKE="$NDK/prebuilt/$HOST/bin/make$EXE"
[ -x "$BIN/clang$EXE" ] || { echo "NDK clang not found in $BIN (set NDK=...)" >&2; exit 1; }
command -v make >/dev/null 2>&1 && MAKE=make

native_path() {
	if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else echo "$1"; fi
}

export ANDROID_NDK_ROOT="$NDK"
export PATH="$BIN:$PATH"
# perl/: the modules OpenSSL needs that the perl of Git for Windows does not ship
SHIMS="$(native_path "$HERE/perl")"

for ABI in $ABIS; do
	case "$ABI" in
		arm64-v8a) TARGET=android-arm64;  TRIPLE=aarch64-linux-android ;;
		x86_64)    TARGET=android-x86_64; TRIPLE=x86_64-linux-android ;;
	esac
	OUT="$HERE/build/$ABI"
	rm -rf "$OUT"
	mkdir -p "$OUT"

	# 1. static, position independent libssl + libcrypto (providers built in, no apps/tests/docs)
	(cd "$OUT" && PERL5LIB="$HERE/perl" perl -I"$SHIMS" "$(native_path "$SRC")/Configure" "$TARGET" -D__ANDROID_API__=$API -fPIC \
		no-shared no-module no-tests no-apps no-docs no-ui-console no-engine)
	"$MAKE" -C "$OUT" -j"$(nproc)" PERL="perl -I$SHIMS" build_libs

	# 2. one shared library out of both archives, 16 KB page aligned, stripped
	mkdir -p "$JNILIBS/$ABI"
	"$BIN/clang$EXE" --target="$TRIPLE$API" -shared -o "$OUT/libssl.so" -Wl,-soname,libssl.so \
		-Wl,--whole-archive "$OUT/libssl.a" "$OUT/libcrypto.a" -Wl,--no-whole-archive \
		-Wl,-z,max-page-size=16384 -Wl,--gc-sections -s
	cp "$OUT/libssl.so" "$JNILIBS/$ABI/libssl.so"

	needed=$("$BIN/llvm-readelf$EXE" -d "$OUT/libssl.so" | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p' | tr '\n' ' ')
	align=$("$BIN/llvm-readelf$EXE" -lW "$OUT/libssl.so" | awk '$1 == "LOAD" { print $NF }' | sort -u | xargs)
	echo "$ABI: $(wc -c < "$OUT/libssl.so") bytes, NEEDED: $needed, LOAD align: $align"
done
