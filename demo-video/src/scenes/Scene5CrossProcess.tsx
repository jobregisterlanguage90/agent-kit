import React from "react";
import { useCurrentFrame, interpolate } from "remotion";
import { FadeIn } from "../components/FadeIn";
import { COLORS, FONTS } from "../styles";

export const Scene5CrossProcess: React.FC = () => {
  const frame = useCurrentFrame();

  const arrowProgress = interpolate(frame, [150, 250], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

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
          Step 5: Cross-Process Communication
        </h1>
      </FadeIn>

      <div style={{ display: "flex", gap: 60, alignItems: "center" }}>
        <FadeIn startFrame={60}>
          <div
            style={{
              background: `${COLORS.accent}15`,
              border: `2px solid ${COLORS.accent}`,
              borderRadius: 16,
              padding: "30px 40px",
              textAlign: "center",
            }}
          >
            <div style={{ fontFamily: FONTS.mono, fontSize: 20, color: COLORS.accent }}>
              :7890
            </div>
            <div style={{ fontFamily: FONTS.sans, fontSize: 16, color: COLORS.text, marginTop: 8 }}>
              ops-agent
            </div>
          </div>
        </FadeIn>

        <div
          style={{
            width: 120,
            height: 4,
            background: `linear-gradient(90deg, ${COLORS.accent}, ${COLORS.cyan})`,
            transform: `scaleX(${arrowProgress})`,
            transformOrigin: "left",
            borderRadius: 2,
          }}
        />

        <FadeIn startFrame={100}>
          <div
            style={{
              background: `${COLORS.cyan}15`,
              border: `2px solid ${COLORS.cyan}`,
              borderRadius: 16,
              padding: "30px 40px",
              textAlign: "center",
            }}
          >
            <div style={{ fontFamily: FONTS.mono, fontSize: 20, color: COLORS.cyan }}>
              :7892
            </div>
            <div style={{ fontFamily: FONTS.sans, fontSize: 16, color: COLORS.text, marginTop: 8 }}>
              dev-agent
            </div>
          </div>
        </FadeIn>
      </div>

      <FadeIn startFrame={300} style={{ marginTop: 50 }}>
        <p
          style={{
            fontFamily: FONTS.sans,
            fontSize: 24,
            color: COLORS.accentLight,
            textAlign: "center",
          }}
        >
          Multiple Kit instances discover each other and exchange messages
        </p>
      </FadeIn>
    </div>
  );
};
