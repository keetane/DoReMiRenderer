import assert from "node:assert/strict";
import test from "node:test";

import {
  compactHandPrintPages,
  compactHandSystemGap,
  displayYForSourceY,
  drawScoreCanvas,
  sourceYForDisplayY,
} from "../../Examples/WebCanvasViewer/score-canvas.js";

test("one-hand system gap is half the previous compact spacing", () => {
  assert.equal(compactHandSystemGap(5), 15);
  assert.equal(compactHandSystemGap(5, true), 10);
  assert.equal(compactHandSystemGap(2), 10, "minimum gap remains readable at small scales");
});

test("one-hand screen and print pages retain A4 frames and pack up to nine systems per page", () => {
  const width = 595;
  const height = 842;
  const systems = [];
  const staffLines = [];
  const noteAnchors = [];
  const pages = [];
  for (let pageIndex = 0; pageIndex < 10; pageIndex += 1) {
    const pageY = pageIndex * height;
    const systemIndices = [];
    for (let offset = 0; offset < 2; offset += 1) {
      const index = pageIndex * 2 + offset;
      const systemY = pageY + 120 + offset * 280;
      systemIndices.push(index);
      systems.push({ index, frame: { x: 24, y: systemY, width: 547, height: 90 } });
      for (const staffOffset of [0, 60]) {
        for (let line = 0; line < 5; line += 1) {
          const y = systemY + staffOffset + line * 5;
          staffLines.push({ start: { x: 24, y }, end: { x: 571, y } });
        }
      }
      noteAnchors.push({
        noteID: `right-${index}`,
        staffID: "1",
        systemIndex: index,
        frame: { x: 100, y: systemY + 6, width: 10, height: 8 },
      });
      noteAnchors.push({
        noteID: `left-${index}`,
        staffID: "2",
        systemIndex: index,
        frame: { x: 100, y: systemY + 66, width: 10, height: 8 },
      });
    }
    pages.push({
      index: pageIndex,
      frame: { x: 0, y: pageY, width, height },
      contentFrame: { x: 24, y: pageY + 24, width: 547, height: 794 },
      systemIndices,
    });
  }
  const plan = {
    canvas: { x: 0, y: 0, width, height: height * pages.length },
    pages,
    systems,
    staffLines,
    noteAnchors,
    commands: [{
      kind: "drawText",
      text: "pp",
      point: { x: 100, y: 158 },
      fontRole: "serifItalic",
      fontSize: 10,
    }],
  };

  const compactPages = compactHandPrintPages(plan, new Set(["1"]));
  assert.ok(compactPages.length < pages.length);
  assert.deepEqual(compactPages.map((page) => page.systemIndices.length), [9, 9, 2]);
  assert.ok(compactPages[0].segments[0].sourceBottom >= 166, "pianissimo ink and clearance remain inside the visible hand segment");
  for (const page of compactPages) {
    assert.deepEqual(page.frame, { x: 0, y: 0, width, height });
    assert.ok(page.segments.at(-1).destinationTop + (page.segments.at(-1).sourceBottom - page.segments.at(-1).sourceTop) <= height - 18);
    if (page.segments.length > 2) {
      const displayedStaffTops = page.segments.map((segment) => (
        segment.destinationTop + segment.sourceStaffTop - segment.sourceTop
      ));
      const pitches = displayedStaffTops.slice(1).map((staffTop, index) => staffTop - displayedStaffTops[index]);
      for (const pitch of pitches.slice(1)) {
        assert.ok(Math.abs(pitch - pitches[0]) < 0.001, "visible one-hand staffs use an even vertical pitch");
      }
    }
  }
});

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

test("hand mode colors noteheads only on enabled staffs", () => {
  const drawnText = [];
  const context = recordingContext(drawnText);
  const canvas = {
    clientWidth: 100,
    dataset: {},
    style: {},
    getContext: () => context,
  };
  const black = { red: 0, green: 0, blue: 0, alpha: 1 };
  const plan = {
    canvas: { x: 0, y: 0, width: 100, height: 50 },
    commands: [
      textCommand("\uE0A4", 20, black),
      textCommand("\uE0A4", 60, black),
    ],
    noteAnchors: [
      { ...noteAnchor("right", 20, 0), staffID: "1" },
      { ...noteAnchor("left", 60, 0), staffID: "2" },
    ],
  };

  drawScoreCanvas(canvas, plan, {
    noteColors: true,
    enabledPitchClasses: new Set([0]),
    enabledStaffIDs: new Set(["1"]),
    noteColorForPitchClass: () => "#ef2929",
  });

  assert.deepEqual(drawnText, [
    { text: "\uE0A4", color: "#ef2929" },
    { text: "\uE0A4", color: "rgba(0, 0, 0, 1)" },
  ]);
});

test("standard renderer masks the lower staff before compact composition", () => {
  const filledRects = [];
  const context = recordingContext([], filledRects);
  const canvas = {
    clientWidth: 100,
    dataset: {},
    style: {},
    getContext: () => context,
  };
  const staffLines = [10, 15, 20, 25, 30, 70, 75, 80, 85, 90].map((y) => ({
    start: { x: 0, y }, end: { x: 100, y }, pitchClass: "c",
  }));
  const plan = {
    canvas: { x: 0, y: 0, width: 100, height: 120 },
    commands: [],
    noteAnchors: [],
    staffLines,
    systems: [{ index: 0, frame: { x: 0, y: 10, width: 100, height: 80 } }],
  };

  drawScoreCanvas(canvas, plan, { enabledStaffIDs: new Set(["1"]) });

  assert.equal(canvas.dataset.hiddenStaffCount, "1");
  const lowerStaffMask = filledRects.find((rect) => rect.width > 100);
  assert.ok(lowerStaffMask);
  assert.ok(lowerStaffMask.y <= 70);
  assert.ok(lowerStaffMask.y + lowerStaffMask.height >= 90);
  assert.ok(filledRects.some((rect) => rect.width < 20), "grand-staff brace should also be masked");
});

test("one-hand mode trims cross-staff barlines to the visible staff", () => {
  const filledRects = [];
  const strokedLines = [];
  const context = recordingContext([], filledRects, strokedLines);
  const canvas = {
    clientWidth: 100,
    dataset: {},
    style: {},
    getContext: () => context,
  };
  const staffLines = [10, 15, 20, 25, 30, 70, 75, 80, 85, 90].map((y) => ({
    start: { x: 0, y }, end: { x: 100, y }, pitchClass: "c",
  }));
  const black = { red: 0, green: 0, blue: 0, alpha: 1 };
  const plan = {
    canvas: { x: 0, y: 0, width: 100, height: 120 },
    commands: [
      {
        kind: "strokeLine", start: { x: 50, y: 10 }, end: { x: 50, y: 90 }, lineWidth: 1, color: black,
      },
      {
        kind: "strokeLine", start: { x: 60, y: 30 }, end: { x: 60, y: 70 }, lineWidth: 1, color: black,
      },
    ],
    noteAnchors: [],
    staffLines,
    systems: [{ index: 0, frame: { x: 0, y: 10, width: 100, height: 80 } }],
  };

  drawScoreCanvas(canvas, plan, { enabledStaffIDs: new Set(["1"]) });

  assert.ok(strokedLines.some((line) => line.color === "rgba(0, 0, 0, 1)" && line.x1 === 50 && line.y1 === 10 && line.y2 === 30));
  assert.ok(!strokedLines.some((line) => line.color === "rgba(0, 0, 0, 1)" && line.x1 === 50 && line.y1 === 70 && line.y2 === 90));
  assert.ok(!strokedLines.some((line) => line.x1 === 60), "the connector between hidden and visible staffs is omitted");
  assert.ok(!strokedLines.some((line) => line.color === "#fff" && line.x1 === 50), "barlines are clipped directly without erase-and-redraw artifacts");
  const braceMask = filledRects.find((rect) => rect.width < 20 && rect.height > 80);
  assert.ok(braceMask, "the hidden grand-staff brace is masked");
  assert.equal(braceMask.x + braceMask.width, 0, "brace masking stops at the staff start so no gap is cut into the five staff lines");
});

test("compact hand coordinates map between displayed and source score positions", () => {
  const canvas = {
    _scoreVerticalSegments: [
      { sourceTop: 100, sourceBottom: 180, destinationTop: 60, destinationBottom: 140 },
      { sourceTop: 300, sourceBottom: 380, destinationTop: 170, destinationBottom: 250 },
    ],
  };

  assert.equal(displayYForSourceY(canvas, 125), 85);
  assert.equal(sourceYForDisplayY(canvas, 85), 125);
  assert.equal(displayYForSourceY(canvas, 325), 195);
  assert.equal(sourceYForDisplayY(canvas, 195), 325);
  assert.equal(displayYForSourceY(canvas, 500), 500, "positions outside compact segments remain unchanged");
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

function recordingContext(drawnText, filledRects = [], strokedLines = []) {
  let start = null;
  let end = null;
  return {
    fillStyle: "",
    strokeStyle: "",
    lineWidth: 1,
    font: "",
    textAlign: "",
    textBaseline: "",
    setTransform() {},
    clearRect() {},
    fillRect(x, y, width, height) { filledRects.push({ x, y, width, height }); },
    beginPath() { start = null; end = null; },
    moveTo(x, y) { start = { x, y }; },
    lineTo(x, y) { end = { x, y }; },
    stroke() {
      if (start && end) strokedLines.push({
        x1: start.x, y1: start.y, x2: end.x, y2: end.y, color: this.strokeStyle, lineWidth: this.lineWidth,
      });
    },
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
