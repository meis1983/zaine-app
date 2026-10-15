#!/bin/bash
# 在呢+ i18n build 前自检脚本（iOS）
# 用途：在 bash build_ipa.sh 之前跑，挡住所有已知 i18n 注入陷阱：
#   1. ''tr.zXXX'' 残留（inject 把 SQL/字符串误吃）
#   2. 跨行相邻字符串拼接丢 +（'str'\n    tr.xxx(）
#   3. const 上下文中用 tr.xxx
#   4. @Deprecated(tr.xxx) 非法
#   5. flutter gen-l10n 必须无 "Found syntax errors"
#   6. flutter analyze 必须 0 error / 0 warning
#   7. iOS kernel 严度扫（const 上下文/默认参数含 tr.）—— analyze 漏报
#   8. arb 双重转义 \n 残留（iOS 渲染成 [n] 乱码）—— A3 防复发
set -e
cd "$(dirname "$0")"
# 若在 zaine-app/ 父目录(脚本放在 zaine_app/), 进 zaine_app/
if [ -d "zaine_app" ] && [ ! -f "pubspec.yaml" ]; then
  cd zaine_app
fi
echo "============================================================"
echo "  [i18n pre-build self-check]"
echo "============================================================"

FAIL=0
report() { echo "  $1"; }

# 1. ''tr.z'' 残留
H1=$(grep -rn "''tr\.z[0-9]\+''" lib/ 2>/dev/null | grep -v 'lib/l10n/' || true)
if [ -n "$H1" ]; then
  report "❌ CHECK 1 失败: 残留 ''tr.zXXX'' (inject 误吃):"
  echo "$H1"
  FAIL=1
else
  report "✅ CHECK 1: 无 ''tr.z'' 残留"
fi

# 2. 跨行相邻字符串拼接丢 +
H2=$(python3 - <<'PY' 2>/dev/null || true
import re, glob
PAT=re.compile(r"(?:'(?:[^'\\]|\\.)*'|(?:tr\.|S\.of|S\.current)\.\w+(?:\([^)]*\))?)\s*,?\s*\n\s*(?:'(?:[^'\\]|\\.)*'|(?:tr\.|S\.of|S\.current)\.\w+(?:\([^)]*\))?)[,)\s]")
DEF_CTOR=re.compile(r"(AndroidNotificationDetails|NotificationDetails|IOSNotificationDetails|FlutterLocalNotificationsPlugin\s*\(|\.show\s*\()")
hits=[]
for path in glob.glob('lib/**/*.dart', recursive=True):
    if path.startswith('lib/l10n/'): continue
    try: t=open(path,encoding='utf-8').read()
    except: continue
    for m in PAT.finditer(t):
        # only flag if it looks like broken concat (not legit multi-arg constructor)
        before=t[max(0,m.start()-200):m.start()]
        if DEF_CTOR.search(before): continue
        # check: if first line ends with `,` AND next line starts with `tr.` or `'`, it's actually a multi-arg constructor call — skip
        ln = t.count('\n',0,m.start())+1
        line1 = t[t.rfind('\n',0,m.start())+1:m.end()]
        # heuristic: if first part is followed by `,` AND second part by `,`, and there's no `+` between — legit multi-arg
        # but if there's no `,` between parts, it's broken concat
        # collect: between parts (m.group(1) end to m.group(2) start) — search for `+`
        between = t[m.start()+len(m.group(1).split('\n')[0]) - t[:m.start()].count('\n')*0: m.start()]
        # simpler: just print — manual review
        hits.append(f'{path}:{ln}')
if hits:
    for h in hits: print(h)
PY
)
if [ -n "$H2" ]; then
  report "❌ CHECK 2 失败: 跨行相邻字符串/tr.xxx 拼接可能丢 +:"
  echo "$H2"
  FAIL=1
else
  report "✅ CHECK 2: 无跨行拼接异常（含 tr.xxx 续行变种）"
fi

# 3. @Deprecated(tr.
H3=$(grep -rn "@Deprecated(tr\." lib/ 2>/dev/null || true)
if [ -n "$H3" ]; then
  report "❌ CHECK 3 失败: @Deprecated(tr.xxx) 非法（编译期常量要求）:"
  echo "$H3"
  FAIL=1
else
  report "✅ CHECK 3: 无 @Deprecated(tr.) 非法用法"
fi

# 4. const 上下文中 tr（粗略：找 "const ...tr." 同行）
H4=$(grep -rn "^.*const .*tr\." lib/ 2>/dev/null | head -5 || true)
if [ -n "$H4" ]; then
  report "⚠️  CHECK 4 警告: const 上下文可能含 tr. (需人工确认):"
  echo "$H4"
else
  report "✅ CHECK 4: 无 const(tr.) 上下文"
fi

# 5. flutter gen-l10n
echo
echo "=== CHECK 5: flutter gen-l10n ==="
GEN_OUT=$(flutter gen-l10n 2>&1)
if echo "$GEN_OUT" | grep -q "Found syntax errors"; then
  report "❌ CHECK 5 失败: gen-l10n 语法错误:"
  echo "$GEN_OUT" | tail -10
  FAIL=1
else
  report "✅ CHECK 5: gen-l10n 通过"
fi

# 6. flutter analyze
echo
echo "=== CHECK 6: flutter analyze (跳过此步可用 --no-analyze) ==="
if [ "$1" = "--no-analyze" ]; then
  report "⏭  CHECK 6: 已跳过"
else
  ANA_OUT=$(flutter analyze 2>&1 || true)
  ERR_CNT=$(printf '%s' "$ANA_OUT" | grep -E "• (error|warning) •" | wc -l | tr -d ' ' || true)
  if [ "$ERR_CNT" = "0" ]; then
    report "✅ CHECK 6: analyze 0 error / 0 warning"
  else
    report "❌ CHECK 6 失败: $ERR_CNT errors/warnings"
    echo "$ANA_OUT" | grep -E "• (error|warning) •" | head -10
    FAIL=1
  fi
fi

# 7. iOS kernel 严度扫（flutter analyze 漏报，xcodebuild 才报错）——
#    (a) const List/Map/Set <X> = [...] 含 tr.        — 顶层 const 容器
#    (b) const ConstructorName(..., tr.xxx, ...)      — const 直接构造
#    (c) 默认参数值 = tr.xxx（在 ( 或 , 之后的 Type name = tr.）
#    (d) static const X name = X(..., tr.xxx, ...)    — 字段 const 字面量调用（含 wrap 类）
echo
echo "=== CHECK 7: iOS kernel 严度（const 上下文与默认参数）==="
H7=$(python3 - <<'PYEOF' 2>/dev/null || true
import re, glob
hits = []
for path in glob.glob('lib/**/*.dart', recursive=True):
    if path.startswith('lib/l10n/'): continue
    try: t = open(path, encoding='utf-8').read()
    except: continue
    # (a): 找到 static const List/Map/Set 的 = [ 或 = { ，match 到匹配的 ] 或 }，里面含 tr. 才报错
    for m in re.finditer(r'\bstatic\s+const\s+(?:List|Map|Set|Iterable)\s*<[^>]*>\s+\w+\s*=\s*[\[{]', t):
        s = m.start(); op = t[m.end()-1]
        cl = ']' if op == '[' else '}'
        depth = 1; j = m.end()
        while j < len(t) and depth > 0:
            if t[j] == op: depth += 1
            elif t[j] == cl: depth -= 1
            j += 1
        body = t[m.start():j]
        if re.search(r'\btr\.\w+', body):
            ln = t.count('\n', 0, s) + 1
            hits.append(f'{path}:{ln}  [const 容器含 tr.xxx]')
    # (b): const Constructor( ... tr.xxx ... )
    for m in re.finditer(r'\bconst\s+([A-Z]\w*(?:<[^>]+>)?)\s*\(', t):
        s = m.start(); name = m.group(1)
        depth = 1; j = m.end()
        while j < len(t) and depth > 0:
            if t[j] == '(': depth += 1
            elif t[j] == ')': depth -= 1
            j += 1
        body = t[s:j]
        if re.search(r'\btr\.\w+', body):
            ln = t.count('\n', 0, s) + 1
            hits.append(f'{path}:{ln}  [const {name} 构造含 tr.xxx]')
    # (c): 默认参数 value = tr.xxx（在 ( 或 , 之后）
    for m in re.finditer(r'(?:\(|,)\s*\n?\s*(?:required\s+)?(?:String|int|double|bool|num|Widget|BuildContext|[A-Z]\w*(?:<[^>]*>)?)\s+\??\s*(\w+)\s*=\s*tr\.(\w+)\s*,', t, re.M):
        s = m.start(); ln = t.count('\n', 0, s) + 1
        hits.append(f'{path}:{ln}  [默认参数 {m.group(1)} = tr.{m.group(2)}]')
    # (d): static const X name = X(... tr.xxx ...)  — 字段 const 字面量调用
    #      注意: 因为常量构造不能含 tr.xxx, const 类的字段形式也应视为 const 构造
    for m in re.finditer(r'\bstatic\s+const\s+([A-Z]\w*(?:<[^>]+>)?)\s+(\w+)\s*=\s*([A-Z]\w*(?:<[^>]+>)?)\s*\(', t):
        s = m.start(); ctor = m.group(3)
        depth = 1; j = m.end()
        while j < len(t) and depth > 0:
            if t[j] == '(': depth += 1
            elif t[j] == ')': depth -= 1
            j += 1
        body = t[s:j]
        if re.search(r'\btr\.\w+', body):
            ln = t.count('\n', 0, s) + 1
            hits.append(f'{path}:{ln}  [static const {m.group(1)} {m.group(2)} = {ctor}(...) 含 tr.xxx]')
for h in hits:
    print(h)
PYEOF
)
if [ -n "$H7" ]; then
  report "❌ CHECK 7 失败: iOS kernel 严度问题（analyze 漏报）:"
  echo "$H7"
  FAIL=1
else
  report "✅ CHECK 7: iOS kernel 严度无问题（const 容器/构造/默认参/字段字面量 4 类）"
fi

# 8. arb 双重转义 \n 残留（A3 修复的 [n] 乱码根因：arb 里写成了字面 \\n，
#    JSON 解析后变字面 \n，Text 渲染成 iOS 上的 [n] 乱码。扫描 5 份 arb 的任何残留）
echo
echo "=== CHECK 8: arb 双重转义 \\\\n 残留扫描（防 [n] 乱码复发）==="
H8=$(python3 - <<'PYEOF' 2>/dev/null || true
import re, glob
hits = []
for path in sorted(glob.glob('lib/l10n/*.arb')):
    try:
        t = open(path, encoding='utf-8').read()
    except Exception:
        continue
    # 双重转义: 文件里出现字面 \\n（两反斜杠 + n），须为 0
    for m in re.finditer(r'\\\\n', t):
        ln = t.count('\n', 0, m.start()) + 1
        seg = t[max(0, m.start() - 15):m.start() + 15].replace('\n', ' ')
        hits.append(f'{path}:{ln}  ...{seg}...')
if hits:
    for h in hits[:20]:
        print(h)
    if len(hits) > 20:
        print(f'... 共 {len(hits)} 处')
PYEOF
)
if [ -n "$H8" ]; then
  report "❌ CHECK 8 失败: 发现 arb 双重转义 \\\\n 残留（iOS 会渲染成 [n] 乱码）:"
  echo "$H8"
  FAIL=1
else
  report "✅ CHECK 8: 无 arb 双重转义 \\\\n 残留"
fi

echo "============================================================"
if [ "$FAIL" -eq 0 ]; then
  echo "  ✅ ALL PASSED — 可以安全执行: bash build_ipa.sh"
  exit 0
else
  echo "  ❌ 自检未通过 — 请先修复以上问题再出包"
  exit 1
fi
