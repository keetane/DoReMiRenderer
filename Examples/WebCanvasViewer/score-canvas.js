const SMUFL_FONT_FAMILY = "Bravura";
const SMUFL_PROBE = "\uE0A4";

export async function ensureSMuFLFont() {
  if (!document.fonts) {
    throw new Error("This browser does not support the Font Loading API required for SMuFL notation.");
  }

  // Canvas retains fallback glyphs from a draw made before this resolves.
  await document.fonts.load(`16px "${SMUFL_FONT_FAMILY}"`, SMUFL_PROBE);
  await document.fonts.ready;
  if (!document.fonts.check(`16px "${SMUFL_FONT_FAMILY}"`, SMUFL_PROBE)) {
    throw new Error("Bravura could not be loaded. Serve Bravura.otf beside this viewer and retain OFL.txt.");
  }
}

export function drawScoreCanvas(canvas, plan, options = {}) {
  const pixelRatio = Math.max(1, window.devicePixelRatio || 1);
  const cssWidth = canvas.clientWidth || plan.canvas.width;
  const layoutScale = cssWidth / plan.canvas.width;
  const cssHeight = plan.canvas.height * layoutScale;
  canvas.width = Math.round(cssWidth * pixelRatio);
  canvas.height = Math.round(cssHeight * pixelRatio);
  canvas.style.height = `${cssHeight}px`;

  const context = canvas.getContext("2d");
  context.setTransform(pixelRatio * layoutScale, 0, 0, pixelRatio * layoutScale, 0, 0);
  context.clearRect(0, 0, plan.canvas.width, plan.canvas.height);
  context.lineCap = "butt";
  context.lineJoin = "miter";

  // Keep page background behind the staff layer. The plan's background fill
  // otherwise covers staff rules if they are pulled out of command order.
  const backgroundCommandIndexes = new Set();
  for (const [index, command] of plan.commands.entries()) {
    if (isCanvasBackground(command, plan.canvas)) {
      backgroundCommandIndexes.add(index);
      drawCommand(context, command, cssColor(command.color));
    }
  }

  // Palette staff guides are above the black staff ink but below notation.
  // They use coordinates exported by ScoreLayout, never browser-derived staff
  // geometry, so changing their visual treatment cannot move score elements.
  const staffCommandIndexes = staffLineCommandIndexes(plan);
  const ledgerCommandIndexes = ledgerLineCommandIndexes(plan);
  for (const index of staffCommandIndexes) drawCommand(context, plan.commands[index], cssColor(plan.commands[index].color));
  for (const index of ledgerCommandIndexes) drawCommand(context, plan.commands[index], cssColor(plan.commands[index].color));
  drawPaletteBackground(context, canvas, plan, options);
  const noteheadColors = noteheadCommandColors(plan, options);
  canvas.dataset.paletteNoteCount = String(noteheadColors.size);

  for (const [commandIndex, command] of plan.commands.entries()) {
    if (backgroundCommandIndexes.has(commandIndex) || staffCommandIndexes.has(commandIndex) || ledgerCommandIndexes.has(commandIndex)) continue;
    drawCommand(context, command, noteheadColors.get(commandIndex) ?? cssColor(command.color));
  }
  // The playback bar intentionally sits above barlines and note ink. A guide
  // behind notation can disappear entirely when an onset coincides with a
  // measure boundary, defeating its navigation purpose.
  drawSystemGuide(context, canvas, plan, options.currentNoteIDs, {
    color: "#23bdf0", lineWidth: 4, alpha: 0.94, dataset: "currentSystemGuide",
  });
  drawSystemGuide(context, canvas, plan, options.nextNoteIDs, {
    color: "#76d8f4", lineWidth: 2, alpha: 0.9, dash: [6, 5], dataset: "nextSystemGuide",
  });
}

function isCanvasBackground(command, canvas) {
  const rect = command.rect;
  return command.kind === "fillRect" && rect
    && rect.x <= canvas.x && rect.y <= canvas.y
    && rect.width >= canvas.width && rect.height >= canvas.height;
}

function drawCommand(context, command, color) {
    context.fillStyle = color;
    context.strokeStyle = color;
    context.lineWidth = command.lineWidth || 1;

    switch (command.kind) {
      case "fillRect":
        context.fillRect(command.rect.x, command.rect.y, command.rect.width, command.rect.height);
        break;
      case "strokeLine":
        context.beginPath();
        context.moveTo(command.start.x, command.start.y);
        context.lineTo(command.end.x, command.end.y);
        context.stroke();
        break;
      case "fillEllipse":
      case "strokeEllipse":
        context.beginPath();
        context.ellipse(
          command.rect.x + command.rect.width / 2,
          command.rect.y + command.rect.height / 2,
          command.rect.width / 2,
          command.rect.height / 2,
          0,
          0,
          Math.PI * 2
        );
        command.kind === "fillEllipse" ? context.fill() : context.stroke();
        break;
      case "strokeQuadraticCurve":
        context.beginPath();
        context.moveTo(command.start.x, command.start.y);
        context.quadraticCurveTo(command.control.x, command.control.y, command.end.x, command.end.y);
        context.stroke();
        break;
      case "drawText":
        drawCenteredText(context, command);
        break;
      default:
        throw new Error(`Unsupported ScoreWebRenderCommand kind: ${command.kind}`);
    }
}

function drawPaletteBackground(context, canvas, plan, options) {
  const enabledPitchClasses = options.enabledPitchClasses ?? new Set();
  const staffColorForPitchClass = options.staffColorForPitchClass ?? (() => null);

  if (options.staffColors) {
    drawStaffLineColorGuides(context, canvas, plan, staffColorForPitchClass, enabledPitchClasses);
    drawLedgerLineColorGuides(context, canvas, plan, staffColorForPitchClass, enabledPitchClasses);
  } else {
    canvas.dataset.paletteStaffLineCount = "0";
    canvas.dataset.paletteLedgerLineCount = "0";
  }
}

function drawLedgerLineColorGuides(context, canvas, plan, colorForPitchClass, enabledPitchClasses) {
  let coloredLedgerLineCount = 0;
  for (const line of plan.ledgerLines ?? []) {
    const pitchClass = line.colorPitchClass;
    if (!Number.isInteger(pitchClass) || !enabledPitchClasses.has(pitchClass)) continue;
    const color = colorForPitchClass(pitchClass);
    if (!color) continue;
    context.save();
    context.globalAlpha = 1;
    context.strokeStyle = color;
    context.lineWidth = 1.6;
    context.beginPath();
    context.moveTo(line.start.x, line.start.y);
    context.lineTo(line.end.x, line.end.y);
    context.stroke();
    context.restore();
    coloredLedgerLineCount += 1;
  }
  canvas.dataset.paletteLedgerLineCount = String(coloredLedgerLineCount);
}

function drawSystemGuide(context, canvas, plan, noteIDs = new Set(), style) {
  canvas.dataset[style.dataset] = "";
  if (!noteIDs?.size) return;
  const anchor = (plan.noteAnchors ?? []).find((item) => noteIDs.has(item.noteID));
  if (!anchor) return;
  const system = (plan.systems ?? []).find((item) => item.index === anchor.systemIndex);
  if (!system) return;
  canvas.dataset[style.dataset] = `${anchor.noteID}@${system.index}`;
  const guideX = Math.max(system.frame.x + 3, anchor.frame.x - 5);

  context.save();
  context.globalAlpha = style.alpha;
  context.strokeStyle = style.color;
  context.lineWidth = style.lineWidth;
  if (style.dash) context.setLineDash(style.dash);
  context.beginPath();
  context.moveTo(guideX, system.frame.y);
  context.lineTo(guideX, system.frame.y + system.frame.height);
  context.stroke();
  context.restore();
}

function drawStaffLineColorGuides(context, canvas, plan, colorForPitchClass, enabledPitchClasses) {
  let coloredStaffLineCount = 0;
  for (const line of plan.staffLines ?? []) {
    const pitchClass = pitchClassNumber(line.pitchClass);
    if (pitchClass == null || !enabledPitchClasses.has(pitchClass)) continue;
    const color = colorForPitchClass(pitchClass);
    if (!color) continue;
    context.save();
    context.globalAlpha = 1;
    context.strokeStyle = color;
    context.lineWidth = 1.6;
    context.beginPath();
    context.moveTo(line.start.x, line.start.y);
    context.lineTo(line.end.x, line.end.y);
    context.stroke();
    context.restore();
    coloredStaffLineCount += 1;
  }
  canvas.dataset.paletteStaffLineCount = String(coloredStaffLineCount);
}

// ScorePainter exports the real SMuFL notehead draw command. Recolour that
// command instead of adding an ellipse overlay, preserving filled/open heads,
// glyph proportions, and the distinction between half and whole notes.
function noteheadCommandColors(plan, options) {
  const enabledPitchClasses = options.enabledPitchClasses ?? new Set();
  const colorForPitchClass = options.noteColorForPitchClass ?? (() => null);
  const result = new Map();

  if (!options.noteColors) {
    return result;
  }
  const anchors = (plan.noteAnchors ?? []).filter((anchor) => anchor.midiNumber != null);
  for (const [index, command] of plan.commands.entries()) {
    if (command.kind !== "drawText" || command.fontRole !== "smufl" || !command.point) continue;
    const anchor = anchors.find((item) => commandMatchesNotehead(command, item));
    if (!anchor) continue;
    const pitchClass = anchor.colorPitchClass ?? modulo(anchor.midiNumber, 12);
    if (!enabledPitchClasses.has(pitchClass)) continue;
    const color = colorForPitchClass(pitchClass);
    if (!color) continue;
    result.set(index, color);
  }
  return result;
}

function staffLineCommandIndexes(plan) {
  const indexedLines = new Set((plan.staffLines ?? []).map((line) => `${line.start.x}:${line.start.y}:${line.end.x}:${line.end.y}`));
  const result = new Set();
  for (const [index, command] of plan.commands.entries()) {
    if (command.kind !== "strokeLine" || !command.start || !command.end) continue;
    if (indexedLines.has(`${command.start.x}:${command.start.y}:${command.end.x}:${command.end.y}`)) result.add(index);
  }
  return result;
}

function ledgerLineCommandIndexes(plan) {
  const indexedLines = new Set((plan.ledgerLines ?? []).map((line) => `${line.start.x}:${line.start.y}:${line.end.x}:${line.end.y}`));
  const result = new Set();
  for (const [index, command] of plan.commands.entries()) {
    if (command.kind !== "strokeLine" || !command.start || !command.end) continue;
    if (indexedLines.has(`${command.start.x}:${command.start.y}:${command.end.x}:${command.end.y}`)) result.add(index);
  }
  return result;
}

function commandMatchesNotehead(command, anchor) {
  const frame = anchor.frame;
  const horizontalTolerance = Math.max(1.5, frame.width * 0.58);
  const verticalTolerance = Math.max(1.5, frame.height * 0.58);
  return Math.abs(command.point.x - anchor.center.x) <= horizontalTolerance
    && Math.abs(command.point.y - anchor.center.y) <= verticalTolerance;
}


function pitchClassNumber(pitchClass) {
  return { c: 0, d: 2, e: 4, f: 5, g: 7, a: 9, b: 11 }[pitchClass] ?? null;
}

function modulo(value, divisor) {
  return ((value % divisor) + divisor) % divisor;
}

function cssColor(color) {
  return `rgba(${Math.round(color.red * 255)}, ${Math.round(color.green * 255)}, ${Math.round(color.blue * 255)}, ${color.alpha})`;
}

function drawCenteredText(context, command) {
  context.save();
  context.translate(command.point.x, command.point.y);
  context.scale(command.mirroredHorizontally ? -1 : 1, command.mirroredVertically ? -1 : 1);
  context.font = cssFont(command);
  context.textAlign = "left";
  context.textBaseline = "alphabetic";

  const lines = String(command.text).split("\n");
  const lineHeight = command.fontSize;
  const firstLineOffset = -((lines.length - 1) * lineHeight) / 2;
  lines.forEach((line, index) => {
    const metrics = context.measureText(line);
    const left = metrics.actualBoundingBoxLeft ?? 0;
    const right = metrics.actualBoundingBoxRight ?? metrics.width;
    const ascent = metrics.actualBoundingBoxAscent ?? command.fontSize * 0.8;
    const descent = metrics.actualBoundingBoxDescent ?? command.fontSize * 0.2;

    // ScorePainter centers CoreText glyph-path bounds. Align the equivalent
    // browser glyph bounds instead of Canvas's em box.
    const x = (left - right) / 2;
    const y = (ascent - descent) / 2 + firstLineOffset + index * lineHeight;
    context.fillText(line, x, y);
  });
  context.restore();
}

function cssFont(command) {
  const size = command.fontSize || 12;
  switch (command.fontRole) {
    case "smufl": return `${size}px "${SMUFL_FONT_FAMILY}"`;
    case "serifItalic": return `italic ${size}px Georgia, "Times New Roman", serif`;
    case "serifBold": return `bold ${size}px Georgia, "Times New Roman", serif`;
    case "sansSerif": return `${size}px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif`;
    case "serif": return `${size}px Georgia, "Times New Roman", serif`;
    default:
      // Version 1 plan compatibility.
      if (command.fontName === "Bravura") return `${size}px "${SMUFL_FONT_FAMILY}"`;
      if (command.fontName === "Georgia-Italic") return `italic ${size}px Georgia, "Times New Roman", serif`;
      if (command.fontName === "TimesNewRomanPS-BoldMT") return `bold ${size}px Georgia, "Times New Roman", serif`;
      return `${size}px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif`;
  }
}
