export const RIGHT_HAND_STAFF_ID = "1";
export const LEFT_HAND_STAFF_ID = "2";

export function handStateForMode(mode) {
  if (mode === "right") return { rightHandEnabled: true, leftHandEnabled: false };
  if (mode === "left") return { rightHandEnabled: false, leftHandEnabled: true };
  return { rightHandEnabled: true, leftHandEnabled: true };
}

export function handModeForState(rightHandEnabled, leftHandEnabled) {
  if (rightHandEnabled && !leftHandEnabled) return "right";
  if (!rightHandEnabled && leftHandEnabled) return "left";
  return "both";
}

export function enabledHandStaffIDs(rightHandEnabled, leftHandEnabled, noteAnchors = []) {
  const result = new Set();
  const availableStaffIDs = [...new Set(noteAnchors.map((anchor) => String(anchor.staffID)))];
  const staffIDs = availableStaffIDs.length > 0 ? availableStaffIDs : [RIGHT_HAND_STAFF_ID, LEFT_HAND_STAFF_ID];
  for (const staffID of staffIDs) {
    const staffNumber = Number(staffID);
    if (!Number.isInteger(staffNumber)) {
      if (rightHandEnabled && leftHandEnabled) result.add(staffID);
    } else if ((staffNumber % 2 === 1 && rightHandEnabled) || (staffNumber % 2 === 0 && leftHandEnabled)) {
      result.add(staffID);
    }
  }
  return result;
}

export function noteIDsForEnabledStaffs(event, noteAnchors, enabledStaffIDs) {
  const staffByNoteID = new Map((noteAnchors ?? []).map((anchor) => [anchor.noteID, String(anchor.staffID)]));
  return (event?.noteIDs ?? []).filter((noteID) => enabledStaffIDs.has(staffByNoteID.get(noteID)));
}

export function pitchesForEnabledStaffs(event, noteAnchors, enabledStaffIDs) {
  const anchorByNoteID = new Map((noteAnchors ?? []).map((anchor) => [anchor.noteID, anchor]));
  const pitches = new Set();
  for (const noteID of event?.noteIDs ?? []) {
    const anchor = anchorByNoteID.get(noteID);
    if (anchor && enabledStaffIDs.has(String(anchor.staffID)) && Number.isInteger(anchor.midiNumber)) {
      pitches.add(anchor.midiNumber);
    }
  }
  return [...pitches];
}
