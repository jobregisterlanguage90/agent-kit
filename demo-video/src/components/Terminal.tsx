import React from "react";
import { useCurrentFrame, interpolate } from "remotion";
import { COLORS, FONTS } from "../styles";

interface TerminalLine {
  text: string;
  delay: number;
  color?: string;
}

interface TerminalProps {
  lines: TerminalLine[];
  title?: string;
  width?: number | string;
}

export const Terminal: React.FC<TerminalProps> = ({
  lines,
  title = "Terminal",
  width = "100%",
}) => {
  const frame = useCurrentFrame();

  // 计算每行的实际开始帧（上一行打完后才开始下一行）
  const lineStarts: number[] = [];
  let currentStart = lines[0]?.delay || 0;
  for (let i = 0; i < lines.length; i++) {
    lineStarts.push(currentStart);
    // 每行打字时间 = 字符数 * 2 帧 + 10 帧间隔
    const typingDuration = lines[i].text.length > 0 ? lines[i].text.length * 2 + 10 : 5;
    currentStart += typingDuration;
  }

  return (
    <div
      style={{
        background: COLORS.terminal,
        borderRadius: 12,
        padding: 0,
        fontFamily: FONTS.mono,
        fontSize: 18,
        overflow: "hidden",
        boxShadow: "0 20px 60px rgba(0,0,0,0.5)",
        width,
      }}
    >
      <div
        style={{
          background: COLORS.terminalBar,
          padding: "8px 16px",
          display: "flex",
          alignItems: "center",
          gap: 8,
        }}
      >
        <div style={{ width: 12, height: 12, borderRadius: "50%", background: COLORS.red }} />
        <div style={{ width: 12, height: 12, borderRadius: "50%", background: COLORS.yellow }} />
        <div style={{ width: 12, height: 12, borderRadius: "50%", background: COLORS.green }} />
        <span style={{ color: COLORS.textDim, marginLeft: 8, fontSize: 14 }}>{title}</span>
      </div>
      <div style={{ padding: "16px 20px", minHeight: 200 }}>
        {lines.map((line, i) => {
          const start = lineStarts[i];
          if (frame < start) return null;

          const len = line.text.length;
          if (len === 0) {
            // 空行直接显示
            return <div key={i} style={{ height: 8 }} />;
          }

          const charCount = interpolate(
            frame - start,
            [0, len * 2],
            [0, len],
            { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
          );

          const isTyping = charCount < len;
          const showCursor = isTyping;

          return (
            <div
              key={i}
              style={{
                color: line.color || COLORS.text,
                marginBottom: 4,
                whiteSpace: "pre",
              }}
            >
              {line.text.slice(0, Math.floor(charCount))}
              {showCursor && (
                <span style={{ opacity: frame % 30 < 15 ? 1 : 0 }}>▋</span>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
};
