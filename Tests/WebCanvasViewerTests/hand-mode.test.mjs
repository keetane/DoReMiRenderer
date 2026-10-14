import assert from "node:assert/strict";
import test from "node:test";

import {
  enabledHandStaffIDs,
  handModeForState,
  handStateForMode,
  noteIDsForEnabledStaffs,
  pitchesForEnabledStaffs,
} from "../../Examples/WebCanvasViewer/hand-mode.js";

const anchors = [
  { noteID: "right-c", staffID: "1", midiNumber: 72 },
  { noteID: "right-e", staffID: "1", midiNumber: 76 },
  { noteID: "left-c", staffID: "2", midiNumber: 48 },
];
const event = {
  noteIDs: ["right-c", "right-e", "left-c"],
  midiPitches: [72, 76, 48],
};

test("right-hand mode selects only upper-staff notes and pitches", () => {
  const staffs = enabledHandStaffIDs(true, false, anchors);
  assert.deepEqual(noteIDsForEnabledStaffs(event, anchors, staffs), ["right-c", "right-e"]);
  assert.deepEqual(pitchesForEnabledStaffs(event, anchors, staffs), [72, 76]);
});

test("left-hand mode selects only lower-staff notes and pitches", () => {
  const staffs = enabledHandStaffIDs(false, true, anchors);
  assert.deepEqual(noteIDsForEnabledStaffs(event, anchors, staffs), ["left-c"]);
  assert.deepEqual(pitchesForEnabledStaffs(event, anchors, staffs), [48]);
});

test("both hand modes preserve all notes and deduplicate a shared pitch", () => {
  const staffs = enabledHandStaffIDs(true, true, anchors);
  const sharedPitchAnchors = [...anchors, { noteID: "left-e", staffID: "2", midiNumber: 76 }];
  const sharedPitchEvent = { ...event, noteIDs: [...event.noteIDs, "left-e"] };
  assert.deepEqual(noteIDsForEnabledStaffs(sharedPitchEvent, sharedPitchAnchors, staffs), ["right-c", "right-e", "left-c", "left-e"]);
  assert.deepEqual(pitchesForEnabledStaffs(sharedPitchEvent, sharedPitchAnchors, staffs), [72, 76, 48]);
});

test("additional grand staffs follow odd-right and even-left pairing", () => {
  const multiPianoAnchors = [
    ...anchors,
    { noteID: "second-right", staffID: "3", midiNumber: 84 },
    { noteID: "second-left", staffID: "4", midiNumber: 36 },
  ];
  assert.deepEqual([...enabledHandStaffIDs(true, false, multiPianoAnchors)], ["1", "3"]);
  assert.deepEqual([...enabledHandStaffIDs(false, true, multiPianoAnchors)], ["2", "4"]);
  assert.deepEqual([...enabledHandStaffIDs(true, true, multiPianoAnchors)], ["1", "2", "3", "4"]);
});

test("three-way hand mode maps each segment to one unambiguous staff state", () => {
  assert.deepEqual(handStateForMode("right"), {
    rightHandEnabled: true,
    leftHandEnabled: false,
  });
  assert.deepEqual(handStateForMode("both"), {
    rightHandEnabled: true,
    leftHandEnabled: true,
  });
  assert.deepEqual(handStateForMode("left"), {
    rightHandEnabled: false,
    leftHandEnabled: true,
  });
  assert.deepEqual(handStateForMode("unexpected"), handStateForMode("both"));
});

test("hand state maps back to the selected segment", () => {
  assert.equal(handModeForState(true, false), "right");
  assert.equal(handModeForState(true, true), "both");
  assert.equal(handModeForState(false, true), "left");
  assert.equal(handModeForState(false, false), "both");
});
