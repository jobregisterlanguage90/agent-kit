import React from "react";
import { Terminal } from "../components/Terminal";
import { FadeIn } from "../components/FadeIn";
import { COLORS, FONTS } from "../styles";

export const Scene2Launch: React.FC = () => {
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
          Step 2: Launch
        </h1>
      </FadeIn>

      <FadeIn startFrame={40} style={{ width: "80%" }}>
        <Terminal
          title="my-ops-agent"
          lines={[
            { text: "$ claude", delay: 60, color: COLORS.green },
            { text: "", delay: 0 },
            { text: "[SessionStart] Dashboard starting on :7890...", delay: 0, color: COLORS.cyan },
            { text: "[SessionStart] Plugins: feishu-notify ✓", delay: 0 },
            { text: "", delay: 0 },
            { text: "Dashboard ready: http://localhost:7890", delay: 0, color: COLORS.green },
            { text: "Initializing 12 servers from entities.yaml...", delay: 0 },
            { text: "Loading memory states...", delay: 0 },
            { text: "Claude status: connected", delay: 0, color: COLORS.accent },
          ]}
        />
      </FadeIn>
    </div>
  );
};
