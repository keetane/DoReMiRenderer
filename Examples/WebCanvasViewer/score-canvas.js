const SMUFL_FONT_FAMILY = "Bravura";
const SMUFL_PROBE = "\uE0A4";
const SMUFL_NOTEHEADS = new Set(["\uE0A2", "\uE0A3", "\uE0A4"]);
const SMUFL_ACCIDENTALS = new Set(["\uE260", "\uE261", "\uE262", "\uE263", "\uE264"]);
const COMPACT_HAND_SYSTEMS_PER_PAGE = 9;

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
  if (options.compactPrintPage) {
    drawCompactHandPrintCanvas(canvas, plan, options);
    return;
  }
  if (shouldUseCompactHandLayout(plan, options)) {
    drawCompactHandScoreCanvas(canvas, plan, options);
    return;
  }
  drawScoreCanvasStandard(canvas, plan, options);
}

function drawScoreCanvasStandard(canvas, plan, options = {}) {
  const pageFrame = options.pageFrame ?? plan.canvas;
  const pixelRatio = Math.max(1, window.devicePixelRatio || 1);
  const cssWidth = options.cssWidthOverride ?? (canvas.clientWidth || pageFrame.width);
  const layoutScale = cssWidth / pageFrame.width;
  const cssHeight = pageFrame.height * layoutScale;
  canvas.width = Math.round(cssWidth * pixelRatio);
  canvas.height = Math.round(cssHeight * pixelRatio);
  canvas.style.height = `${cssHeight}px`;

  const context = canvas.getContext("2d");
  const scale = pixelRatio * layoutScale;
  context.setTransform(scale, 0, 0, scale, -pageFrame.x * scale, -pageFrame.y * scale);
  context.clearRect(pageFrame.x, pageFrame.y, pageFrame.width, pageFrame.height);
  context.lineCap = "butt";
  context.lineJoin = "miter";
  canvas.dataset.pageIndex = String(options.pageIndex ?? 0);
  canvas.dataset.compactHandLayout = "false";
  canvas._scoreVerticalSegments = null;

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
  const compactBarlineBands = crossStaffBarlineCommandBands(plan, options.enabledStaffIDs, pageFrame);
  for (const index of staffCommandIndexes) drawCommand(context, plan.commands[index], cssColor(plan.commands[index].color));
  for (const index of ledgerCommandIndexes) drawCommand(context, plan.commands[index], cssColor(plan.commands[index].color));
  drawPaletteBackground(context, canvas, plan, options);
  const noteheadColors = noteheadCommandColors(plan, options);
  const accidentalColors = accidentalCommandColors(plan, options);
  canvas.dataset.paletteNoteCount = String(noteheadColors.size);
  canvas.dataset.paletteAccidentalCount = String(accidentalColors.size);

  for (const [commandIndex, command] of plan.commands.entries()) {
    if (backgroundCommandIndexes.has(commandIndex) || staffCommandIndexes.has(commandIndex) || ledgerCommandIndexes.has(commandIndex)) continue;
    const color = noteheadColors.get(commandIndex) ?? accidentalColors.get(commandIndex) ?? cssColor(command.color);
    const visibleBands = compactBarlineBands.get(commandIndex);
    if (visibleBands) drawVerticalCommandInBands(context, command, visibleBands, color);
    else drawCommand(context, command, color);
  }
  drawDisabledStaffMasks(context, canvas, plan, options.enabledStaffIDs, pageFrame);
  // The playback bar intentionally sits above barlines and note ink. A guide
  // behind notation can disappear entirely when an onset coincides with a
  // measure boundary, defeating its navigation purpose.
  drawSystemGuide(context, canvas, plan, options.currentNoteIDs, options.enabledStaffIDs, {
    color: "#23bdf0", lineWidth: 4, alpha: 0.94, dataset: "currentSystemGuide",
  });
  drawSystemGuide(context, canvas, plan, options.nextNoteIDs, options.enabledStaffIDs, {
    color: "#76d8f4", lineWidth: 2, alpha: 0.9, dash: [6, 5], dataset: "nextSystemGuide",
  });
}

function shouldUseCompactHandLayout(plan, options) {
  if (options.compactHandLayout === false || typeof document === "undefined") return false;
  const enabledStaffIDs = options.enabledStaffIDs;
  if (!enabledStaffIDs || !Array.isArray(plan.systems) || !Array.isArray(plan.staffLines)) return false;
  const availableStaffIDs = new Set((plan.noteAnchors ?? []).map((anchor) => String(anchor.staffID)));
  return availableStaffIDs.size > 1 && enabledStaffIDs.size < availableStaffIDs.size;
}

function drawCompactHandScoreCanvas(canvas, plan, options) {
  const pageFrame = options.pageFrame ?? plan.canvas;
  const cssWidth = canvas.clientWidth || pageFrame.width;
  const layoutScale = cssWidth / pageFrame.width;
  const pixelRatio = Math.max(1, window.devicePixelRatio || 1);
  const offscreen = document.createElement("canvas");
  drawScoreCanvasStandard(offscreen, plan, { ...options, cssWidthOverride: cssWidth, compactHandLayout: false });

  const segments = compactHandSegments(plan, pageFrame, options.enabledStaffIDs);
  if (segments.length === 0) {
    drawScoreCanvasStandard(canvas, plan, options);
    return;
  }

  const bottomPadding = Math.max(24, segments[0].staffSpace * 5);
  const logicalHeight = Math.max(100, segments.at(-1).destinationBottom - pageFrame.y + bottomPadding);
  const physicalScale = pixelRatio * layoutScale;
  canvas.width = Math.round(cssWidth * pixelRatio);
  canvas.height = Math.round(logicalHeight * physicalScale);
  canvas.style.height = `${logicalHeight * layoutScale}px`;
  canvas.dataset.pageIndex = String(options.pageIndex ?? 0);
  canvas.dataset.compactHandLayout = "true";
  canvas._scoreVerticalSegments = segments;
  for (const key of ["paletteNoteCount", "paletteAccidentalCount", "paletteStaffLineCount", "paletteLedgerLineCount", "hiddenStaffCount", "currentSystemGuide", "nextSystemGuide"]) {
    if (offscreen.dataset[key] != null) canvas.dataset[key] = offscreen.dataset[key];
  }

  const context = canvas.getContext("2d");
  context.setTransform(1, 0, 0, 1, 0, 0);
  context.fillStyle = "#fff";
  context.fillRect(0, 0, canvas.width, canvas.height);
  const destinationStart = segments[0].destinationTop;
  const headerHeight = Math.max(0, destinationStart - pageFrame.y);
  if (headerHeight > 0) {
    context.drawImage(
      offscreen,
      0, 0, offscreen.width, headerHeight * physicalScale,
      0, 0, canvas.width, headerHeight * physicalScale
    );
  }
  for (const segment of segments) {
    const sourceY = (segment.sourceTop - pageFrame.y) * physicalScale;
    const sourceHeight = (segment.sourceBottom - segment.sourceTop) * physicalScale;
    const destinationY = (segment.destinationTop - pageFrame.y) * physicalScale;
    context.drawImage(
      offscreen,
      0, sourceY, offscreen.width, sourceHeight,
      0, destinationY, canvas.width, sourceHeight
    );
  }
}

function drawCompactHandPrintCanvas(canvas, plan, options) {
  const printPage = options.compactPrintPage;
  const pageFrame = printPage.frame;
  const cssWidth = canvas.clientWidth || pageFrame.width;
  const layoutScale = cssWidth / pageFrame.width;
  const pixelRatio = Math.max(1, window.devicePixelRatio || 1);
  const physicalScale = pixelRatio * layoutScale;
  canvas.width = Math.round(cssWidth * pixelRatio);
  canvas.height = Math.round(pageFrame.height * physicalScale);
  canvas.style.height = `${pageFrame.height * layoutScale}px`;
  canvas.dataset.pageIndex = String(options.pageIndex ?? 0);
  canvas.dataset.compactHandLayout = "print";
  canvas._scoreVerticalSegments = printPage.segments.map((segment) => ({
    ...segment,
    destinationBottom: segment.destinationTop + (segment.sourceBottom - segment.sourceTop),
  }));

  const context = canvas.getContext("2d");
  context.setTransform(1, 0, 0, 1, 0, 0);
  context.fillStyle = "#fff";
  context.fillRect(0, 0, canvas.width, canvas.height);

  const sourceCanvases = new Map();
  const sourceCanvas = (sourcePage) => {
    let offscreen = sourceCanvases.get(sourcePage.index);
    if (offscreen) return offscreen;
    offscreen = document.createElement("canvas");
    drawScoreCanvasStandard(offscreen, plan, {
      ...options,
      pageFrame: sourcePage.frame,
      cssWidthOverride: cssWidth,
      compactHandLayout: false,
      compactPrintPage: null,
    });
    sourceCanvases.set(sourcePage.index, offscreen);
    return offscreen;
  };

  if (printPage.header) {
    const offscreen = sourceCanvas(printPage.header.sourcePage);
    const sourceY = (printPage.header.sourceTop - printPage.header.sourcePage.frame.y) * physicalScale;
    const sourceHeight = (printPage.header.sourceBottom - printPage.header.sourceTop) * physicalScale;
    context.drawImage(offscreen, 0, sourceY, offscreen.width, sourceHeight, 0, 0, canvas.width, sourceHeight);
  }

  for (const segment of printPage.segments) {
    const offscreen = sourceCanvas(segment.sourcePage);
    const sourceY = (segment.sourceTop - segment.sourcePage.frame.y) * physicalScale;
    const sourceHeight = (segment.sourceBottom - segment.sourceTop) * physicalScale;
    const destinationY = segment.destinationTop * physicalScale;
    context.drawImage(
      offscreen,
      0, sourceY, offscreen.width, sourceHeight,
      0, destinationY, canvas.width, sourceHeight
    );
  }
}

export function compactHandPrintPages(plan, enabledStaffIDs) {
  const sourcePages = Array.isArray(plan?.pages) && plan.pages.length > 0
    ? plan.pages
    : [{ index: 0, frame: plan.canvas, contentFrame: plan.canvas, systemIndices: (plan.systems ?? []).map((system) => system.index) }];
  if (!enabledStaffIDs || sourcePages.length === 0) return sourcePages;

  const firstSourcePage = sourcePages[0];
  const pageWidth = firstSourcePage.frame.width;
  const pageHeight = firstSourcePage.frame.height;
  const topMargin = Math.max(18, firstSourcePage.contentFrame?.y - firstSourcePage.frame.y || 0);
  const bottomMargin = Math.max(18, pageHeight - ((firstSourcePage.contentFrame?.y - firstSourcePage.frame.y || 0) + (firstSourcePage.contentFrame?.height || pageHeight)));
  const entries = [];

  for (const system of [...(plan.systems ?? [])].sort((left, right) => left.frame.y - right.frame.y)) {
    const sourcePage = sourcePages.find((page) => page.systemIndices?.includes(system.index))
      ?? sourcePages.find((page) => system.frame.y >= page.frame.y && system.frame.y < page.frame.y + page.frame.height);
    if (!sourcePage) continue;
    const bands = staffBandsForSystem(plan, system);
    const bounds = bands.map((band) => compactHandBandBounds(plan, system, band));
    for (let index = 0; index < bands.length; index += 1) {
      const band = bands[index];
      if (!enabledStaffIDs.has(band.staffID)) continue;
      entries.push({
        system,
        band,
        sourcePage,
        sourceTop: Math.max(sourcePage.frame.y, bounds[index].top),
        sourceBottom: Math.min(sourcePage.frame.y + sourcePage.frame.height, bounds[index].bottom),
        sourceStaffTop: band.lines[0].start.y,
        firstBandTop: bounds[0]?.top ?? band.top,
      });
    }
  }
  if (entries.length === 0) return sourcePages;

  const firstDestinationTop = Math.max(topMargin, entries[0].firstBandTop - firstSourcePage.frame.y);
  const header = {
    sourcePage: firstSourcePage,
    sourceTop: firstSourcePage.frame.y,
    sourceBottom: firstSourcePage.frame.y + firstDestinationTop,
  };
  return paginateCompactHandEntries(entries, {
    pageWidth,
    pageHeight,
    topMargin,
    bottomMargin,
    firstDestinationTop,
    header,
  });
}

function paginateCompactHandEntries(entries, options) {
  const pages = [];
  let cursor = 0;
  while (cursor < entries.length) {
    const page = makeCompactPrintPage(pages.length, options.pageWidth, options.pageHeight);
    if (page.index === 0) page.header = options.header;
    const top = page.index === 0 ? options.firstDestinationTop : options.topMargin;
    let count = Math.min(COMPACT_HAND_SYSTEMS_PER_PAGE, entries.length - cursor);
    while (count > 1 && !compactBatchFits(entries.slice(cursor, cursor + count), top, options.pageHeight - options.bottomMargin)) count -= 1;
    const batch = entries.slice(cursor, cursor + count);
    const layout = compactBatchLayout(batch, top, options.pageHeight - options.bottomMargin);
    for (let index = 0; index < batch.length; index += 1) {
      const entry = batch[index];
      const destinationTop = layout.firstStaffTop + index * layout.staffPitch - compactEntryTopOverhang(entry);
      page.segments.push({ ...entry, destinationTop });
      page.systemIndices.push(entry.system.index);
    }
    pages.push(page);
    cursor += count;
  }
  return pages;
}

function compactEntryHeights(entries) {
  return entries.reduce((sum, entry) => sum + entry.sourceBottom - entry.sourceTop, 0);
}

function compactBatchFits(entries, top, bottom) {
  if (entries.length <= 1) return compactEntryHeights(entries) <= bottom - top;
  const availablePitch = compactAvailableStaffPitch(entries, top, bottom);
  return availablePitch >= compactMinimumStaffPitch(entries);
}

function compactBatchLayout(entries, top, bottom) {
  if (entries.length <= 1) {
    return { firstStaffTop: top + compactEntryTopOverhang(entries[0]), staffPitch: 0 };
  }
  const firstStaffTop = top + compactEntryTopOverhang(entries[0]);
  const fittedPitch = compactAvailableStaffPitch(entries, top, bottom);
  const preferredPitch = compactPreferredStaffPitch(entries);
  const staffSpace = Math.min(...entries.map((entry) => entry.band.staffSpace));
  const maximumPitch = preferredPitch + Math.max(8, staffSpace * 2.5);
  return {
    firstStaffTop,
    staffPitch: Math.max(compactMinimumStaffPitch(entries), Math.min(fittedPitch, maximumPitch)),
  };
}

function compactAvailableStaffPitch(entries, top, bottom) {
  if (entries.length <= 1) return 0;
  const firstStaffTop = top + compactEntryTopOverhang(entries[0]);
  const lastStaffTop = bottom - compactEntryBottomOverhang(entries.at(-1));
  return Math.max(0, (lastStaffTop - firstStaffTop) / (entries.length - 1));
}

function compactMinimumStaffPitch(entries) {
  let pitch = 0;
  for (let index = 1; index < entries.length; index += 1) {
    const previous = entries[index - 1];
    const current = entries[index];
    const clearance = Math.max(4, Math.min(previous.band.staffSpace, current.band.staffSpace));
    pitch = Math.max(pitch, compactEntryBottomOverhang(previous) + compactEntryTopOverhang(current) + clearance);
  }
  return pitch;
}

function compactPreferredStaffPitch(entries) {
  let pitch = 0;
  for (let index = 1; index < entries.length; index += 1) {
    const previous = entries[index - 1];
    const current = entries[index];
    const clearance = compactHandSystemGap(current.band.staffSpace, previous.system.index === current.system.index);
    pitch = Math.max(pitch, compactEntryBottomOverhang(previous) + compactEntryTopOverhang(current) + clearance);
  }
  return pitch;
}

function compactEntryTopOverhang(entry) {
  return entry.sourceStaffTop - entry.sourceTop;
}

function compactEntryBottomOverhang(entry) {
  return entry.sourceBottom - entry.sourceStaffTop;
}

function makeCompactPrintPage(index, width, height) {
  return {
    index,
    frame: { x: 0, y: 0, width, height },
    contentFrame: { x: 0, y: 0, width, height },
    systemIndices: [],
    segments: [],
    header: null,
  };
}

function compactHandSegments(plan, pageFrame, enabledStaffIDs) {
  const systems = (plan.systems ?? [])
    .filter((system) => system.frame.y >= pageFrame.y - 0.01 && system.frame.y < pageFrame.y + pageFrame.height - 0.01)
    .sort((left, right) => left.frame.y - right.frame.y);
  const entries = systems.flatMap((system) => {
    const bands = staffBandsForSystem(plan, system);
    const compactBounds = bands.map((band) => compactHandBandBounds(plan, system, band));
    return bands.flatMap((band, index) => (
      enabledStaffIDs.has(band.staffID)
        ? [{ system, band, bounds: compactBounds[index], firstBandTop: compactBounds[0]?.top ?? band.top }]
        : []
    ));
  });
  if (entries.length === 0) return [];

  const firstTop = Math.max(pageFrame.y, entries[0].firstBandTop);
  let nextTop = firstTop;
  let previousSystemIndex = null;
  return entries.map(({ system, band, bounds }) => {
    if (previousSystemIndex != null) {
      nextTop += compactHandSystemGap(band.staffSpace, previousSystemIndex === system.index);
    }
    const height = bounds.bottom - bounds.top;
    const segment = {
      sourceTop: Math.max(pageFrame.y, bounds.top),
      sourceBottom: Math.min(pageFrame.y + pageFrame.height, bounds.bottom),
      destinationTop: nextTop,
      destinationBottom: nextTop + height,
      staffID: band.staffID,
      systemIndex: system.index,
      staffSpace: band.staffSpace,
    };
    segment.destinationBottom = segment.destinationTop + (segment.sourceBottom - segment.sourceTop);
    nextTop = segment.destinationBottom;
    previousSystemIndex = system.index;
    return segment;
  });
}

function compactHandBandBounds(plan, system, band, margin = null) {
  const staffTop = band.lines[0].start.y;
  const staffBottom = band.lines.at(-1).start.y;
  const bands = staffBandsForSystem(plan, system);
  const noteFrames = (plan.noteAnchors ?? [])
    .filter((anchor) => anchor.systemIndex === system.index && String(anchor.staffID) === band.staffID)
    .map((anchor) => anchor.frame)
    .filter(Boolean);
  const commandFrames = notationCommandBoundsForBand(plan, system, band, bands);
  const inkFrames = [...noteFrames, ...commandFrames];
  const inkTop = Math.min(staffTop, ...inkFrames.map((frame) => frame.y));
  const inkBottom = Math.max(staffBottom, ...inkFrames.map((frame) => frame.y + frame.height));
  const notationClearance = margin ?? Math.max(2, band.staffSpace * 0.6);
  return {
    top: inkTop - notationClearance,
    bottom: inkBottom + notationClearance,
  };
}

function notationCommandBoundsForBand(plan, system, band, bands) {
  const verticalLimit = Math.max(48, band.staffSpace * 12);
  const systemTop = system.frame.y - band.staffSpace * 10;
  const systemBottom = system.frame.y + system.frame.height + band.staffSpace * 10;
  return (plan.commands ?? []).flatMap((command) => {
    const bounds = scoreCommandBounds(command);
    const isStructuralVerticalLine = command.kind === "strokeLine"
      && command.start && command.end
      && Math.abs(command.start.x - command.end.x) <= 0.01
      && bounds?.height > band.staffSpace * 6;
    if (!bounds || bounds.height > verticalLimit
      || isStructuralVerticalLine
      || bounds.x + bounds.width < system.frame.x - 1
      || bounds.x > system.frame.x + system.frame.width + 1
      || bounds.y + bounds.height < systemTop
      || bounds.y > systemBottom) return [];
    const commandCenter = bounds.y + bounds.height / 2;
    const nearest = bands.reduce((result, candidate) => {
      const distance = Math.abs(staffCenter(candidate) - commandCenter);
      return distance < result.distance ? { band: candidate, distance } : result;
    }, { band: null, distance: Infinity });
    if (nearest.distance > band.staffSpace * 8) return [];
    return nearest.band?.staffID === band.staffID ? [bounds] : [];
  });
}

function staffCenter(band) {
  return (band.lines[0].start.y + band.lines.at(-1).start.y) / 2;
}

function scoreCommandBounds(command) {
  if (command.rect) return { ...command.rect };
  if (command.kind === "strokeLine" && command.start && command.end) {
    return boundsForPoints([command.start, command.end], command.lineWidth || 1);
  }
  if (command.kind === "strokeQuadraticCurve" && command.start && command.control && command.end) {
    return boundsForPoints([command.start, command.control, command.end], command.lineWidth || 1);
  }
  if (command.kind === "drawText" && command.point) {
    const size = command.fontSize || 12;
    const lines = String(command.text ?? "").split("\n");
    const width = Math.max(size * 0.8, ...lines.map((line) => line.length * size * 0.7));
    const height = Math.max(size, lines.length * size);
    return { x: command.point.x - width / 2, y: command.point.y - height / 2, width, height };
  }
  return null;
}

function boundsForPoints(points, lineWidth) {
  const inset = Math.max(0.5, lineWidth / 2);
  const xs = points.map((point) => point.x);
  const ys = points.map((point) => point.y);
  const left = Math.min(...xs) - inset;
  const top = Math.min(...ys) - inset;
  return {
    x: left,
    y: top,
    width: Math.max(...xs) + inset - left,
    height: Math.max(...ys) + inset - top,
  };
}

export function compactHandSystemGap(staffSpace, sameSystem = false) {
  return Math.max(10, staffSpace * (sameSystem ? 2 : 3));
}

export function sourceYForDisplayY(canvas, displayY) {
  const segment = canvas?._scoreVerticalSegments?.find((item) => (
    displayY >= item.destinationTop && displayY <= item.destinationBottom
  ));
  return segment ? segment.sourceTop + displayY - segment.destinationTop : displayY;
}

export function displayYForSourceY(canvas, sourceY) {
  const segment = canvas?._scoreVerticalSegments?.find((item) => (
    sourceY >= item.sourceTop && sourceY <= item.sourceBottom
  ));
  return segment ? segment.destinationTop + sourceY - segment.sourceTop : sourceY;
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

function drawSystemGuide(context, canvas, plan, noteIDs = new Set(), enabledStaffIDs, style) {
  canvas.dataset[style.dataset] = "";
  if (!noteIDs?.size) return;
  const anchor = (plan.noteAnchors ?? []).find((item) => noteIDs.has(item.noteID));
  if (!anchor) return;
  const system = (plan.systems ?? []).find((item) => item.index === anchor.systemIndex);
  if (!system) return;
  canvas.dataset[style.dataset] = `${anchor.noteID}@${system.index}`;
  const guideX = Math.max(system.frame.x + 3, anchor.frame.x - 5);
  const bands = staffBandsForSystem(plan, system);
  const hasHiddenStaff = enabledStaffIDs && bands.some((band) => !enabledStaffIDs.has(band.staffID));
  const guideBand = hasHiddenStaff ? bands.find((band) => band.staffID === String(anchor.staffID)) : null;
  const guideTop = guideBand
    ? guideBand.lines[0].start.y - guideBand.staffSpace * 2
    : system.frame.y;
  const guideBottom = guideBand
    ? guideBand.lines.at(-1).start.y + guideBand.staffSpace * 2
    : system.frame.y + system.frame.height;

  context.save();
  context.globalAlpha = style.alpha;
  context.strokeStyle = style.color;
  context.lineWidth = style.lineWidth;
  if (style.dash) context.setLineDash(style.dash);
  context.beginPath();
  context.moveTo(guideX, guideTop);
  context.lineTo(guideX, guideBottom);
  context.stroke();
  context.restore();
}

function drawDisabledStaffMasks(context, canvas, plan, enabledStaffIDs, pageFrame = plan.canvas) {
  canvas.dataset.hiddenStaffCount = "0";
  if (!enabledStaffIDs || !Array.isArray(plan.systems) || !Array.isArray(plan.staffLines)) return;
  let hiddenCount = 0;
  const pageBottom = pageFrame.y + pageFrame.height;
  for (const system of plan.systems.filter((item) => (
    item.frame.y + item.frame.height >= pageFrame.y && item.frame.y <= pageBottom
  ))) {
    const bands = staffBandsForSystem(plan, system);
    const enabledBounds = bands
      .filter((band) => enabledStaffIDs.has(band.staffID))
      .map((band) => ({ band, bounds: compactHandBandBounds(plan, system, band, 0) }));
    for (const band of bands) {
      if (enabledStaffIDs.has(band.staffID)) continue;
      const bounds = compactHandBandBounds(plan, system, band, 0);
      const center = staffCenter(band);
      for (const enabled of enabledBounds) {
        const enabledCenter = staffCenter(enabled.band);
        if (center > enabledCenter) bounds.top = Math.max(bounds.top, enabled.bounds.bottom);
        if (center < enabledCenter) bounds.bottom = Math.min(bounds.bottom, enabled.bounds.top);
      }
      context.save();
      context.fillStyle = "#fff";
      context.fillRect(system.frame.x - 2, bounds.top, system.frame.width + 4, Math.max(0, bounds.bottom - bounds.top));
      context.restore();
      hiddenCount += 1;
    }
    if (bands.some((band) => !enabledStaffIDs.has(band.staffID))) {
      replaceGrandStaffBraceWithVisibleStaffBarlines(context, system, bands, enabledStaffIDs);
    }
  }
  canvas.dataset.hiddenStaffCount = String(hiddenCount);
}

function crossStaffBarlineCommandBands(plan, enabledStaffIDs, pageFrame) {
  const result = new Map();
  if (!enabledStaffIDs) return result;
  const pageBottom = pageFrame.y + pageFrame.height;
  for (const system of (plan.systems ?? []).filter((item) => (
    item.frame.y + item.frame.height >= pageFrame.y && item.frame.y <= pageBottom
  ))) {
    const bands = staffBandsForSystem(plan, system);
    if (!bands.some((band) => !enabledStaffIDs.has(band.staffID))) continue;
    for (const [index, command] of (plan.commands ?? []).entries()) {
      if (command.kind !== "strokeLine" || !command.start || !command.end
        || Math.abs(command.start.x - command.end.x) > 0.01
        || command.start.x < system.frame.x - 1
        || command.start.x > system.frame.x + system.frame.width + 1) continue;
      const top = Math.min(command.start.y, command.end.y);
      const bottom = Math.max(command.start.y, command.end.y);
      const connectsStaffGap = bands.some((band, bandIndex) => {
        const nextBand = bands[bandIndex + 1];
        if (!nextBand) return false;
        return Math.abs(top - band.lines.at(-1).start.y) <= 0.01
          && Math.abs(bottom - nextBand.lines[0].start.y) <= 0.01;
      });
      if (connectsStaffGap) {
        result.set(index, []);
        continue;
      }
      const crossedBands = bands.filter((band) => (
        top <= band.lines[0].start.y + 0.01 && bottom >= band.lines.at(-1).start.y - 0.01
      ));
      if (crossedBands.length >= 2) {
        result.set(index, bands.filter((band) => enabledStaffIDs.has(band.staffID)));
      }
    }
  }
  return result;
}

function drawVerticalCommandInBands(context, command, bands, color) {
  context.save();
  context.strokeStyle = color;
  context.lineWidth = command.lineWidth || 1;
  context.lineCap = "butt";
  for (const band of bands) {
    context.beginPath();
    context.moveTo(command.start.x, band.lines[0].start.y);
    context.lineTo(command.end.x, band.lines.at(-1).start.y);
    context.stroke();
  }
  context.restore();
}

function replaceGrandStaffBraceWithVisibleStaffBarlines(context, system, bands, enabledStaffIDs) {
  const lineStartX = Math.min(...bands.flatMap((band) => band.lines.map((line) => line.start.x)));
  const staffSpace = bands[0]?.staffSpace ?? 5;
  context.save();
  context.fillStyle = "#fff";
  context.fillRect(
    lineStartX - Math.max(14, staffSpace * 3),
    system.frame.y - staffSpace,
    Math.max(14, staffSpace * 3),
    system.frame.height + staffSpace * 2
  );
  context.strokeStyle = "#000";
  context.lineWidth = 1;
  for (const band of bands) {
    if (!enabledStaffIDs.has(band.staffID)) continue;
    context.beginPath();
    context.moveTo(lineStartX, band.lines[0].start.y);
    context.lineTo(lineStartX, band.lines.at(-1).start.y);
    context.stroke();
  }
  context.restore();
}

function staffBandsForSystem(plan, system) {
  const lineYs = [...new Set((plan.staffLines ?? [])
    .filter((line) => line.start.y >= system.frame.y - 0.01 && line.start.y <= system.frame.y + system.frame.height + 0.01)
    .map((line) => Number(line.start.y.toFixed(3))))]
    .sort((left, right) => left - right);
  const staffGroups = [];
  for (let index = 0; index + 4 < lineYs.length; index += 5) {
    const ys = lineYs.slice(index, index + 5);
    const lines = ys.map((y) => (plan.staffLines ?? []).find((line) => Math.abs(line.start.y - y) < 0.01));
    if (lines.some((line) => !line)) continue;
    staffGroups.push({ center: ys.reduce((sum, value) => sum + value, 0) / ys.length, lines });
  }
  if (staffGroups.length === 0) return [];
  const staffSpace = staffGroups[0].lines.length > 1
    ? staffGroups[0].lines[1].start.y - staffGroups[0].lines[0].start.y
    : 5;
  const outerPadding = Math.max(24, staffSpace * 8);
  return staffGroups.map((group, index) => ({
    staffID: String(index + 1),
    lines: group.lines,
    staffSpace,
    top: index === 0 ? system.frame.y - outerPadding : (staffGroups[index - 1].center + group.center) / 2,
    bottom: index === staffGroups.length - 1
      ? system.frame.y + system.frame.height + outerPadding
      : (group.center + staffGroups[index + 1].center) / 2,
  }));
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
  const enabledStaffIDs = options.enabledStaffIDs;
  const colorForPitchClass = options.noteColorForPitchClass ?? (() => null);
  const result = new Map();

  if (!options.noteColors) {
    return result;
  }
  const anchors = (plan.noteAnchors ?? []).filter((anchor) => anchor.midiNumber != null
    && (!enabledStaffIDs || enabledStaffIDs.has(String(anchor.staffID))));
  for (const [index, command] of plan.commands.entries()) {
    if (command.kind !== "drawText" || command.fontRole !== "smufl" || !command.point
      || !SMUFL_NOTEHEADS.has(command.text)) continue;
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

function accidentalCommandColors(plan, options) {
  const enabledPitchClasses = options.enabledPitchClasses ?? new Set();
  const enabledStaffIDs = options.enabledStaffIDs;
  const colorForPitchClass = options.noteColorForPitchClass ?? (() => null);
  const result = new Map();

  if (!options.noteColors) return result;
  const accidentals = plan.accidentals ?? [];
  for (const [index, command] of plan.commands.entries()) {
    if (command.kind !== "drawText" || command.fontRole !== "smufl" || !command.point
      || !SMUFL_ACCIDENTALS.has(command.text)) continue;
    const accidental = accidentals.find((item) => pointsMatch(command.point, item.point));
    const anchor = accidental ? (plan.noteAnchors ?? []).find((item) => item.noteID === accidental.noteID) : null;
    if (enabledStaffIDs && (!anchor || !enabledStaffIDs.has(String(anchor.staffID)))) continue;
    const pitchClass = accidental?.colorPitchClass;
    if (!Number.isInteger(pitchClass) || !enabledPitchClasses.has(pitchClass)) continue;
    const color = colorForPitchClass(pitchClass);
    if (color) result.set(index, color);
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

function pointsMatch(lhs, rhs) {
  return rhs && Math.abs(lhs.x - rhs.x) < 0.01 && Math.abs(lhs.y - rhs.y) < 0.01;
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
