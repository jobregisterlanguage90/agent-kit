import React from "react";
import { useCurrentFrame, interpolate } from "remotion";
import { FadeIn } from "../components/FadeIn";
import { COLORS, FONTS } from "../styles";

const FEATURES = [
  { icon: "🏗️", text: "One command to create", delay: 60 },
  { icon: "🚀", text: "Auto-start with hooks", delay: 100 },
  { icon: "🤖", text: "Team of parallel workers", delay: 140 },
  { icon: "🖥️", text: "Real-time dashboard", delay: 180 },
  { icon: "🔗", text: "Cross-process communication", delay: 220 },
  { icon: "🧠", text: "Per-entity memory", delay: 260 },
  { icon: "📚", text: "Self-learning system", delay: 300 },
  { icon: "🔌", text: "Plugin architecture", delay: 340 },
];

export const Scene6Summary: React.FC = () => {
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
      <FadeIn startFrame={0}>
        <h1
          style={{
            fontFamily: FONTS.sans,
            fontSize: 64,
            color: COLORS.white,
            fontWeight: 700,
            marginBottom: 50,
          }}
        >
          Claude Agent Kit
        </h1>
      </FadeIn>

      <div
        style={{
          display: "grid",
          gridTemplateColumns: "1fr 1fr",
          gap: 20,
          maxWidth: 800,
        }}
      >
        {FEATURES.map((f) => {
          const opacity = interpolate(frame - f.delay, [0, 15], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          });
          return (
            <div
              key={f.text}
              style={{
                opacity,
                display: "flex",
                alignItems: "center",
                gap: 16,
                padding: "12px 20px",
              }}
            >
              <span style={{ fontSize: 32 }}>{f.icon}</span>
              <span
                style={{
                  fontFamily: FONTS.sans,
                  fontSize: 22,
                  color: COLORS.text,
                }}
              >
                {f.text}
              </span>
            </div>
          );
        })}
      </div>

      <FadeIn startFrame={400} style={{ marginTop: 50 }}>
        <p
          style={{
            fontFamily: FONTS.mono,
            fontSize: 28,
            color: COLORS.accent,
            fontWeight: 600,
          }}
        >
          github.com/anjiacm/agent-kit
        </p>
      </FadeIn>
    </div>
  );
};
