#!/usr/bin/env bash
#
# 本地 CI（Linux / macOS）：格式检查 -> 静态分析 -> 测试 -> 构建 Release APK/AAB。
# 与 .github/workflows/ci.yml 保持一致。
#
# 用法：
#   ./tool/ci.sh
#   ./tool/ci.sh --skip-build
#
set -euo pipefail

SKIP_BUILD=0
for arg in "$@"; do
  case "$arg" in
    --skip-build) SKIP_BUILD=1 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "未知参数：$arg" >&2; exit 2 ;;
  esac
done

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

FLUTTER="${FLUTTER:-flutter}"

# 找到 dart：优先从 flutter 路径推导，其次用 PATH 里的 dart。
DART="${DART:-}"
if [[ -z "$DART" ]]; then
  FLUTTER_REAL="$(command -v "$FLUTTER" || true)"
  if [[ -n "$FLUTTER_REAL" ]]; then
    CANDIDATE="$(dirname "$FLUTTER_REAL")/cache/dart-sdk/bin/dart"
    [[ -x "$CANDIDATE" ]] && DART="$CANDIDATE"
  fi
fi
DART="${DART:-dart}"

header() {
  echo
  echo "=============================================================="
  echo "  $1"
  echo "=============================================================="
}

run() {
  local name="$1"; shift
  header "$name"
  local started=$SECONDS
  if "$@"; then
    echo "[OK]   $name  ($((SECONDS - started))s)"
  else
    echo "[FAIL] $name  ($((SECONDS - started))s)" >&2
    exit 1
  fi
}

header "环境准备"
echo "工作目录 = $PROJECT_ROOT"
echo "Flutter  = $FLUTTER ($(command -v "$FLUTTER"))"
echo "Dart     = $DART"

run "拉取依赖 (flutter pub get)"        "$FLUTTER" pub get
run "检查代码格式 (dart format)"        "$DART" format --output=none --set-exit-if-changed lib test integration_test
run "静态分析 (flutter analyze)"        "$FLUTTER" analyze --fatal-infos
run "运行测试 (flutter test)"           "$FLUTTER" test --coverage --reporter compact

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  run "构建 Release APK"  "$FLUTTER" build apk --release
  run "构建 Release AAB"  "$FLUTTER" build appbundle --release
fi

header "结果"
echo "全部通过 ✅"
if [[ "$SKIP_BUILD" -eq 0 ]]; then
  ls -lh build/app/outputs/flutter-apk/*.apk build/app/outputs/bundle/release/*.aab 2>/dev/null || true
fi
