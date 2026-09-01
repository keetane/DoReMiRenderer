import { drawScoreCanvas, ensureSMuFLFont } from "./score-canvas.js?v=palette-14";

// Same defaultEducationalPalette and basic pitch-class grouping as iOS.
const PITCHES = [
  ["C", [0, 1], "#e6191a"], ["D", [2, 3], "#ff8c00"], ["E", [4], "#f2d10d"],
  ["F", [5, 6], "#1aa633"], ["G", [7, 8], "#1a59f2"], ["A", [9, 10], "#5933cc"], ["B", [11], "#bf33bf"],
];
const COLORS = new Map(PITCHES.flatMap(([_, classes, color]) => classes.map((pitchClass) => [pitchClass, color])));
const WHITE = new Set([0, 2, 4, 5, 7, 9, 11]);
const allPitchClasses = () => new Set(Array.from({ length: 12 }, (_, index) => index));
const usesLoopbackCompanion = ["127.0.0.1", "localhost", "::1"].includes(location.hostname);
const loopbackCompanionOrigins = ["http://127.0.0.1:8767", "http://127.0.0.1:8765"];
const state = {
  source: null, plan: null, sourceName: "score-web.json", transpose: 0, scoreZoom: 1,
  noteColors: true, staffColors: false, keyboardColors: true, keyboardColorPosition: "top", nextNoteGuide: true, keyboardVisible: true, enabled: allPitchClasses(),
  selectedNoteID: null, selectedMidi: null, currentIndex: 0, activeMIDIs: new Set(), nextMIDIs: new Set(), playing: false,
  context: null, nodes: new Set(), nextScheduledIndex: 0, contextStart: 0, timelineStart: 0, baseTempoBPM: 120, tempoBPM: 120, animationFrame: null,
  lastFollowedSystemIndex: null, pageCanvases: new Map(), transposeRequestID: 0, printing: false, samples: null, activeDrawer: null,
  companionOrigin: usesLoopbackCompanion ? location.origin : null,
  hasAppliedInitialFitWidth: false,
};
const $ = (selector) => document.querySelector(selector);
const pageStack = $("#page-stack");
const controls = {
  status: $("#status"), palette: $("#palette"), paletteButton: $("#palette-button"), drawer: $("#right-drawer"), drawerBackdrop: $("#drawer-backdrop"), drawerClose: $("#drawer-close"), drawerTitle: $("#drawer-title"), noteColors: $("#note-colors"),
  keyboard: $("#keyboard-button"), dock: $("#keyboard-dock"), file: $("#file-input"), sampleLibraryButton: $("#sample-library-button"), sampleLibrary: $("#sample-library"), sampleList: $("#sample-list"), print: $("#print-button"), sourceName: $("#score-name"),
  sourceMeta: $("#score-meta"), selected: $("#selected-note"), current: $("#current-note"), transpose: $("#transpose-select"), originalScale: $("#original-scale-button"), keyboardElement: $("#keyboard"),
  staffColors: $("#staff-colors"), keyboardColors: $("#keyboard-colors"), keyboardColorPosition: $("#keyboard-color-position"), nextNoteGuide: $("#next-note-guide"), allPitches: $("#all-pitches"),
  tempo: $("#tempo-input"), zoom: $("#zoom-input"), fitWidth: $("#fit-width-button"), reset: $("#reset-button"), previous: $("#previous-button"), play: $("#play-button"),
  stop: $("#stop-button"), next: $("#next-button"), jump: $("#jump-button"), measure: $("#measure-input"), measureStatus: $("#measure-status"),
};

buildPalette();
buildTranspose();
buildKeyboard();
configureStaticHosting();
controls.paletteButton.addEventListener("click", () => togglePalette());
controls.drawerClose.addEventListener("click", closeDrawer);
controls.drawerBackdrop.addEventListener("click", closeDrawer);
controls.noteColors.addEventListener("click", () => { state.noteColors = !state.noteColors; sync(); redraw(); });
controls.keyboard.addEventListener("click", () => { state.keyboardVisible = !state.keyboardVisible; sync(); });
$("#palette-reset").addEventListener("click", () => { state.enabled = allPitchClasses(); state.noteColors = true; state.staffColors = false; state.keyboardColors = true; state.keyboardColorPosition = "top"; state.nextNoteGuide = true; sync(); redraw(); });
controls.staffColors.addEventListener("click", () => { state.staffColors = !state.staffColors; sync(); redraw(); });
controls.keyboardColors.addEventListener("click", () => { state.keyboardColors = !state.keyboardColors; sync(); updateKeyboard(); });
controls.keyboardColorPosition.addEventListener("click", () => { state.keyboardColorPosition = state.keyboardColorPosition === "top" ? "bottom" : "top"; sync(); updateKeyboard(); });
controls.nextNoteGuide.addEventListener("click", () => { state.nextNoteGuide = !state.nextNoteGuide; sync(); redraw(); });
controls.allPitches.addEventListener("click", () => { state.enabled = state.enabled.size === 12 ? new Set() : allPitchClasses(); sync(); redraw(); });
controls.file.addEventListener("change", async (event) => { const file = event.target.files?.[0]; if (!file) return; try { await loadFile(file); } catch (error) { fail(`スコアを開けません: ${error.message}`); } finally { controls.file.value = ""; } });
controls.sampleLibraryButton.addEventListener("click", () => { void toggleSampleLibrary(); });
controls.print.addEventListener("click", printScore);
controls.transpose.addEventListener("change", () => { state.transpose = Number(controls.transpose.value); void applyTranspose(); });
controls.originalScale.addEventListener("click", () => { state.transpose = 0; void applyTranspose(); });
controls.tempo.addEventListener("change", updateTempoFromInput);
controls.tempo.addEventListener("keydown", (event) => { if (event.key === "Enter") { event.preventDefault(); updateTempoFromInput(); controls.tempo.blur(); } });
controls.zoom.addEventListener("change", updateZoomFromInput);
controls.zoom.addEventListener("keydown", (event) => { if (event.key === "Enter") { event.preventDefault(); updateZoomFromInput(); controls.zoom.blur(); } });
controls.fitWidth.addEventListener("click", fitScoreToWidth);
controls.reset.addEventListener("click", () => setEvent(0, true));
controls.previous.addEventListener("click", () => move(-1));
controls.next.addEventListener("click", () => move(1));
controls.jump.addEventListener("click", jumpToMeasure);
controls.measure.addEventListener("keydown", (event) => { if (event.key === "Enter") jumpToMeasure(); });
controls.play.addEventListener("click", play);
controls.stop.addEventListener("click", stop);
addEventListener("resize", () => requestAnimationFrame(redraw));
addEventListener("keydown", (event) => { if (event.key === "Escape") closeDrawer(); });
addEventListener("afterprint", finishPrint);

try {
  const [response] = await Promise.all([fetch("./score-web.json"), ensureSMuFLFont()]);
  if (!response.ok) throw new Error(`score-web.json (${response.status})`);
  load(await response.json(), "score-web.json");
} catch (error) { fail(`Score viewer could not start: ${error.message}`); }

function load(document, sourceName) {
  stop();
  const source = normalize(document);
  validate(source.primaryPlan);
  state.source = source;
  state.sourceName = sourceName;
  state.transpose = 0;
  // scoreZoom is a viewer preference and intentionally survives score changes.
  state.baseTempoBPM = sourceTempoBPM(source.events);
  state.tempoBPM = state.baseTempoBPM;
  state.pageCanvases.clear();
  pageStack.replaceChildren();
  state.currentIndex = 0;
  state.lastFollowedSystemIndex = null;
  state.selectedNoteID = null;
  state.selectedMidi = null;
  state.nextMIDIs = new Set();
  controls.sourceName.textContent = sourceName.replace(/\.json$/i, "");
  controls.sourceMeta.textContent = `${source.primaryPlan.noteAnchors.length} notes`;
  controls.status.hidden = true;
  buildTranspose();
  void applyTranspose(true).then(() => {
    if (state.hasAppliedInitialFitWidth) return;
    requestAnimationFrame(() => {
      if (state.hasAppliedInitialFitWidth || !fitScoreToWidth()) return;
      state.hasAppliedInitialFitWidth = true;
    });
  });
}

async function loadFile(file) {
  const name = file.name.toLowerCase();
  if (name.endsWith(".json")) {
    load(JSON.parse(await file.text()), file.name);
    return;
  }
  if (!/\.(mxl|musicxml|xml)$/.test(name)) {
    throw new Error(".mxl、.musicxml、.xml、またはWeb Render Plan JSONを選択してください。");
  }
  if (!state.companionOrigin) throw new Error("MusicXML/MXLの変換用ローカル companion が見つかりません。プロジェクトで `cd Examples/WebCanvasViewer && python3 server.py --port 8767` を実行してから、もう一度開いてください。");
  if (file.size > 50 * 1024 * 1024) throw new Error("50 MB以下のMusicXML/MXLファイルを選択してください。");
  info("MusicXMLをSDKでレイアウトしています…");
  // Send a fixed byte body instead of relying on the browser's File-stream
  // transport. The loopback importer deliberately validates Content-Length,
  // and this keeps .mxl uploads reliable across browser implementations.
  const payload = await file.arrayBuffer();
  const response = await fetch(companionAPI("/api/render"), {
    method: "POST",
    headers: { "Content-Type": file.type || "application/octet-stream", "X-DoReMi-File-Name": encodeURIComponent(file.name) },
    body: payload,
  });
  if (!response.ok) {
    const detail = await responseDetail(response);
    throw new Error(detail || "MusicXML/MXL変換サーバーに接続できません。Examples/WebCanvasViewer/server.pyで起動してください。");
  }
  load(await response.json(), file.name);
}

async function toggleSampleLibrary() {
  const opening = state.activeDrawer !== "samples";
  setActiveDrawer(opening ? "samples" : null);
  if (!opening || state.samples) return;
  controls.sampleList.replaceChildren(sampleLibraryMessage("サンプル曲を読み込んでいます…"));
  try {
    const response = await fetch(sampleCatalogURL());
    if (!response.ok) throw new Error(await responseDetail(response));
    state.samples = await response.json();
    renderSampleLibrary();
  } catch (error) {
    controls.sampleList.replaceChildren(sampleLibraryMessage(`サンプル曲を読み込めません: ${error.message}`));
  }
}

function renderSampleLibrary() {
  controls.sampleList.replaceChildren(...state.samples.map((sample) => {
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = sample.name;
    button.title = sample.name;
    button.addEventListener("click", () => { void loadBundledSample(sample); });
    return button;
  }));
}

function sampleLibraryMessage(message) {
  const element = document.createElement("span");
  element.className = "sample-library-message";
  element.textContent = message;
  return element;
}

async function loadBundledSample(sample) {
  info(`${sample.name} をSDKでレイアウトしています…`);
  try {
    const response = await fetch(sample.plan ?? companionAPI(`/api/sample?id=${encodeURIComponent(sample.id)}`));
    if (!response.ok) throw new Error(await responseDetail(response));
    load(await response.json(), sample.name);
    closeDrawer();
  } catch (error) {
    fail(`サンプル曲を開けません: ${error.message}`);
  }
}

function normalize(document) {
  if (document?.primaryPlan && Array.isArray(document.transposeVariants)) {
    return {
      primaryPlan: document.primaryPlan,
      variants: new Map(document.transposeVariants.map((item) => [Number(item.semitones), item.plan])),
      events: document.primaryPlan.playbackEvents ?? [],
      sourceToken: document.sourceToken ?? null,
      availableTransposeSemitones: document.availableTransposeSemitones ?? document.transposeVariants.map((item) => Number(item.semitones)).concat(0),
    };
  }
  return {
    primaryPlan: document,
    variants: new Map(),
    events: document?.playbackEvents ?? [],
    sourceToken: document?.sourceToken ?? null,
    availableTransposeSemitones: document?.availableTransposeSemitones ?? [0],
  };
}

function validate(plan) {
  if (!plan?.canvas || !Array.isArray(plan.commands) || !Array.isArray(plan.noteAnchors)) throw new Error("DoReMiRenderer Web Render Plan JSON を選択してください。");
}

async function applyTranspose(silent = false) {
  if (!state.source) return;
  const requestedTranspose = state.transpose;
  const requestID = ++state.transposeRequestID;
  let variant = requestedTranspose !== 0 ? state.source.variants.get(requestedTranspose) : state.source.primaryPlan;
  if (!variant && requestedTranspose !== 0 && state.source.sourceToken) {
    try {
      info("移調レイアウトをSDKで生成しています…");
      const response = await fetch(companionAPI(`/api/transpose?token=${encodeURIComponent(state.source.sourceToken)}&semitones=${requestedTranspose}`));
      if (!response.ok) throw new Error(await responseDetail(response));
      variant = await response.json();
      validate(variant);
      if (requestID !== state.transposeRequestID || requestedTranspose !== state.transpose) return;
      state.source.variants.set(requestedTranspose, variant);
    } catch (error) {
      if (requestID !== state.transposeRequestID || requestedTranspose !== state.transpose) return;
      if (!silent) fail(`移調レイアウトを生成できません: ${error.message}`);
      return;
    }
  }
  if (requestID !== state.transposeRequestID || requestedTranspose !== state.transpose) return;
  state.plan = variant ?? state.source.primaryPlan;
  state.lastFollowedSystemIndex = null;
  if (!variant && state.transpose !== 0 && !silent) info("このファイルには選択した移調レイアウトが含まれていません。");
  else controls.status.hidden = true;
  setEvent(state.currentIndex, false);
}

async function responseDetail(response) {
  const body = await response.text();
  try {
    return JSON.parse(body).error ?? body;
  } catch {
    return body;
  }
}

function events() { return state.source?.events ?? []; }

function redraw() {
  if (!state.plan) return;
  const event = state.printing ? null : events()[state.currentIndex];
  const nextEvent = state.printing || !state.nextNoteGuide ? null : events()[state.currentIndex + 1];
  const pages = pageFrames(state.plan);
  preparePageCanvases(pages);
  applyPageStackWidth(pages);
  for (const page of pages) {
    drawScoreCanvas(state.pageCanvases.get(page.index), state.plan, {
      pageFrame: page.frame, pageIndex: page.index,
      noteColors: state.noteColors, staffColors: state.staffColors, enabledPitchClasses: state.enabled,
      noteColorForPitchClass: (pitchClass) => COLORS.get(pitchClass),
      staffColorForPitchClass: (pitchClass) => COLORS.get(pitchClass),
      selectedNoteIDs: new Set(!state.printing && state.selectedNoteID ? [state.selectedNoteID] : []),
      currentNoteIDs: new Set(event?.noteIDs ?? []),
      nextNoteIDs: new Set(nextEvent?.noteIDs ?? []),
    });
  }
  updateKeyboard();
}

function pageFrames(plan) {
  if (Array.isArray(plan?.pages) && plan.pages.length > 0) return plan.pages;
  return [{ index: 0, frame: plan.canvas, contentFrame: plan.canvas, systemIndices: (plan.systems ?? []).map((system) => system.index) }];
}

function preparePageCanvases(pages) {
  const wanted = new Set(pages.map((page) => page.index));
  for (const [index, pageCanvas] of state.pageCanvases) {
    if (!wanted.has(index)) { pageCanvas.remove(); state.pageCanvases.delete(index); }
  }
  for (const page of pages) {
    let pageCanvas = state.pageCanvases.get(page.index);
    if (!pageCanvas) {
      pageCanvas = document.createElement("canvas");
      pageCanvas.className = "score-page";
      pageCanvas.dataset.pageIndex = String(page.index);
      pageCanvas.setAttribute("aria-label", `Rendered music score page ${page.index + 1}`);
      pageCanvas.addEventListener("click", selectAnchor);
      state.pageCanvases.set(page.index, pageCanvas);
    }
    pageStack.append(pageCanvas);
  }
}

function applyPageStackWidth(pages = pageFrames(state.plan)) {
  const firstPage = pages[0];
  if (!firstPage) return;
  pageStack.style.width = `${firstPage.frame.width * state.scoreZoom}px`;
}

function sync() {
  const hasTimeline = events().length > 0;
  controls.keyboard.classList.toggle("active", state.keyboardVisible);
  controls.keyboard.setAttribute("aria-pressed", String(state.keyboardVisible));
  controls.dock.hidden = !state.keyboardVisible;
  syncCheckToggle(controls.noteColors, state.noteColors);
  syncCheckToggle(controls.staffColors, state.staffColors);
  syncCheckToggle(controls.keyboardColors, state.keyboardColors);
  syncCheckToggle(controls.nextNoteGuide, state.nextNoteGuide);
  syncCheckToggle(controls.allPitches, state.enabled.size === 12);
  controls.keyboardColorPosition.textContent = state.keyboardColorPosition === "top" ? "鍵盤色: 上" : "鍵盤色: 下";
  controls.keyboardElement.classList.toggle("color-bottom", state.keyboardColorPosition === "bottom");
  controls.transpose.value = String(state.transpose);
  controls.transpose.disabled = state.source == null || (state.source.variants.size === 0 && !state.source.sourceToken);
  controls.originalScale.disabled = state.transpose === 0;
  controls.tempo.value = String(Math.round(state.tempoBPM));
  controls.tempo.disabled = !hasTimeline;
  controls.zoom.value = String(Math.round(state.scoreZoom * 100));
  controls.zoom.disabled = !state.plan;
  controls.fitWidth.disabled = !state.plan;
  controls.print.disabled = !state.plan || state.printing;
  for (const button of document.querySelectorAll("#pitch-controls button")) {
    const classes = button.dataset.classes.split(",").map(Number);
    button.classList.toggle("is-active", classes.every((pitchClass) => state.enabled.has(pitchClass)));
  }
  for (const button of [controls.reset, controls.previous, controls.play, controls.stop, controls.next, controls.jump]) button.disabled = !hasTimeline;
  controls.measure.disabled = !hasTimeline;
  const event = events()[state.currentIndex];
  controls.measureStatus.textContent = event ? `${event.measureNumber} / ${new Set(events().map((item) => item.measureNumber)).size}` : "-/ -";
  if (event) controls.measure.value = event.measureNumber;
}

function printScore() {
  if (!state.plan || state.printing) return;
  stop();
  state.printing = true;
  document.body.classList.add("is-printing");
  sync();
  requestAnimationFrame(() => {
    redraw();
    requestAnimationFrame(() => window.print());
  });
}

function finishPrint() {
  if (!state.printing) return;
  state.printing = false;
  document.body.classList.remove("is-printing");
  requestAnimationFrame(() => { redraw(); sync(); });
}

function buildPalette() {
  const root = $("#pitch-controls");
  for (const [name, classes] of PITCHES) {
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = name;
    button.className = name.toLowerCase();
    button.dataset.classes = classes.join(",");
    button.addEventListener("click", () => { const enabled = classes.every((value) => state.enabled.has(value)); for (const value of classes) enabled ? state.enabled.delete(value) : state.enabled.add(value); sync(); redraw(); });
    root.append(button);
  }
}

function buildTranspose() {
  controls.transpose.replaceChildren();
  const signature = state.source?.primaryPlan?.initialKeySignature ?? { fifths: 0, mode: "major" };
  const tonic = tonicForKeySignature(signature);
  const mode = keyMode(signature);
  // One representative for every chromatic pitch class. The written key is
  // near the middle; octave-equivalent +/-12 choices are intentionally absent.
  const variantValues = state.source?.availableTransposeSemitones ?? [...(state.source?.variants.keys() ?? [])];
  const values = [...new Set([0, ...variantValues])]
    .filter((value) => value >= -6 && value <= 5)
    .sort((left, right) => left - right);
  for (const value of values) {
    const option = document.createElement("option");
    option.value = String(value);
    option.textContent = scaleName(mod(tonic + value, 12), mode, value === 0);
    controls.transpose.append(option);
  }
}

function syncCheckToggle(button, isActive) {
  button.classList.toggle("is-active", isActive);
  button.setAttribute("aria-pressed", String(isActive));
}

function buildKeyboard() {
  const root = $("#keyboard");
  const values = Array.from({ length: 49 }, (_, index) => index + 36);
  const whites = values.filter((midi) => WHITE.has(mod(midi, 12)));
  whites.forEach((midi, index) => makeKey(root, midi, "white-key", index / whites.length * 100, 100 / whites.length));
  values.filter((midi) => !WHITE.has(mod(midi, 12))).forEach((midi) => {
    const preceding = whites.filter((value) => value < midi).length;
    makeKey(root, midi, "black-key", preceding / whites.length * 100 - 100 / whites.length * 0.31, 100 / whites.length * 0.62);
  });
  updateKeyboard();
}

function makeKey(root, midi, className, left, width) {
  const key = document.createElement("button");
  key.type = "button";
  key.className = className;
  key.dataset.midi = midi;
  key.style.left = `${left}%`;
  key.style.width = `${width}%`;
  if (className === "white-key" && mod(midi, 12) === 0) key.textContent = midiLabel(midi);
  key.addEventListener("click", () => selectMidi(midi));
  root.append(key);
}

function updateKeyboard() {
  const scaleColors = scaleDegreeColorMap();
  for (const key of document.querySelectorAll("[data-midi]")) {
    const midi = Number(key.dataset.midi);
    const pitchClass = mod(midi, 12);
    const scaleColorPitchClass = scaleColors.get(pitchClass);
    const isScalePitch = scaleColorPitchClass != null && state.enabled.has(scaleColorPitchClass);
    const isActive = state.activeMIDIs.has(midi) || midi === state.selectedMidi;
    const isNext = state.nextNoteGuide && state.nextMIDIs.has(midi) && !isActive;
    key.style.setProperty("--key-color", COLORS.get(isScalePitch ? scaleColorPitchClass : pitchClass));
    key.classList.toggle("is-colored", state.keyboardColors && isScalePitch);
    key.classList.toggle("is-selected", isActive);
    key.classList.toggle("is-next-guide", isNext);
    key.classList.toggle("is-guide-outside", isActive && !isScalePitch);
  }
  const active = [...state.activeMIDIs].map(midiLabel).join(" · ");
  controls.selected.textContent = active || (state.selectedMidi == null ? "音符を選択してください" : midiLabel(state.selectedMidi));
}

function selectAnchor(event) {
  if (!state.plan) return;
  const pageCanvas = event.currentTarget;
  const page = pageFrames(state.plan).find((item) => item.index === Number(pageCanvas.dataset.pageIndex));
  if (!page) return;
  const bounds = pageCanvas.getBoundingClientRect();
  const scale = page.frame.width / bounds.width;
  const x = page.frame.x + (event.clientX - bounds.left) * scale;
  const y = page.frame.y + (event.clientY - bounds.top) * scale;
  const nearest = state.plan.noteAnchors.reduce((result, anchor) => {
    const distance = (anchor.center.x - x) ** 2 + (anchor.center.y - y) ** 2;
    return distance < result.distance ? { anchor, distance } : result;
  }, { anchor: null, distance: Infinity });
  if (!nearest.anchor || Math.sqrt(nearest.distance) > 32) return;
  const index = events().findIndex((item) => item.noteIDs.includes(nearest.anchor.noteID));
  if (index >= 0) setEvent(index, true);
}

function selectMidi(midi) {
  const index = events().findIndex((event) => transposedPitches(event).includes(midi));
  if (index >= 0) setEvent(index, true);
}

function setEvent(index, shouldFollow) {
  const timeline = events();
  if (!timeline.length) { sync(); redraw(); return; }
  state.currentIndex = Math.min(Math.max(index, 0), timeline.length - 1);
  const event = timeline[state.currentIndex];
  state.selectedNoteID = event.noteIDs[0] ?? null;
  state.selectedMidi = transposedPitches(event)[0] ?? null;
  state.activeMIDIs = state.playing ? new Set(transposedPitches(event)) : new Set();
  state.nextMIDIs = new Set(transposedPitches(timeline[state.currentIndex + 1] ?? { midiPitches: [] }));
  controls.current.textContent = state.selectedMidi == null ? "-" : `現在の音: ${transposedPitches(event).map(midiLabel).join(" · ")}`;
  sync();
  redraw();
  if (shouldFollow) follow(event);
}

function move(delta) {
  const wasPlaying = state.playing;
  if (wasPlaying) stop();
  setEvent(state.currentIndex + delta, true);
  if (wasPlaying) play();
}

function jumpToMeasure() {
  const requested = Number(controls.measure.value);
  const index = events().findIndex((event) => Number(event.measureNumber) === requested);
  if (index < 0) { info("指定した小節は、この再生シーケンスにありません。"); return; }
  const wasPlaying = state.playing;
  if (wasPlaying) stop();
  setEvent(index, true);
  if (wasPlaying) play();
}

async function play() {
  if (state.playing || !events().length) return;
  const AudioContextClass = window.AudioContext || window.webkitAudioContext;
  if (!AudioContextClass) { info("このブラウザではWeb Audio再生を利用できません。"); return; }
  state.context ??= new AudioContextClass();
  await state.context.resume();
  state.playing = true;
  state.contextStart = state.context.currentTime;
  state.timelineStart = events()[state.currentIndex].startSeconds;
  state.nextScheduledIndex = state.currentIndex;
  setEvent(state.currentIndex, true);
  tick();
}

function stop() {
  state.playing = false;
  if (state.animationFrame != null) cancelAnimationFrame(state.animationFrame);
  state.animationFrame = null;
  for (const oscillator of state.nodes) { try { oscillator.stop(); } catch { /* already stopped */ } }
  state.nodes.clear();
  state.activeMIDIs = new Set();
  sync();
  redraw();
}

function tick() {
  if (!state.playing || !state.context) return;
  const timeline = events();
  const elapsed = state.timelineStart + Math.max(0, state.context.currentTime - state.contextStart) * playbackRate();
  while (state.nextScheduledIndex < timeline.length && timeline[state.nextScheduledIndex].startSeconds <= elapsed + 0.18) schedule(timeline[state.nextScheduledIndex++], elapsed);
  const index = eventIndexAt(elapsed, timeline);
  if (index !== state.currentIndex) setEvent(index, true);
  const last = timeline.at(-1);
  if (elapsed >= last.startSeconds + last.intervalSeconds) { state.currentIndex = timeline.length - 1; stop(); return; }
  state.animationFrame = requestAnimationFrame(tick);
}

function schedule(event, elapsed) {
  if (!state.context) return;
  const start = state.context.currentTime + Math.max(0, (event.startSeconds - elapsed) / playbackRate());
  // Match PalettePlaybackRuntime.playbackVelocity(for:): the iOS tone engine
  // receives an 80% base velocity, clamped to the same audible range.
  const velocity = Math.min(1, Math.max(0.08, 0.8 * event.velocityScale));
  const baseGain = velocity * 0.22;
  for (const sourceMidi of event.midiPitches) {
    const midi = sourceMidi + state.transpose;
    if (midi < 0 || midi > 127) continue;
    const oscillator = state.context.createOscillator();
    const gain = state.context.createGain();
    oscillator.setPeriodicWave(iOSLikePeriodicWave(state.context));
    oscillator.frequency.value = 440 * 2 ** ((midi - 69) / 12);
    // Duration metadata is keyed by the written pitch; transposition changes
    // pitch output only and must not alter the source note's written duration.
    const duration = Math.min(Math.max(0.03, (event.midiSoundDurationSeconds?.[sourceMidi] ?? event.soundDurationSeconds) / playbackRate()), 8);
    const fade = Math.min(0.01, duration / 2);
    const gainValue = baseGain * (oscillator.frequency.value < 180 ? 1.35 : 1);
    gain.gain.setValueAtTime(0.0001, start);
    gain.gain.exponentialRampToValueAtTime(Math.max(0.0001, gainValue), start + fade);
    gain.gain.setValueAtTime(Math.max(0.0001, gainValue), Math.max(start + fade, start + duration - fade));
    gain.gain.exponentialRampToValueAtTime(0.0001, start + duration);
    oscillator.connect(gain).connect(state.context.destination);
    oscillator.start(start);
    oscillator.stop(start + duration + 0.02);
    oscillator.addEventListener("ended", () => state.nodes.delete(oscillator));
    state.nodes.add(oscillator);
  }
}

function iOSLikePeriodicWave(context) {
  state.iOSLikeWave ??= context.createPeriodicWave(
    new Float32Array(4),
    new Float32Array([0, 1 / 1.44, 0.32 / 1.44, 0.12 / 1.44]),
    { disableNormalization: true }
  );
  return state.iOSLikeWave;
}

function eventIndexAt(time, timeline) {
  let low = 0;
  let high = timeline.length - 1;
  while (low < high) { const middle = Math.ceil((low + high) / 2); if (timeline[middle].startSeconds <= time) low = middle; else high = middle - 1; }
  return low;
}

function updateTempoFromInput() {
  const value = Number(controls.tempo.value);
  if (!Number.isFinite(value)) { sync(); return; }
  state.tempoBPM = clampTempoBPM(value);
  const resume = state.playing;
  if (resume) stop();
  sync();
  if (resume) play();
}

function updateZoomFromInput() {
  const value = Number(controls.zoom.value);
  if (!Number.isFinite(value)) { sync(); return; }
  setScoreZoom(value / 100);
}

function fitScoreToWidth() {
  const page = pageFrames(state.plan)[0];
  const scroll = $("#score-scroll");
  if (!page || scroll.clientWidth <= 0) return false;

  // Keep the A4 frame unchanged and only fit its rendered width inside the scroll viewport.
  const fit = () => setScoreZoom((scroll.clientWidth - 2) / page.frame.width, false);
  fit();
  // A newly visible vertical scrollbar changes clientWidth on non-overlay scrollbar platforms.
  requestAnimationFrame(fit);
  return true;
}

function sourceTempoBPM(timeline) {
  const explicitTempo = timeline.find((event) => Number.isFinite(Number(event.tempoBPM)))?.tempoBPM;
  return clampTempoBPM(explicitTempo ?? 120);
}

function clampTempoBPM(value) { return Math.min(300, Math.max(30, Math.round(Number(value)))); }
function playbackRate() { return state.tempoBPM / state.baseTempoBPM; }

function follow(event) {
  const anchor = state.plan?.noteAnchors.find((item) => event.noteIDs.includes(item.noteID));
  const systemIndex = anchor?.systemIndex;
  if (!anchor || systemIndex == null || state.lastFollowedSystemIndex === systemIndex) return;
  const system = (state.plan?.systems ?? []).find((item) => item.index === systemIndex);
  if (!system) return;
  const page = pageFrames(state.plan).find((item) => item.systemIndices?.includes(systemIndex));
  const pageCanvas = page ? state.pageCanvases.get(page.index) : null;
  if (!page || !pageCanvas) return;
  const scroll = $("#score-scroll");
  const canvasBounds = pageCanvas.getBoundingClientRect();
  const scrollBounds = scroll.getBoundingClientRect();
  const localY = (system.frame.y - page.frame.y) / page.frame.height * canvasBounds.height;
  const position = canvasBounds.top + localY - scrollBounds.top;
  state.lastFollowedSystemIndex = systemIndex;
  scroll.scrollTo({ top: Math.max(0, scroll.scrollTop + position - scrollBounds.height * 0.18), behavior: "smooth" });
}

function setScoreZoom(value, snapToInputStep = true) {
  const clamped = Math.min(3, Math.max(0.5, value));
  state.scoreZoom = snapToInputStep ? Math.round(clamped * 10) / 10 : clamped;
  applyPageStackWidth();
  redraw();
  sync();
}

function keyMode(signature) {
  return String(signature?.mode ?? "major").toLowerCase().includes("minor") ? "minor" : "major";
}

function tonicForKeySignature(signature) {
  const majorTonics = [11, 6, 1, 8, 3, 10, 5, 0, 7, 2, 9, 4, 11, 6, 1];
  const fifths = Math.max(-7, Math.min(7, Number(signature?.fifths ?? 0)));
  const majorTonic = majorTonics[fifths + 7];
  return keyMode(signature) === "minor" ? mod(majorTonic + 9, 12) : majorTonic;
}

function scalePitchClasses() {
  const signature = state.plan?.initialKeySignature ?? state.source?.primaryPlan?.initialKeySignature;
  const tonic = tonicForKeySignature(signature);
  const intervals = keyMode(signature) === "minor" ? [0, 2, 3, 5, 7, 8, 10] : [0, 2, 4, 5, 7, 9, 11];
  return new Set(intervals.map((interval) => mod(tonic + interval, 12)));
}

function scaleDegreeColorMap() {
  const signature = state.plan?.initialKeySignature ?? state.source?.primaryPlan?.initialKeySignature;
  const tonic = tonicForKeySignature(signature);
  const intervals = keyMode(signature) === "minor" ? [0, 2, 3, 5, 7, 8, 10] : [0, 2, 4, 5, 7, 9, 11];
  const tonicLetter = tonicLetterIndexForKeySignature(signature);
  const naturalPitchClasses = [0, 2, 4, 5, 7, 9, 11];
  return new Map(intervals.map((interval, degree) => [
    mod(tonic + interval, 12),
    naturalPitchClasses[mod(tonicLetter + degree, naturalPitchClasses.length)],
  ]));
}

function tonicLetterIndexForKeySignature(signature) {
  const majorTonicLetters = [0, 4, 1, 5, 2, 6, 3, 0, 4, 1, 5, 2, 6, 3, 0];
  const fifths = Math.max(-7, Math.min(7, Number(signature?.fifths ?? 0)));
  const majorLetter = majorTonicLetters[fifths + 7];
  return keyMode(signature) === "minor" ? mod(majorLetter + 5, 7) : majorLetter;
}

function scaleName(tonic, mode, original) {
  const names = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"];
  const relative = mode === "minor" ? mod(tonic + 3, 12) : mod(tonic + 9, 12);
  const pair = mode === "minor"
    ? `${names[tonic]}m / ${names[relative]}`
    : `${names[tonic]} / ${names[relative]}m`;
  return `${original ? "♪ " : ""}${pair}`;
}

function transposedPitches(event) { return event.midiPitches.map((midi) => midi + state.transpose).filter((midi) => midi >= 0 && midi <= 127); }
function togglePalette() { setActiveDrawer(state.activeDrawer === "palette" ? null : "palette"); }
function closeDrawer() { setActiveDrawer(null); }
function setActiveDrawer(kind) {
  state.activeDrawer = kind;
  const isOpen = kind != null;
  const paletteOpen = kind === "palette";
  const samplesOpen = kind === "samples";
  controls.drawer.classList.toggle("is-open", isOpen);
  controls.drawerBackdrop.classList.toggle("is-open", isOpen);
  controls.drawer.setAttribute("aria-hidden", String(!isOpen));
  controls.drawerBackdrop.setAttribute("aria-hidden", String(!isOpen));
  controls.palette.classList.toggle("is-open", paletteOpen);
  controls.sampleLibrary.classList.toggle("is-open", samplesOpen);
  controls.paletteButton.classList.toggle("active", paletteOpen);
  controls.sampleLibraryButton.classList.toggle("active", samplesOpen);
  controls.paletteButton.setAttribute("aria-expanded", String(paletteOpen));
  controls.sampleLibraryButton.setAttribute("aria-expanded", String(samplesOpen));
  controls.drawerTitle.textContent = paletteOpen ? "カラーパレット" : "サンプル曲";
}
function companionAPI(path) {
  return state.companionOrigin ? `${state.companionOrigin}${path}` : path;
}

function sampleCatalogURL() {
  // GitHub Pages ships only the two sample scores that cleared the bundled
  // asset review. Local development keeps its broader fixture catalogue.
  return usesLoopbackCompanion ? companionAPI("/api/samples") : "./samples/catalog.json";
}

async function configureStaticHosting() {
  if (usesLoopbackCompanion) return;
  controls.sampleLibraryButton.title = "サンプル曲";
  controls.file.closest("label")?.setAttribute("title", "MusicXML、MXL、またはWeb Render Planを開く");
  for (const origin of loopbackCompanionOrigins) {
    try {
      const response = await fetch(`${origin}/api/health`, { cache: "no-store" });
      if (!response.ok) continue;
      state.companionOrigin = origin;
      return;
    } catch {
      // Try the next conventional loopback port before falling back to JSON.
    }
  }
}
function info(message) { pageStack.hidden = false; controls.status.hidden = false; controls.status.textContent = message; }
function fail(message) { pageStack.hidden = true; controls.status.hidden = false; controls.status.textContent = message; }
function midiLabel(midi) { const names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]; return `${names[mod(midi, 12)]}${Math.floor(midi / 12) - 1}`; }
function mod(value, divisor) { return ((value % divisor) + divisor) % divisor; }
