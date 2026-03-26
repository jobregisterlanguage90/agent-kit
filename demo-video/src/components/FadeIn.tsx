import React from "react";
import { useCurrentFrame, interpolate } from "remotion";

export const FadeIn: React.FC<{
  startFrame: number;
  duration?: number;
  children: React.ReactNode;
  style?: React.CSSProperties;
}> = ({ startFrame, duration = 15, children, style }) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(frame - startFrame, [0, duration], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  if (frame < startFrame) return null;
  return <div style={{ opacity, ...style }}>{children}</div>;
};
