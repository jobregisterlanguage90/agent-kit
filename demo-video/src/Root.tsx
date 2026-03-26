import React from "react";
import { Audio, Composition, Sequence, staticFile } from "remotion";
import { Scene1Create } from "./scenes/Scene1Create";
import { Scene2Launch } from "./scenes/Scene2Launch";
import { Scene3Team } from "./scenes/Scene3Team";
import { Scene4Dashboard } from "./scenes/Scene4Dashboard";
import { Scene5CrossProcess } from "./scenes/Scene5CrossProcess";
import { Scene6Summary } from "./scenes/Scene6Summary";
import { SCENE_TIMING } from "./styles";

const KitDemo: React.FC = () => {
  const { scene1, scene2, scene3, scene4, scene5, scene6 } = SCENE_TIMING;

  return (
    <div style={{ width: "100%", height: "100%", background: "#0a0a1a" }}>
      {/* BGM — 全程播放，音量低 */}
      <Audio src={staticFile("audio/bgm.mp3")} volume={0.15} />

      {/* Scene 1 */}
      <Sequence from={scene1.start} durationInFrames={scene1.end - scene1.start}>
        <Scene1Create />
        <Audio src={staticFile("audio/scene1.mp3")} volume={0.9} />
      </Sequence>

      {/* Scene 2 */}
      <Sequence from={scene2.start} durationInFrames={scene2.end - scene2.start}>
        <Scene2Launch />
        <Audio src={staticFile("audio/scene2.mp3")} volume={0.9} />
      </Sequence>

      {/* Scene 3 */}
      <Sequence from={scene3.start} durationInFrames={scene3.end - scene3.start}>
        <Scene3Team />
        <Audio src={staticFile("audio/scene3.mp3")} volume={0.9} />
      </Sequence>

      {/* Scene 4 */}
      <Sequence from={scene4.start} durationInFrames={scene4.end - scene4.start}>
        <Scene4Dashboard />
        <Audio src={staticFile("audio/scene4.mp3")} volume={0.9} />
      </Sequence>

      {/* Scene 5 */}
      <Sequence from={scene5.start} durationInFrames={scene5.end - scene5.start}>
        <Scene5CrossProcess />
        <Audio src={staticFile("audio/scene5.mp3")} volume={0.9} />
      </Sequence>

      {/* Scene 6 */}
      <Sequence from={scene6.start} durationInFrames={scene6.end - scene6.start}>
        <Scene6Summary />
        <Audio src={staticFile("audio/scene6.mp3")} volume={0.9} />
      </Sequence>
    </div>
  );
};

export const RemotionRoot: React.FC = () => {
  return (
    <Composition
      id="KitDemo"
      component={KitDemo}
      durationInFrames={3600}
      fps={30}
      width={1920}
      height={1080}
    />
  );
};
