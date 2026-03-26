import React from "react";
import { FadeIn } from "../components/FadeIn";
import { COLORS, FONTS } from "../styles";

export const Scene4Dashboard: React.FC = () => {
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
      <FadeIn startFrame={0} style={{ marginBottom: 40 }}>
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
          Step 4: Dual-Channel Interaction
        </h1>
      </FadeIn>

      <FadeIn startFrame={60} style={{ marginBottom: 30 }}>
        <div
          style={{
            display: "flex",
            gap: 40,
            alignItems: "center",
          }}
        >
          <div
            style={{
              background: COLORS.terminal,
              borderRadius: 16,
              padding: "30px 40px",
              textAlign: "center",
              border: `2px solid ${COLORS.green}`,
            }}
          >
            <div style={{ fontSize: 48, marginBottom: 10 }}>⌨️</div>
            <div style={{ fontFamily: FONTS.sans, fontSize: 20, color: COLORS.white }}>
              Terminal
            </div>
            <div style={{ fontFamily: FONTS.mono, fontSize: 14, color: COLORS.textDim, marginTop: 8 }}>
              Type commands directly
            </div>
          </div>

          <div style={{ fontSize: 36, color: COLORS.accent }}>⟷</div>

          <div
            style={{
              background: COLORS.terminal,
              borderRadius: 16,
              padding: "30px 40px",
              textAlign: "center",
              border: `2px solid ${COLORS.blue}`,
            }}
          >
            <div style={{ fontSize: 48, marginBottom: 10 }}>🖥️</div>
            <div style={{ fontFamily: FONTS.sans, fontSize: 20, color: COLORS.white }}>
              Dashboard
            </div>
            <div style={{ fontFamily: FONTS.mono, fontSize: 14, color: COLORS.textDim, marginTop: 8 }}>
              Click buttons, real-time view
            </div>
          </div>
        </div>
      </FadeIn>

      <FadeIn startFrame={180}>
        <p
          style={{
            fontFamily: FONTS.sans,
            fontSize: 24,
            color: COLORS.accentLight,
            textAlign: "center",
          }}
        >
          Both channels equal priority. Dashboard polls every 3s.
        </p>
      </FadeIn>
    </div>
  );
};
