import React from "react";
import { useCurrentFrame } from "remotion";
import { Terminal } from "../components/Terminal";
import { FadeIn } from "../components/FadeIn";
import { TypingText } from "../components/TypingText";
import { COLORS, FONTS } from "../styles";

export const Scene1Create: React.FC = () => {
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
      <FadeIn startFrame={0} duration={20} style={{ marginBottom: 40 }}>
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
          Step 1: Create Your Agent
        </h1>
      </FadeIn>

      <FadeIn startFrame={60} style={{ width: "80%" }}>
        <Terminal
          title="~/code"
          lines={[
            { text: "$ bash create-agent.sh", delay: 80, color: COLORS.green },
            { text: "", delay: 0 },
            { text: "╔══════════════════════════════════════╗", delay: 0, color: COLORS.cyan },
            { text: "║    Claude Agent Kit — Create Agent    ║", delay: 0, color: COLORS.cyan },
            { text: "╚══════════════════════════════════════╝", delay: 0, color: COLORS.cyan },
            { text: "", delay: 0 },
            { text: "Project name: my-ops-agent", delay: 0, color: COLORS.text },
            { text: "Agent role: Server Operations", delay: 0 },
            { text: "Dashboard port: 7890", delay: 0 },
            { text: "Team size: 4 Workers", delay: 0 },
            { text: "", delay: 0 },
            { text: "=== ✅ Environment Check ===", delay: 0, color: COLORS.green },
            { text: "  Node.js v25.3.0 ✅", delay: 0, color: COLORS.green },
            { text: "  npm 11.6.2 ✅", delay: 0, color: COLORS.green },
            { text: "  jq 1.8.1 ✅", delay: 0, color: COLORS.green },
            { text: "", delay: 0 },
            { text: "✅ Project created at ~/code/my-ops-agent", delay: 0, color: COLORS.accent },
          ]}
        />
      </FadeIn>
    </div>
  );
};
