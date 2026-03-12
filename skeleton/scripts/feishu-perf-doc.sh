#!/usr/bin/env bash
# 创建飞书性能报告文档（优先写入 Wiki 知识库）
# 用法: bash scripts/feishu-perf-doc.sh <report.json> <token>
# 输出: 文档 URL (stdout)

set -euo pipefail

REPORT_FILE="$1"
TOKEN="$2"
FEISHU_DOMAIN="${FEISHU_DOMAIN:-hengjunhome.feishu.cn}"

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_FILE="$PROJECT_DIR/data/cf-reports/daemon.log"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] perf-doc: $*" >> "$LOG_FILE" 2>/dev/null || true; }

# ── 读取报告数据 ──
count=$(jq -r '.results | length' "$REPORT_FILE")
[ "$count" -eq 0 ] && { echo ""; exit 0; }

first_url=$(jq -r '.results[0].url' "$REPORT_FILE" | sed 's|https://||;s|/.*||')
dt=$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M')
DOC_TITLE="📊 ${first_url} | $(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M')"

# ── 1. 创建文档（Wiki 优先，fallback 到普通文档）──
WIKI_SPACE="${FEISHU_PERF_WIKI_SPACE_ID:-}"
USER_TOKEN=""
DOC_ID=""
NODE_TOKEN=""

# 获取 user_access_token（Wiki 需要）
if [ -n "$WIKI_SPACE" ] && [ -f "$PROJECT_DIR/plugins/feishu-auth/get-token.sh" ]; then
  USER_TOKEN=$(bash "$PROJECT_DIR/plugins/feishu-auth/get-token.sh" 2>/dev/null) || true
fi

if [ -n "$WIKI_SPACE" ] && [ -n "$USER_TOKEN" ]; then
  # Wiki 知识库模式
  WIKI_RESP=$(curl -sf -X POST "https://open.feishu.cn/open-apis/wiki/v2/spaces/${WIKI_SPACE}/nodes" \
    -H "Authorization: Bearer $USER_TOKEN" \
    -H "Content-Type: application/json; charset=utf-8" \
    -d "$(jq -n --arg t "$DOC_TITLE" '{"obj_type":"docx","node_type":"origin","title":$t}')" 2>/dev/null) || true
  DOC_ID=$(echo "$WIKI_RESP" | jq -r '.data.node.obj_token // empty' 2>/dev/null)
  NODE_TOKEN=$(echo "$WIKI_RESP" | jq -r '.data.node.node_token // empty' 2>/dev/null)
fi

# Fallback: 普通文档
if [ -z "$DOC_ID" ]; then
  DOC_RESP=$(curl -sf -X POST "https://open.feishu.cn/open-apis/docx/v1/documents" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg t "$DOC_TITLE" '{title:$t}')")
  DOC_ID=$(echo "$DOC_RESP" | jq -r '.data.document.document_id // empty')
fi

if [ -z "$DOC_ID" ]; then
  log "创建文档失败"
  echo ""
  exit 0
fi
log "文档已创建: $DOC_ID (wiki=${WIKI_SPACE:+yes})"

# 写入文档用的 token（Wiki 用 user_token）
WRITE_TOKEN="${USER_TOKEN:-$TOKEN}"

# ── 辅助函数 ──
api_children() {
  curl -sf -X POST \
    "https://open.feishu.cn/open-apis/docx/v1/documents/$DOC_ID/blocks/$DOC_ID/children" \
    -H "Authorization: Bearer $WRITE_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$1" > /dev/null 2>&1
}

api_descendant() {
  curl -sf -X POST \
    "https://open.feishu.cn/open-apis/docx/v1/documents/$DOC_ID/blocks/$DOC_ID/descendant?document_revision_id=-1" \
    -H "Authorization: Bearer $WRITE_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$1" > /dev/null 2>&1
}

rate_emoji() {
  local val="$1" good="$2" poor="$3" direction="${4:-lower}"
  if [ "$direction" = "lower" ]; then
    [ "$val" -le "$good" ] 2>/dev/null && echo "🟢 好" && return
    [ "$val" -ge "$poor" ] 2>/dev/null && echo "🔴 差" && return
    echo "🟡 需改进"
  else
    [ "$val" -ge "$good" ] 2>/dev/null && echo "🟢 好" && return
    [ "$val" -le "$poor" ] 2>/dev/null && echo "🔴 差" && return
    echo "🟡 需改进"
  fi
}

# ── 2. 遍历每个 URL 写内容 ──
i=0
while [ "$i" -lt "$count" ]; do
  url=$(jq -r ".results[$i].url" "$REPORT_FILE")
  score=$(jq -r ".results[$i].score" "$REPORT_FILE")
  lcp=$(jq -r ".results[$i].lcp" "$REPORT_FILE")
  fcp=$(jq -r ".results[$i].fcp" "$REPORT_FILE")
  cls=$(jq -r ".results[$i].cls" "$REPORT_FILE")
  ttfb=$(jq -r ".results[$i].ttfb" "$REPORT_FILE")
  tbt=$(jq -r ".results[$i].tbt // 0" "$REPORT_FILE")

  # 评级
  score_rate=$(rate_emoji "$score" 90 50 higher)
  lcp_rate=$(rate_emoji "$lcp" 2500 4000 lower)
  fcp_rate=$(rate_emoji "$fcp" 1800 3000 lower)
  ttfb_rate=$(rate_emoji "$ttfb" 800 1800 lower)
  tbt_rate=$(rate_emoji "$tbt" 200 600 lower)
  cls_int=$(echo "$cls" | awk '{printf "%d", $1 * 1000}')
  cls_rate=$(rate_emoji "$cls_int" 100 250 lower)
  cls_display=$(echo "$cls" | awk '{printf "%.2f", $1}')

  short_url=$(echo "$url" | sed 's|https://||')

  # ── URL 标题 ──
  api_children "$(jq -n --arg u "$short_url" '{children:[{block_type:3,heading1:{elements:[{text_run:{content:$u}}]}}],index:-1}')"

  # ── 指标总览表格 (7行 x 4列) ──
  ROWS=7
  COLS=4
  TOTAL_CELLS=$((ROWS * COLS))

  declare -a TBL_DATA=(
    "指标" "数值" "评级" "Google 标准"
    "Performance Score" "$score" "$score_rate" "≥ 90"
    "LCP (最大内容绘制)" "${lcp}ms" "$lcp_rate" "≤ 2500ms"
    "FCP (首次内容绘制)" "${fcp}ms" "$fcp_rate" "≤ 1800ms"
    "TTFB (首字节时间)" "${ttfb}ms" "$ttfb_rate" "≤ 800ms"
    "CLS (累积布局偏移)" "$cls_display" "$cls_rate" "≤ 0.1"
    "TBT (总阻塞时间)" "${tbt}ms" "$tbt_rate" "≤ 200ms"
  )

  cell_ids=""
  descendants="[]"
  cell_idx=0
  for r in $(seq 0 $((ROWS-1))); do
    for c in $(seq 0 $((COLS-1))); do
      cid="c${i}_${r}_${c}"
      tid="t${i}_${r}_${c}"
      data_idx=$((r * COLS + c))
      content="${TBL_DATA[$data_idx]}"

      bold="false"
      [ "$r" -eq 0 ] && bold="true"

      cell_ids="${cell_ids}\"${cid}\","
      descendants=$(echo "$descendants" | jq \
        --arg cid "$cid" --arg tid "$tid" --arg content "$content" --argjson bold "$bold" \
        '. + [
          {block_id:$cid, block_type:32, table_cell:{}, children:[$tid]},
          {block_id:$tid, block_type:2, text:{elements:[{text_run:{content:$content, text_element_style:{bold:$bold}}}]}, children:[]}
        ]')
      cell_idx=$((cell_idx + 1))
    done
  done
  cell_ids="${cell_ids%,}"

  TBL_ID="tbl_${i}"
  FULL_DESC=$(echo "$descendants" | jq \
    --arg tbl_id "$TBL_ID" \
    --argjson rows "$ROWS" --argjson cols "$COLS" \
    --arg cells "$cell_ids" \
    '[{block_id:$tbl_id, block_type:31, table:{property:{row_size:$rows,column_size:$cols}}, children:($cells | split(",") | map(gsub("\"";"")))
    }] + .')

  DESC_BODY=$(jq -n --arg tbl_id "$TBL_ID" --argjson desc "$FULL_DESC" \
    '{index:-1, children_id:[$tbl_id], descendants:$desc}')

  api_descendant "$DESC_BODY" || log "表格写入失败"

  # ── LCP 元素分析 ──
  lcp_selector=$(jq -r ".results[$i].lcpElement.selector // empty" "$REPORT_FILE")
  lcp_snippet=$(jq -r ".results[$i].lcpElement.snippet // empty" "$REPORT_FILE")
  if [ -n "$lcp_selector" ]; then
    api_children '{"children":[{"block_type":4,"heading2":{"elements":[{"text_run":{"content":"🎯 LCP 元素分析"}}]}}],"index":-1}'

    # 提取图片 URL（如果 LCP 是图片）
    lcp_img=$(echo "$lcp_snippet" | sed -n 's/.*src="\([^"]*\)".*/\1/p' | head -1 || true)
    lcp_text="选择器: ${lcp_selector}"
    [ -n "$lcp_img" ] && lcp_text="${lcp_text}\n图片: ${lcp_img}"

    api_children "$(jq -n --arg t "$lcp_text" \
      '{children:[{block_type:14,code:{elements:[{text_run:{content:$t}}],language:1}}],index:-1}')"

    # LCP 阶段分解
    phase_count=$(jq -r ".results[$i].lcpPhases | length" "$REPORT_FILE" 2>/dev/null || echo "0")
    if [ "$phase_count" -gt 0 ]; then
      phase_text=""
      j=0
      while [ "$j" -lt "$phase_count" ]; do
        p_name=$(jq -r ".results[$i].lcpPhases[$j].phase" "$REPORT_FILE")
        p_dur=$(jq -r ".results[$i].lcpPhases[$j].duration_ms" "$REPORT_FILE")
        # 标记瓶颈阶段（占 LCP 40%+ 的）
        pct=0
        [ "$lcp" -gt 0 ] && pct=$((p_dur * 100 / lcp))
        marker=""
        [ "$pct" -gt 40 ] && marker=" ⚠️ 瓶颈"
        phase_text="${phase_text}• ${p_name}: ${p_dur}ms (${pct}%)${marker}\n"
        j=$((j + 1))
      done
      api_children "$(jq -n --arg t "$(echo -e "$phase_text")" \
        '{children:[{block_type:2,text:{elements:[{text_run:{content:$t}}]}}],index:-1}')"
    fi

    # LCP 发现检查
    lcp_fp=$(jq -r ".results[$i].lcpDiscovery.fetchpriority // empty" "$REPORT_FILE")
    lcp_disc=$(jq -r ".results[$i].lcpDiscovery.discoverable // empty" "$REPORT_FILE")
    lcp_eager=$(jq -r ".results[$i].lcpDiscovery.notLazy // empty" "$REPORT_FILE")
    if [ -n "$lcp_fp" ]; then
      check_text=""
      [ "$lcp_fp" = "true" ] && check_text="${check_text}✅ fetchpriority=high 已设置\n" || check_text="${check_text}❌ 缺少 fetchpriority=high\n"
      [ "$lcp_disc" = "true" ] && check_text="${check_text}✅ 资源可在初始文档中发现\n" || check_text="${check_text}❌ 资源未在初始文档中发现\n"
      [ "$lcp_eager" = "true" ] && check_text="${check_text}✅ 未设置 lazy load\n" || check_text="${check_text}❌ 不应对 LCP 元素 lazy load\n"
      api_children "$(jq -n --arg t "$(echo -e "$check_text")" \
        '{children:[{block_type:2,text:{elements:[{text_run:{content:$t}}]}}],index:-1}')"
    fi
  fi

  # ── 第三方脚本影响 ──
  tp_count=$(jq -r ".results[$i].thirdParties | length" "$REPORT_FILE" 2>/dev/null || echo "0")
  if [ "$tp_count" -gt 0 ]; then
    api_children '{"children":[{"block_type":4,"heading2":{"elements":[{"text_run":{"content":"📦 第三方脚本影响"}}]}}],"index":-1}'

    tp_text=""
    j=0
    while [ "$j" -lt "$tp_count" ]; do
      tp_name=$(jq -r ".results[$i].thirdParties[$j].name" "$REPORT_FILE")
      tp_size=$(jq -r ".results[$i].thirdParties[$j].size_kb" "$REPORT_FILE")
      tp_time=$(jq -r ".results[$i].thirdParties[$j].main_thread_ms" "$REPORT_FILE")
      tp_text="${tp_text}• ${tp_name}: ${tp_size}KB, 主线程 ${tp_time}ms\n"
      j=$((j + 1))
    done
    api_children "$(jq -n --arg t "$(echo -e "$tp_text")" \
      '{children:[{block_type:2,text:{elements:[{text_run:{content:$t}}]}}],index:-1}')"
  fi

  # ── 资源加载汇总 ──
  rs_count=$(jq -r ".results[$i].resourceSummary | length" "$REPORT_FILE" 2>/dev/null || echo "0")
  if [ "$rs_count" -gt 0 ]; then
    api_children '{"children":[{"block_type":4,"heading2":{"elements":[{"text_run":{"content":"📊 资源加载汇总"}}]}}],"index":-1}'

    rs_text=""
    j=0
    while [ "$j" -lt "$rs_count" ]; do
      rs_type=$(jq -r ".results[$i].resourceSummary[$j].type" "$REPORT_FILE")
      rs_cnt=$(jq -r ".results[$i].resourceSummary[$j].count" "$REPORT_FILE")
      rs_size=$(jq -r ".results[$i].resourceSummary[$j].size_kb" "$REPORT_FILE")
      [ "$rs_type" = "total" ] && rs_text="总计: ${rs_cnt} 请求, ${rs_size}KB\n${rs_text}" && j=$((j + 1)) && continue
      [ "$rs_cnt" -eq 0 ] && j=$((j + 1)) && continue
      rs_text="${rs_text}• ${rs_type}: ${rs_cnt} 请求, ${rs_size}KB\n"
      j=$((j + 1))
    done
    api_children "$(jq -n --arg t "$(echo -e "$rs_text")" \
      '{children:[{block_type:2,text:{elements:[{text_run:{content:$t}}]}}],index:-1}')"
  fi

  # ── Top CPU 重脚本 ──
  ts_count=$(jq -r ".results[$i].topScripts | length" "$REPORT_FILE" 2>/dev/null || echo "0")
  if [ "$ts_count" -gt 0 ]; then
    api_children '{"children":[{"block_type":4,"heading2":{"elements":[{"text_run":{"content":"🔥 CPU 密集脚本 Top 5"}}]}}],"index":-1}'

    ts_text=""
    j=0
    while [ "$j" -lt "$ts_count" ]; do
      ts_url=$(jq -r ".results[$i].topScripts[$j].url" "$REPORT_FILE")
      ts_script=$(jq -r ".results[$i].topScripts[$j].scripting_ms" "$REPORT_FILE")
      ts_total=$(jq -r ".results[$i].topScripts[$j].total_ms" "$REPORT_FILE")
      # 缩短 URL 显示
      ts_short=$(echo "$ts_url" | sed 's|https\?://[^/]*/||' | cut -c1-60)
      ts_text="${ts_text}• ${ts_short}: 脚本 ${ts_script}ms / 总计 ${ts_total}ms\n"
      j=$((j + 1))
    done
    api_children "$(jq -n --arg t "$(echo -e "$ts_text")" \
      '{children:[{block_type:2,text:{elements:[{text_run:{content:$t}}]}}],index:-1}')"
  fi

  # ── 优化建议（Lighthouse 自动检测）──
  opp_count=$(jq -r ".results[$i].opportunities | length" "$REPORT_FILE" 2>/dev/null || echo "0")
  if [ "$opp_count" -gt 0 ]; then
    api_children '{"children":[{"block_type":4,"heading2":{"elements":[{"text_run":{"content":"🔧 优化建议（按收益排序）"}}]}}],"index":-1}'

    j=0
    while [ "$j" -lt "$opp_count" ]; do
      opp_title=$(jq -r ".results[$i].opportunities[$j].title" "$REPORT_FILE")
      opp_savings=$(jq -r ".results[$i].opportunities[$j].savings_ms" "$REPORT_FILE")

      api_children "$(jq -n --arg t "${opp_title} — 可节省 ${opp_savings}ms" \
        '{children:[{block_type:13,ordered:{elements:[{text_run:{content:$t,text_element_style:{bold:true}}}]}}],index:-1}')"

      j=$((j + 1))
    done
  fi

  # ── 诊断问题 ──
  diag_count=$(jq -r ".results[$i].diagnostics | length" "$REPORT_FILE" 2>/dev/null || echo "0")
  if [ "$diag_count" -gt 0 ]; then
    api_children '{"children":[{"block_type":4,"heading2":{"elements":[{"text_run":{"content":"⚠️ 诊断问题"}}]}}],"index":-1}'

    j=0
    while [ "$j" -lt "$diag_count" ]; do
      diag_title=$(jq -r ".results[$i].diagnostics[$j].title" "$REPORT_FILE")
      diag_val=$(jq -r ".results[$i].diagnostics[$j].displayValue // empty" "$REPORT_FILE")
      if [ -n "$diag_val" ]; then
        text="${diag_title} (${diag_val})"
      else
        text="$diag_title"
      fi

      api_children "$(jq -n --arg t "$text" \
        '{children:[{block_type:12,bullet:{elements:[{text_run:{content:$t}}]}}],index:-1}')"

      j=$((j + 1))
    done
  fi

  # ── 实际优化建议（基于指标分析）──
  api_children '{"children":[{"block_type":4,"heading2":{"elements":[{"text_run":{"content":"💡 针对性优化方案"}}]}}],"index":-1}'

  # 根据各指标状态生成具体建议
  suggestions=""
  if [ "$lcp" -gt 4000 ] 2>/dev/null; then
    suggestions="${suggestions}\n• LCP ${lcp}ms 严重超标：检查首屏大图是否用了 WebP/AVIF 格式、是否加了 fetchpriority=high、第三方 App 脚本是否阻塞渲染"
  elif [ "$lcp" -gt 2500 ] 2>/dev/null; then
    suggestions="${suggestions}\n• LCP ${lcp}ms 需优化：考虑内联关键 CSS、预加载 Hero 图、延迟非首屏资源"
  fi

  if [ "$ttfb" -gt 1800 ] 2>/dev/null; then
    suggestions="${suggestions}\n• TTFB ${ttfb}ms 过高：检查服务器响应速度、CDN 缓存命中率、是否有重定向链"
  elif [ "$ttfb" -gt 800 ] 2>/dev/null; then
    suggestions="${suggestions}\n• TTFB ${ttfb}ms 偏高：考虑开启页面缓存、检查 DNS 解析时间"
  fi

  if [ "$tbt" -gt 600 ] 2>/dev/null; then
    suggestions="${suggestions}\n• TBT ${tbt}ms 主线程阻塞严重：拆分长任务、延迟加载非关键 JS、移除不必要的第三方脚本"
  elif [ "$tbt" -gt 200 ] 2>/dev/null; then
    suggestions="${suggestions}\n• TBT ${tbt}ms 偏高：考虑 Code Splitting、defer 非关键脚本"
  fi

  if [ "$cls_int" -gt 250 ] 2>/dev/null; then
    suggestions="${suggestions}\n• CLS ${cls_display} 布局偏移严重：给图片/广告设置固定宽高、避免动态插入内容"
  elif [ "$cls_int" -gt 100 ] 2>/dev/null; then
    suggestions="${suggestions}\n• CLS ${cls_display} 偏高：检查字体加载是否导致闪烁、动态内容是否预留空间"
  fi

  if [ "$score" -lt 50 ] 2>/dev/null; then
    suggestions="${suggestions}\n• 综合分 ${score} 极低：建议整体审计第三方脚本数量（目标 ≤3 个），优先解决 LCP 和 TBT"
  fi

  if [ -z "$suggestions" ]; then
    suggestions="各项指标均在合理范围内，继续保持。可关注长期趋势变化。"
  fi

  api_children "$(jq -n --arg t "$(echo -e "$suggestions")" \
    '{children:[{block_type:2,text:{elements:[{text_run:{content:$t}}]}}],index:-1}')"

  # 多 URL 分隔
  if [ $((i + 1)) -lt "$count" ]; then
    api_children '{"children":[{"block_type":22,"divider":{}}],"index":-1}'
  fi

  i=$((i + 1))
done

# ── 尾注 ──
api_children "$(jq -n --arg t "🤖 自动生成 · ${dt}" \
  '{children:[{block_type:22,divider:{}},{block_type:2,text:{elements:[{text_run:{content:$t,text_element_style:{italic:true}}}]}}],index:-1}')"

# ── 返回文档 URL ──
if [ -n "$NODE_TOKEN" ]; then
  DOC_URL="https://${FEISHU_DOMAIN}/wiki/${NODE_TOKEN}"
else
  DOC_URL="https://${FEISHU_DOMAIN}/docx/${DOC_ID}"
fi
log "文档完成: $DOC_URL"
echo "$DOC_URL"
