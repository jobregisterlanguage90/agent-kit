import React from "react";
import { useCurrentFrame, interpolate } from "remotion";

export const TypingText: React.FC<{
  text: string;
  startFrame: number;
  speed?: number;
  style?: React.CSSProperties;
}> = ({ text, startFrame, speed = 2, style }) => {
  const frame = useCurrentFrame();
  if (frame < startFrame || !text) return null;
  const chars = interpolate(
    frame - startFrame,
    [0, text.length * speed],
    [0, text.length],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
  );
  const visibleText = text.slice(0, Math.floor(chars));
  return (
    <span style={{ display: "inline-block", overflow: "hidden", ...style }}>
      {visibleText}
      {chars < text.length && <span style={{ opacity: frame % 30 < 15 ? 1 : 0 }}>▋</span>}
    </span>
  );
};
