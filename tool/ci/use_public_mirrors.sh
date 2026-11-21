#!/usr/bin/env bash
# 把仓库里的国内镜像配置换成 CI 可访问的官方源，并锁定 Gradle 分发包校验和。
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
wrapper="$root/android/gradle/wrapper/gradle-wrapper.properties"
dist_url='https\://services.gradle.org/distributions/gradle-8.13-all.zip'
dist_sha256='fba8464465835e74f7270bbf43d6d8a8d7709ab0a43ce1aa3323f73e9aa0c612'

[ -f "$wrapper" ] || { echo "::error::找不到 $wrapper"; exit 1; }

# 统一用官方分发地址，并写入 SHA-256，避免下载被篡改或版本漂移
python3 - "$wrapper" "$dist_url" "$dist_sha256" <<'PY'
import re, sys
path, url, sha = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, encoding='utf-8') as f:
    text = f.read()
text = re.sub(r'(?m)^distributionUrl=.*$', f'distributionUrl={url}', text)
text = re.sub(r'(?m)^distributionSha256Sum=.*\n?', '', text)
if not text.endswith('\n'):
    text += '\n'
text += f'distributionSha256Sum={sha}\n'
with open(path, 'w', encoding='utf-8') as f:
    f.write(text)
PY

# 去掉 CI 里访问不稳定的镜像仓库，保留 google() / mavenCentral()
for file in "$root/android/settings.gradle" "$root/android/build.gradle"; do
  [ -f "$file" ] || continue
  sed -i '/maven\.aliyun\.com/d' "$file"
done

echo "Gradle 分发包与 Maven 源已切换为官方地址"
