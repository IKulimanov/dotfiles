// Иконка ярлыка шпаргалки для Dock, 1024×1024 PNG. Рисуется средствами macOS,
// без сети и лишних пакетов. Цвета — Catppuccin Mocha, как в nvim.
//
//   osascript -l JavaScript macos/dock-icon.js <куда.png>
ObjC.import('AppKit');

function run(argv) {
  const out = argv[0];
  const S = 1024;
  const rgb = (hex, a) => {
    const n = parseInt(hex.slice(1), 16);
    return $.NSColor.colorWithSRGBRedGreenBlueAlpha(
      ((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255, a === undefined ? 1 : a);
  };
  const text = (str, size, weight, color) => {
    const attrs = $.NSDictionary.dictionaryWithObjectsForKeys(
      $([$.NSFont.monospacedSystemFontOfSizeWeight(size, weight), rgb(color)]),
      $([$.NSFontAttributeName, $.NSForegroundColorAttributeName]));
    const s = $(str);
    return { s, attrs, size: s.sizeWithAttributes(attrs) };
  };

  const rep = $.NSBitmapImageRep.alloc
    .initWithBitmapDataPlanesPixelsWidePixelsHighBitsPerSampleSamplesPerPixelHasAlphaIsPlanarColorSpaceNameBytesPerRowBitsPerPixel(
      null, S, S, 8, 4, true, false, $.NSDeviceRGBColorSpace, 0, 0);
  $.NSGraphicsContext.saveGraphicsState;
  // Присваивание currentContext в JXA не срабатывает — нужен явный вызов сеттера
  $.NSGraphicsContext.setCurrentContext($.NSGraphicsContext.graphicsContextWithBitmapImageRep(rep));

  // Плитка по сетке значков macOS: 824 точки в центре холста 1024, скругление ~185
  const tile = $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius($.NSMakeRect(100, 100, 824, 824), 185, 185);

  $.NSGraphicsContext.saveGraphicsState;
  const shadow = $.NSShadow.alloc.init;
  shadow.shadowBlurRadius = 28;
  shadow.shadowOffset = $.NSMakeSize(0, -14);
  shadow.shadowColor = rgb('#000000', 0.35);
  shadow.set;
  rgb('#1e1e2e').setFill;
  tile.fill;
  $.NSGraphicsContext.restoreGraphicsState;

  $.NSGradient.alloc.initWithStartingColorEndingColor(rgb('#313244'), rgb('#181825')).drawInBezierPathAngle(tile, -90);
  rgb('#45475a').setStroke;
  tile.lineWidth = 6;
  tile.stroke;

  // «nvim» и курсор-блок после него
  const word = text('nvim', 210, 0.4, '#a6e3a1');
  const cursorW = 70, gap = 14;
  const x = (S - (word.size.width + gap + cursorW)) / 2;
  const y = (S - word.size.height) / 2 + 10;
  word.s.drawAtPointWithAttributes($.NSMakePoint(x, y), word.attrs);
  rgb('#89b4fa').setFill;
  $.NSBezierPath.fillRect($.NSMakeRect(x + word.size.width + gap, y + word.size.height * 0.2, cursorW, word.size.height * 0.62));

  // «:help» ниже: страница — справка
  const help = text(':help', 120, 0.3, '#f9e2af');
  help.s.drawAtPointWithAttributes($.NSMakePoint((S - help.size.width) / 2, 200), help.attrs);

  $.NSGraphicsContext.restoreGraphicsState;

  const png = rep.representationUsingTypeProperties(4, $.NSDictionary.dictionary);  // 4 — PNG
  if (!png.writeToFileAtomically($(out), true)) throw new Error('не удалось записать ' + out);
  return out;
}
