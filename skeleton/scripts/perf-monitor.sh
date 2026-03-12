#!/bin/bash
# 网站性能监控 — Lighthouse + PageSpeed Insights 双引擎
# 用法: bash scripts/perf-monitor.sh [url1,url2,...] [output_dir]
# 默认从 .env 读取 PERF_TARGET_URLS

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
[ -f "$PROJECT_DIR/.env" ] && { set -a; source "$PROJECT_DIR/.env"; set +a; }

URLS="${1:-${PERF_TARGET_URLS:-}}"
OUTPUT_DIR="${2:-$PROJECT_DIR/data/perf-reports}"
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
KNOWLEDGE_FILE="$PROJECT_DIR/memory/knowledge/performance-baselines.md"

if [ -z "$URLS" ]; then
  echo "错误: 未配置 PERF_TARGET_URLS，请在 .env 中设置"
  exit 1
fi

# ── 随机产品页发现 ──
# 用 Lighthouse 的 Chrome（能过 CF challenge）提取首页 <a> 中的 /products/ 链接
discover_product_page() {
  local base_url="$1"
  local base_domain="$2"
  local cache_file="$OUTPUT_DIR/.product-urls-${base_domain}.txt"

  # 缓存有效期 6 小时（仅非空文件）
  if [ -s "$cache_file" ] && [ -z "$(find "$cache_file" -mmin +360 2>/dev/null)" ]; then
    sort -R "$cache_file" | head -1
    return
  fi

  echo "[Discovery] 提取产品页链接（约 20 秒）..." >&2
  node "$SCRIPT_DIR/discover-product-urls.mjs" "$base_url" 2>/dev/null > "$cache_file" || true

  if [ -s "$cache_file" ]; then
    local count=$(wc -l < "$cache_file" | tr -d ' ')
    echo "[Discovery] 找到 ${count} 个产品页" >&2
    sort -R "$cache_file" | head -1
  fi
}

mkdir -p "$OUTPUT_DIR"

echo "=== 网站性能监控 $(date '+%Y-%m-%d %H:%M') ==="
echo "目标: $URLS"
echo ""

# CWV 阈值（毫秒）
LCP_GOOD=2500; LCP_POOR=4000
FCP_GOOD=1800; FCP_POOR=3000
CLS_GOOD=10;   CLS_POOR=25    # CLS * 100 (避免小数比较)
TTFB_GOOD=800; TTFB_POOR=1800
SCORE_GOOD=90; SCORE_WARN=50

# 评级函数
rate() {
  local val="$1" good="$2" poor="$3"
  if [ "$val" -le "$good" ] 2>/dev/null; then echo "good"
  elif [ "$val" -ge "$poor" ] 2>/dev/null; then echo "poor"
  else echo "needs-improvement"; fi
}

RESULTS_JSON="[]"
OVERALL_STATUS="ok"
CSV_LINES=""

IFS=',' read -ra URL_LIST <<< "$URLS"
_idx=0
while [ "$_idx" -lt "${#URL_LIST[@]}" ]; do
  url=$(echo "${URL_LIST[$_idx]}" | tr -d '[:space:]')
  _idx=$((_idx + 1))
  [ -z "$url" ] && continue

  echo "--- $url ---"

  # ── Lighthouse 本地审计 ──
  LH_SCORE="" LH_LCP="" LH_FCP="" LH_CLS="" LH_TTFB="" LH_TBT="" LH_SI=""
  LH_JSON="$OUTPUT_DIR/lh-${TIMESTAMP}-$(echo "$url" | sed -E 's|https?://||;s|/|_|g').json"

  echo "[Lighthouse] 运行中..."
  if lighthouse "$url" \
    --output=json --output-path="$LH_JSON" \
    --chrome-flags="--headless --no-sandbox --disable-gpu" \
    --only-categories=performance \
    --quiet 2>/dev/null; then

    LH_SCORE=$(jq -r '.categories.performance.score * 100 | floor' "$LH_JSON" 2>/dev/null || echo "")
    LH_LCP=$(jq -r '.audits["largest-contentful-paint"].numericValue | floor' "$LH_JSON" 2>/dev/null || echo "")
    LH_FCP=$(jq -r '.audits["first-contentful-paint"].numericValue | floor' "$LH_JSON" 2>/dev/null || echo "")
    LH_CLS_RAW=$(jq -r '.audits["cumulative-layout-shift"].numericValue' "$LH_JSON" 2>/dev/null || echo "0")
    LH_CLS=$(echo "$LH_CLS_RAW" | awk '{printf "%d", $1 * 100}')
    LH_TTFB=$(jq -r '.audits["server-response-time"].numericValue | floor' "$LH_JSON" 2>/dev/null || echo "")
    LH_TBT=$(jq -r '.audits["total-blocking-time"].numericValue | floor' "$LH_JSON" 2>/dev/null || echo "")
    LH_SI=$(jq -r '.audits["speed-index"].numericValue | floor' "$LH_JSON" 2>/dev/null || echo "")

    echo "  Score: ${LH_SCORE}  LCP: ${LH_LCP}ms  FCP: ${LH_FCP}ms  CLS: ${LH_CLS_RAW}  TTFB: ${LH_TTFB}ms  TBT: ${LH_TBT}ms"
  else
    echo "  [Lighthouse] 运行失败，跳过"
  fi

  # ── 提取 Lighthouse 深度数据 ──
  LCP_ELEMENT="{}"
  LCP_PHASES="[]"
  LCP_DISCOVERY="{}"
  THIRD_PARTIES="[]"
  RESOURCE_SUMMARY="[]"
  TOP_SCRIPTS="[]"

  if [ -f "$LH_JSON" ]; then
    # LCP 元素详情（选择器、HTML 片段、图片 URL）
    LCP_ELEMENT=$(jq '{
      selector: (.audits["lcp-breakdown-insight"].details.items[1].selector // empty),
      snippet: (.audits["lcp-breakdown-insight"].details.items[1].snippet // empty),
      nodeLabel: (.audits["lcp-breakdown-insight"].details.items[1].nodeLabel // empty)
    }' "$LH_JSON" 2>/dev/null || echo "{}")

    # LCP 阶段分解（TTFB / 资源加载延迟 / 资源加载时间 / 渲染延迟）
    LCP_PHASES=$(jq '[.audits["lcp-breakdown-insight"].details.items[0].items[] |
      {phase: .label, duration_ms: (.duration | floor)}]' "$LH_JSON" 2>/dev/null || echo "[]")

    # LCP 发现检查清单
    LCP_DISCOVERY=$(jq '.audits["lcp-discovery-insight"].details.items[0].items |
      {fetchpriority: .priorityHinted.value, discoverable: .requestDiscoverable.value, notLazy: .eagerlyLoaded.value}' "$LH_JSON" 2>/dev/null || echo "{}")

    # 第三方影响（厂商、传输大小、主线程时间）
    THIRD_PARTIES=$(jq '[.audits["third-parties-insight"].details.items[0:8] // [] | .[] |
      {name: .entity, size_kb: ((.transferSize // 0) / 1024 | floor), main_thread_ms: ((.mainThreadTime // 0) | floor)}]' "$LH_JSON" 2>/dev/null || echo "[]")

    # 资源汇总（按类型）
    RESOURCE_SUMMARY=$(jq '[.audits["resource-summary"].details.items[] |
      {type: .resourceType, count: .requestCount, size_kb: ((.transferSize // 0) / 1024 | floor)}]' "$LH_JSON" 2>/dev/null || echo "[]")

    # Top 5 CPU 重脚本
    TOP_SCRIPTS=$(jq '[.audits["bootup-time"].details.items[] | select(.total > 50) |
      {url: (.url | split("?")[0] | .[-80:]), scripting_ms: (.scripting | floor), total_ms: (.total | floor)}]
      | sort_by(-.total_ms) | .[0:5]' "$LH_JSON" 2>/dev/null || echo "[]")
  fi

  # ── PageSpeed Insights API（补充真实用户数据）──
  PSI_SCORE="" PSI_LCP="" PSI_FCP="" PSI_CLS=""
  echo "[PSI API] 查询中..."
  PSI_RAW=$(curl -sf "https://www.googleapis.com/pagespeedonline/v5/runPagespeed?url=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$url', safe=''))")&strategy=mobile&category=performance" 2>/dev/null || echo "")

  if [ -n "$PSI_RAW" ]; then
    PSI_SCORE=$(echo "$PSI_RAW" | jq -r '.lighthouseResult.categories.performance.score * 100 | floor' 2>/dev/null || echo "")
    # CrUX 真实用户数据
    PSI_LCP=$(echo "$PSI_RAW" | jq -r '.loadingExperience.metrics.LARGEST_CONTENTFUL_PAINT_MS.percentile' 2>/dev/null || echo "")
    PSI_FCP=$(echo "$PSI_RAW" | jq -r '.loadingExperience.metrics.FIRST_CONTENTFUL_PAINT_MS.percentile' 2>/dev/null || echo "")
    PSI_CLS_RAW=$(echo "$PSI_RAW" | jq -r '.loadingExperience.metrics.CUMULATIVE_LAYOUT_SHIFT_SCORE.percentile' 2>/dev/null || echo "")
    [ "$PSI_CLS_RAW" != "null" ] && [ -n "$PSI_CLS_RAW" ] && PSI_CLS="$PSI_CLS_RAW" || PSI_CLS=""

    [ -n "$PSI_SCORE" ] && [ "$PSI_SCORE" != "null" ] && echo "  PSI Score: ${PSI_SCORE}  CrUX LCP: ${PSI_LCP}ms  FCP: ${PSI_FCP}ms" || echo "  [PSI] 无 CrUX 数据"
  else
    echo "  [PSI API] 查询失败，跳过"
  fi

  # ── 综合评估（优先 Lighthouse，PSI 补充）──
  SCORE="${LH_SCORE:-${PSI_SCORE:-0}}"
  LCP="${LH_LCP:-${PSI_LCP:-0}}"
  FCP="${LH_FCP:-${PSI_FCP:-0}}"
  CLS_VAL="${LH_CLS:-0}"
  TTFB="${LH_TTFB:-0}"

  # 评级
  SCORE_RATE="good"
  [ "${SCORE:-0}" -lt "$SCORE_GOOD" ] && SCORE_RATE="needs-improvement"
  [ "${SCORE:-0}" -lt "$SCORE_WARN" ] && SCORE_RATE="poor"

  LCP_RATE=$(rate "${LCP:-0}" "$LCP_GOOD" "$LCP_POOR")
  FCP_RATE=$(rate "${FCP:-0}" "$FCP_GOOD" "$FCP_POOR")
  CLS_RATE=$(rate "${CLS_VAL:-0}" "$CLS_GOOD" "$CLS_POOR")
  TTFB_RATE=$(rate "${TTFB:-0}" "$TTFB_GOOD" "$TTFB_POOR")

  URL_STATUS="ok"
  if [ "$SCORE_RATE" = "poor" ] || [ "$LCP_RATE" = "poor" ]; then URL_STATUS="error"
  elif [ "$SCORE_RATE" = "needs-improvement" ] || [ "$LCP_RATE" = "needs-improvement" ]; then URL_STATUS="warn"; fi

  [ "$URL_STATUS" = "error" ] && OVERALL_STATUS="error"
  [ "$URL_STATUS" = "warn" ] && [ "$OVERALL_STATUS" = "ok" ] && OVERALL_STATUS="warn"

  echo "  综合: score=$SCORE($SCORE_RATE) LCP=$LCP($LCP_RATE) TTFB=$TTFB($TTFB_RATE) → $URL_STATUS"
  echo ""

  # 从 Lighthouse JSON 提取优化建议
  OPPORTUNITIES="[]"
  DIAGNOSTICS="[]"
  if [ -f "$LH_JSON" ]; then
    OPPORTUNITIES=$(jq '[.audits | to_entries[] | select(.value.details.type == "opportunity" and .value.details.overallSavingsMs > 0) | {title: .value.title, savings_ms: (.value.details.overallSavingsMs | floor)}] | sort_by(-.savings_ms) | .[0:5]' "$LH_JSON" 2>/dev/null || echo "[]")
    DIAGNOSTICS=$(jq '[.audits | to_entries[] | select(.value.details.type == "table" and (.value.score != null and .value.score < 0.5)) | {title: .value.title, displayValue: .value.displayValue}] | sort_by(.title) | .[0:5]' "$LH_JSON" 2>/dev/null || echo "[]")
  fi

  # 构建 JSON 结果（确保数值变量非空）
  : "${LH_TBT:=0}" "${LH_SI:=0}" "${LH_CLS_RAW:=0}"
  RESULT=$(jq -n \
    --arg url "$url" \
    --argjson score "${SCORE:-0}" \
    --argjson lcp "${LCP:-0}" \
    --argjson fcp "${FCP:-0}" \
    --arg cls "${LH_CLS_RAW}" \
    --argjson ttfb "${TTFB:-0}" \
    --argjson tbt "${LH_TBT}" \
    --argjson si "${LH_SI}" \
    --arg status "$URL_STATUS" \
    --arg scoreRate "$SCORE_RATE" \
    --arg lcpRate "$LCP_RATE" \
    --arg ttfbRate "$TTFB_RATE" \
    --arg psiScore "${PSI_SCORE:-}" \
    --arg psiLcp "${PSI_LCP:-}" \
    --argjson opportunities "$OPPORTUNITIES" \
    --argjson diagnostics "$DIAGNOSTICS" \
    --argjson lcpElement "$LCP_ELEMENT" \
    --argjson lcpPhases "$LCP_PHASES" \
    --argjson lcpDiscovery "$LCP_DISCOVERY" \
    --argjson thirdParties "$THIRD_PARTIES" \
    --argjson resourceSummary "$RESOURCE_SUMMARY" \
    --argjson topScripts "$TOP_SCRIPTS" \
    '{url:$url, score:$score, lcp:$lcp, fcp:$fcp, cls:($cls|tonumber), ttfb:$ttfb, tbt:$tbt, si:$si,
      status:$status, scoreRate:$scoreRate, lcpRate:$lcpRate, ttfbRate:$ttfbRate,
      psi:{score:$psiScore, lcp:$psiLcp},
      opportunities:$opportunities, diagnostics:$diagnostics,
      lcpElement:$lcpElement, lcpPhases:$lcpPhases, lcpDiscovery:$lcpDiscovery,
      thirdParties:$thirdParties, resourceSummary:$resourceSummary, topScripts:$topScripts}')
  RESULTS_JSON=$(echo "$RESULTS_JSON" | jq --argjson r "$RESULT" '. + [$r]')

  # CSV 行
  CSV_LINES="${CSV_LINES}${TIMESTAMP},${url},${SCORE},${LCP},${FCP},${LH_CLS_RAW:-0},${TTFB}\n"

  # 清理 Lighthouse JSON（保留最近 7 天）
  find "$OUTPUT_DIR" -name "lh-*.json" -mtime +7 -delete 2>/dev/null || true

  # ── 自动发现产品详情页（首页处理完后追加）──
  if echo "$url" | grep -qE '\.com/?$'; then
    base_domain=$(echo "$url" | sed -E 's|https?://||;s|/.*||')
    DETAIL_URL=$(discover_product_page "$url" "$base_domain")
    if [ -n "$DETAIL_URL" ]; then
      # 检查是否已在 URL_LIST 中
      already_in=false
      for existing in "${URL_LIST[@]}"; do
        [ "$existing" = "$DETAIL_URL" ] && already_in=true
      done
      if [ "$already_in" = "false" ]; then
        echo "[Discovery] 追加详情页: $DETAIL_URL"
        URL_LIST+=("$DETAIL_URL")
      fi
    fi
  fi
done

# ── 输出汇总报告 ──
echo "=== 性能监控汇总 ==="
echo "$RESULTS_JSON" | jq -r '.[] | "\(.url): score=\(.score) LCP=\(.lcp)ms TTFB=\(.ttfb)ms → \(.status)"'
echo "整体状态: $OVERALL_STATUS"
echo "=== 监控结束 ==="

# 保存 JSON 报告
REPORT_FILE="$OUTPUT_DIR/perf-${TIMESTAMP}.json"
jq -n --arg ts "$TIMESTAMP" --arg status "$OVERALL_STATUS" --argjson results "$RESULTS_JSON" \
  '{timestamp:$ts, status:$status, results:$results}' > "$REPORT_FILE"

# 追加 CSV 历史
CSV_FILE="$OUTPUT_DIR/perf-history.csv"
if [ ! -f "$CSV_FILE" ]; then
  echo "timestamp,url,score,lcp_ms,fcp_ms,cls,ttfb_ms" > "$CSV_FILE"
fi
printf "$CSV_LINES" >> "$CSV_FILE"

echo "$REPORT_FILE"
