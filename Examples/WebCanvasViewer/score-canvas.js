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

export function drawScoreCanvas(canvas, plan) {
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

  for (const command of plan.commands) {
    const color = cssColor(command.color);
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
