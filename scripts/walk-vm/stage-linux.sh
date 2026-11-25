#!/usr/bin/env bash
# Stage: ContextCore swift test on Linux, capped. Args: <tree> <out>
set -uo pipefail
tree=$1; out=$2
L=$HOME/tmp/agent/skill/walk-the-store/swiftlib
INC=$HOME/tmp/agent/skill/swift-deps/root/usr/include
export PATH=$HOME/.local/share/swiftly/toolchains/6.4.2/usr/bin:$PATH LD_LIBRARY_PATH=$L
cd "$tree/native/ContextCore"
nice -n 19 ionice -c 3 timeout -k 30 3000 swift test -j 2 --scratch-path "$out/linux" -Xlinker -L$L -Xcc -I$INC \
  --xunit-output "$out/linux.xml" >"$out/linux-test.log" 2>&1
echo $? >"$out/linux.rc"
