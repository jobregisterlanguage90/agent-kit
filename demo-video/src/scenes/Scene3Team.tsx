import React from "react";
import { useCurrentFrame, interpolate } from "remotion";
import { FadeIn } from "../components/FadeIn";
import { COLORS, FONTS } from "../styles";

const WORKERS = [
  { name: "ops-worker-1", color: "#3b82f6", delay: 80 },
  { name: "ops-worker-2", color: "#10b981", delay: 120 },
  { name: "ops-worker-3", color: "#f59e0b", delay: 160 },
  { name: "ops-worker-4", color: "#ef4444", delay: 200 },
];

export const Scene3Team: React.FC = () => {
  const frame = useCurrentFrame();

  return (
    <div
      style={{
        width: "100%",
        height: "100%",
        background: COLORS.bg,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        padding: 80,
      }}
    >
      <FadeIn startFrame={0} style={{ marginBottom: 60 }}>
        <h1
          style={{
            fontFamily: FONTS.sans,
            fontSize: 52,
            color: COLORS.white,
            fontWeight: 700,
            textAlign: "center",
            letterSpacing: "-0.02em",
          }}
        >
          Step 3: Team Spawns
        </h1>
      </FadeIn>

      <div style={{ display: "flex", gap: 30, flexWrap: "wrap", justifyContent: "center" }}>
        {WORKERS.map((w) => {
          const opacity = interpolate(frame - w.delay, [0, 20], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          });
          const scale = interpolate(frame - w.delay, [0, 20], [0.5, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          });
          return (
            <div
              key={w.name}
              style={{
                opacity,
                transform: `scale(${scale})`,
                background: `${w.color}15`,
                border: `2px solid ${w.color}`,
                borderRadius: 16,
                padding: "30px 40px",
                textAlign: "center",
                minWidth: 200,
              }}
            >
              <div style={{ fontSize: 48, marginBottom: 10 }}>🤖</div>
              <div
                style={{
                  fontFamily: FONTS.mono,
                  fontSize: 18,
                  color: w.color,
                  fontWeight: 600,
                }}
              >
                {w.name}
              </div>
              <div
                style={{
                  fontFamily: FONTS.sans,
                  fontSize: 14,
                  color: COLORS.textDim,
                  marginTop: 8,
                }}
              >
                {frame > w.delay + 60 ? "ready" : "spawning..."}
              </div>
            </div>
          );
        })}
      </div>

      <FadeIn startFrame={280} style={{ marginTop: 50 }}>
        <p
          style={{
            fontFamily: FONTS.sans,
            fontSize: 24,
            color: COLORS.accentLight,
          }}
        >
          Lead dispatches. Workers execute. Memory per-entity.
        </p>
      </FadeIn>
    </div>
  );
};
