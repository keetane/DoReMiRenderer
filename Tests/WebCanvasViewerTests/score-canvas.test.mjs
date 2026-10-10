import assert from "node:assert/strict";
import test from "node:test";

import { drawScoreCanvas } from "../../Examples/WebCanvasViewer/score-canvas.js";

globalThis.window = { devicePixelRatio: 1 };

test("a natural sign keeps its note color when it overlaps the preceding notehead anchor", () => {
  const drawnText = [];
  const context = recordingContext(drawnText);
  const canvas = {
    clientWidth: 100,
    dataset: {},
    style: {},
    getContext: () => context,
  };
  const red = { red: 1, green: 0, blue: 0, alpha: 1 };
  const black = { red: 0, green: 0, blue: 0, alpha: 1 };
  const plan = {
    canvas: { x: 0, y: 0, width: 100, height: 50 },
    commands: [
      textCommand("\uE261", 10.5, red),
      textCommand("\uE0A4", 22, black),
    ],
    accidentals: [
      { point: { x: 10.5, y: 20 }, noteID: "current-c", colorPitchClass: 0 },
    ],
    noteAnchors: [
      noteAnchor("previous-d", 10, 2),
      noteAnchor("current-c", 22, 0),
    ],
  };

  drawScoreCanvas(canvas, plan, {
    noteColors: true,
    enabledPitchClasses: new Set([0, 2]),
    noteColorForPitchClass: (pitchClass) => pitchClass === 0 ? "#ef2929" : "#f28c18",
  });

  assert.deepEqual(drawnText, [
    { text: "\uE261", color: "#ef2929" },
    { text: "\uE0A4", color: "#ef2929" },
  ]);
});

function textCommand(text, x, color) {
  return {
    kind: "drawText",
    text,
    point: { x, y: 20 },
    fontRole: "smufl",
    fontSize: 12,
    color,
    mirroredHorizontally: false,
    mirroredVertically: false,
  };
}

function noteAnchor(noteID, x, colorPitchClass) {
  return {
    noteID,
    center: { x, y: 20 },
    frame: { x: x - 5, y: 16, width: 10, height: 8 },
    midiNumber: colorPitchClass === 0 ? 72 : 74,
    colorPitchClass,
  };
}

function recordingContext(drawnText) {
  return {
    fillStyle: "",
    strokeStyle: "",
    lineWidth: 1,
    font: "",
    textAlign: "",
    textBaseline: "",
    setTransform() {},
    clearRect() {},
    fillRect() {},
    beginPath() {},
    moveTo() {},
    lineTo() {},
    stroke() {},
    ellipse() {},
    fill() {},
    quadraticCurveTo() {},
    save() {},
    restore() {},
    translate() {},
    scale() {},
    setLineDash() {},
    measureText() {
      return {
        actualBoundingBoxLeft: 0,
        actualBoundingBoxRight: 10,
        actualBoundingBoxAscent: 8,
        actualBoundingBoxDescent: 2,
        width: 10,
      };
    },
    fillText(text) {
      drawnText.push({ text, color: this.fillStyle });
    },
  };
}
