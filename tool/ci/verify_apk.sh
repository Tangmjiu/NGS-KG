#!/usr/bin/env bash
# 校验产出的 APK：包名、SDK 版本、原生架构、签名，以及 release 不可调试。
# 用法: verify_apk.sh <apk 路径> [期望的 ABI]
# 注意：不可用 pipefail —— 提取字段时的 `grep | head` 会因 head 提前关闭管道
# 触发 SIGPIPE，在 pipefail 下会让赋值语句返回非 0 并直接终止脚本。
set -eu

apk="${1:?用法: verify_apk.sh <apk> [expected-abi]}"
expected_abi="${2:-}"

fail() { echo "::error::$*" >&2; exit 1; }

[ -f "$apk" ] || fail "APK 不存在: $apk"
[ -s "$apk" ] || fail "APK 是空文件: $apk"

# 1. 压缩包完整性
unzip -tqq "$apk" >/dev/null || fail "APK 压缩结构损坏"

# 2. 定位 build-tools
sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
[ -n "$sdk" ] || fail "未设置 ANDROID_HOME/ANDROID_SDK_ROOT"
build_tools="$(find "$sdk/build-tools" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort -V | tail -1)"
[ -n "$build_tools" ] || fail "未找到 Android build-tools"
aapt2="$build_tools/aapt2"
apksigner="$build_tools/apksigner"
[ -x "$aapt2" ] || fail "缺少 aapt2: $aapt2"
[ -x "$apksigner" ] || fail "缺少 apksigner: $apksigner"

echo "build-tools: $build_tools"
badging="$("$aapt2" dump badging "$apk")"

# 3. 包名与版本
extract() {
  # $1 = 正则，$2 = 文本；只输出匹配中的第一段数字/字符串
  grep -oE "$1" <<<"$2" | head -1 || true
}

package="$(extract "name='[^']+'" "$(grep '^package:' <<<"$badging")" | sed "s/name='//;s/'$//")"
[ "$package" = "com.mjiutang.ngskg.wear" ] || fail "包名不符，期望 com.mjiutang.ngskg.wear，实际 '${package}'"

version_code="$(extract "versionCode='[0-9]+'" "$badging" | grep -oE '[0-9]+' || true)"
version_name="$(extract "versionName='[^']*'" "$badging" | sed "s/versionName='//;s/'$//")"
min_sdk="$(extract "minSdkVersion:'[0-9]+'" "$badging" | grep -oE '[0-9]+' || true)"
target_sdk="$(extract "targetSdkVersion:'[0-9]+'" "$badging" | grep -oE '[0-9]+' || true)"

if [ -z "$min_sdk" ] || [ -z "$target_sdk" ] || [ -z "$version_code" ]; then
  echo "::group::aapt2 badging 原始输出（诊断用）"
  echo "$badging"
  echo "::endgroup::"
fi
[ -n "$version_code" ] || fail "读不到 versionCode"
[ "$min_sdk" = "26" ] || fail "minSdk 应为 26，实际 '${min_sdk}'"
[ "$target_sdk" = "36" ] || fail "targetSdk 应为 36，实际 '${target_sdk}'"

# 4. 原生架构
native_line="$(grep '^native-code:' <<<"$badging" | head -1 || true)"
[ -n "$native_line" ] || fail "APK 内没有原生库（native-code 为空）"
native_abis="$(tr -d "'" <<<"$native_line")"
for abi in arm64-v8a armeabi-v7a; do
  if [[ "$native_abis" == *"$abi"* ]]; then
    echo "原生架构: $abi"
  fi
done
if [ -n "$expected_abi" ] && [[ "$native_abis" != *"$expected_abi"* ]]; then
  fail "期望包含 ${expected_abi}，实际只有 ${native_abis}"
fi

# 5. release 不能带可调试标记
is_debug_apk=0
if grep -q '^application-debuggable' <<<"$badging"; then is_debug_apk=1; fi
case "$apk" in
  *-release.apk)
    [ "$is_debug_apk" = "0" ] || fail "release APK 仍标记为 debuggable"
    ;;
esac

# 6. 签名信息
certs="$("$apksigner" verify --print-certs "$apk" 2>&1)" || fail "APK 签名校验失败：${certs}"
signer="$(extract 'Signer #1 certificate DN: .*' "$certs" | sed 's/Signer #1 certificate DN: //')"
[ -n "$signer" ] || fail "APK 未签名或读不到签名者"
case "$apk" in
  *-release.apk)
    case "$signer" in
      *"Android Debug"*) fail "release APK 使用了 debug 签名：${signer}" ;;
    esac
    ;;
esac

# 7. 权限快照（供审阅）
permissions="$(grep '^uses-permission:' <<<"$badging" | sed -n "s/.*name='\([^']*\)'.*/\1/p" | sort | tr '\n' ' ')"

info_dir="$(dirname "$(dirname "$apk")")"
mkdir -p "$info_dir"
{
  echo "apk: $(basename "$apk")"
  echo "package: $package"
  echo "versionName: $version_name"
  echo "versionCode: $version_code"
  echo "minSdk: $min_sdk"
  echo "targetSdk: $target_sdk"
  echo "nativeAbis: $native_abis"
  echo "debuggable: $is_debug_apk"
  echo "signer: $signer"
  echo "permissions: $permissions"
} | tee "$info_dir/apk-info.txt"

echo "APK 校验通过: $(basename "$apk")"
