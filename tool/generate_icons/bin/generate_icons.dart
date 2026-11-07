import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Fraction of the output canvas used for artwork (rest is transparent padding).
/// ~0.58 keeps artwork inside Android/iOS circular launcher masks (~66% safe zone).
const launcherContentScale = 0.58;

/// Maskable PWA icons need extra padding (content in center ~80% circle).
const maskableContentScale = 0.54;

/// Adaptive-icon layers are 108dp. Masks may clip anything outside the center
/// 66dp circle, so foreground artwork has to fit in that circle.
const adaptiveSafeDiameter = 66 / 108;

late img.Image source;

/// Source with the flat backdrop removed. White facet pixels inside the gem stay.
late img.Image gem;
late double gemCenterX;
late double gemCenterY;
late double gemMaxRadius;

img.Image renderIcon(int size, {double contentScale = launcherContentScale}) {
  final canvas = img.Image(width: size, height: size);
  final artSize = (size * contentScale).round();
  final scaled = img.copyResize(
    source,
    width: artSize,
    height: artSize,
    interpolation: img.Interpolation.nearest,
  );
  final x = ((size - artSize) / 2).round();
  final y = ((size - artSize) / 2).round();
  img.compositeImage(canvas, scaled, dstX: x, dstY: y);
  return canvas;
}

void writePng(String path, img.Image image) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(img.encodePng(image));
  stdout.writeln('Wrote $path');
}

bool _isBackdrop(img.Pixel p) =>
    p.a < 16 || (p.r > 245 && p.g > 245 && p.b > 245);

/// Removes the connected corner backdrop so padding scales the gem, not a
/// full-bleed white plate. Interior white highlights are not connected to
/// the corners, so they stay.
void prepareGem() {
  final width = source.width;
  final height = source.height;
  final backdrop = List<bool>.filled(width * height, false);
  final qx = <int>[];
  final qy = <int>[];

  void push(int x, int y) {
    if (x < 0 || y < 0 || x >= width || y >= height) return;
    final i = y * width + x;
    if (backdrop[i] || !_isBackdrop(source.getPixel(x, y))) return;
    backdrop[i] = true;
    qx.add(x);
    qy.add(y);
  }

  for (var x = 0; x < width; x++) {
    push(x, 0);
    push(x, height - 1);
  }
  for (var y = 0; y < height; y++) {
    push(0, y);
    push(width - 1, y);
  }
  for (var head = 0; head < qx.length; head++) {
    final x = qx[head];
    final y = qy[head];
    push(x + 1, y);
    push(x - 1, y);
    push(x, y + 1);
    push(x, y - 1);
  }

  gem = img.Image(width: width, height: height, numChannels: 4);
  var minX = width;
  var minY = height;
  var maxX = 0;
  var maxY = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (backdrop[y * width + x]) continue;
      gem.setPixel(x, y, source.getPixel(x, y));
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
  }

  gemCenterX = (minX + maxX) / 2;
  gemCenterY = (minY + maxY) / 2;
  var maxR2 = 0.0;
  for (var y = minY; y <= maxY; y++) {
    for (var x = minX; x <= maxX; x++) {
      if (backdrop[y * width + x]) continue;
      final dx = x - gemCenterX;
      final dy = y - gemCenterY;
      final r2 = dx * dx + dy * dy;
      if (r2 > maxR2) maxR2 = r2;
    }
  }
  gemMaxRadius = math.sqrt(maxR2);
  stdout.writeln(
    'Gem center (${gemCenterX.toStringAsFixed(1)}, ${gemCenterY.toStringAsFixed(1)}) '
    'max radius ${gemMaxRadius.toStringAsFixed(1)}px',
  );
}

/// Places the gem so its farthest pixel sits inside a circle of
/// [safeDiameter] times the canvas. [whiteBackground] fills the square for
/// legacy icons; adaptive foregrounds stay transparent.
img.Image renderFittedGem(
  int size, {
  required double safeDiameter,
  bool whiteBackground = false,
}) {
  final canvas = img.Image(width: size, height: size, numChannels: 4);
  if (whiteBackground) {
    img.fill(canvas, color: img.ColorRgba8(255, 255, 255, 255));
  }
  // Keep a hair of room so mask antialiasing does not shave the outline.
  final targetRadius = size * safeDiameter / 2 * 0.98;
  final scale = targetRadius / gemMaxRadius;
  final scaled = img.copyResize(
    gem,
    width: math.max(1, (gem.width * scale).round()),
    height: math.max(1, (gem.height * scale).round()),
    interpolation: img.Interpolation.nearest,
  );
  final dstX = (size / 2 - gemCenterX * scale).round();
  final dstY = (size / 2 - gemCenterY * scale).round();
  img.compositeImage(canvas, scaled, dstX: dstX, dstY: dstY);
  return canvas;
}

void _assertInsideCircle(img.Image icon, double diameterFraction, String label) {
  final radius = icon.width * diameterFraction / 2;
  final cx = icon.width / 2;
  final cy = icon.height / 2;
  var outside = 0;
  for (var y = 0; y < icon.height; y++) {
    for (var x = 0; x < icon.width; x++) {
      final p = icon.getPixel(x, y);
      if (p.a < 16) continue;
      if (p.r > 245 && p.g > 245 && p.b > 245) continue;
      final dx = x + 0.5 - cx;
      final dy = y + 0.5 - cy;
      if (dx * dx + dy * dy > radius * radius) outside++;
    }
  }
  if (outside > 0) {
    throw StateError('$label has $outside gem pixels outside the safe circle');
  }
  stdout.writeln('$label fits inside the safe circle');
}

void generateAndroid(String repoRoot) {
  const densities = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  };
  // Foreground layers live in drawable-* so they are not scaled as 48dp mipmaps.
  const adaptiveDensities = {
    'mdpi': 108,
    'hdpi': 162,
    'xhdpi': 216,
    'xxhdpi': 324,
    'xxxhdpi': 432,
  };

  for (final entry in densities.entries) {
    // Legacy launchers mask this whole bitmap with a circle.
    final icon = renderFittedGem(entry.value, safeDiameter: 1, whiteBackground: true);
    _assertInsideCircle(icon, 1, 'mipmap-${entry.key}/ic_launcher.png');
    writePng(
      '$repoRoot/android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
      icon,
    );
    writePng(
      '$repoRoot/android/app/src/main/res/mipmap-${entry.key}/ic_launcher_round.png',
      icon,
    );
  }

  for (final entry in adaptiveDensities.entries) {
    final fg = renderFittedGem(entry.value, safeDiameter: adaptiveSafeDiameter);
    _assertInsideCircle(
      fg,
      adaptiveSafeDiameter,
      'drawable-${entry.key}/ic_launcher_foreground.png',
    );
    writePng(
      '$repoRoot/android/app/src/main/res/drawable-${entry.key}/ic_launcher_foreground.png',
      fg,
    );
  }

  final adaptiveDir = Directory(
    '$repoRoot/android/app/src/main/res/mipmap-anydpi-v26',
  );
  adaptiveDir.createSync(recursive: true);

  File('$repoRoot/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml')
      .writeAsString('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
    <monochrome android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
''');

  File('$repoRoot/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml')
      .writeAsString('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
    <monochrome android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
''');

  final valuesDir = Directory('$repoRoot/android/app/src/main/res/values');
  valuesDir.createSync(recursive: true);
  File('$repoRoot/android/app/src/main/res/values/ic_launcher_background.xml')
      .writeAsString('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#FFFFFF</color>
</resources>
''');
}

void generateIos(String repoRoot) {
  const appIconDir =
      'ios/Runner/Assets.xcassets/AppIcon.appiconset';
  const sizes = {
    'Icon-App-20x20@1x.png': 20,
    'Icon-App-20x20@2x.png': 40,
    'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29,
    'Icon-App-29x29@2x.png': 58,
    'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40,
    'Icon-App-40x40@2x.png': 80,
    'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120,
    'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76,
    'Icon-App-76x76@2x.png': 152,
    'Icon-App-83.5x83.5@2x.png': 167,
    'Icon-App-1024x1024@1x.png': 1024,
    '1024.png': 1024,
    '180.png': 180,
    '120.png': 120,
    '114.png': 114,
    '87.png': 87,
    '80.png': 80,
    '60.png': 60,
    '58.png': 58,
    '57.png': 57,
    '40.png': 40,
    '29.png': 29,
  };

  for (final entry in sizes.entries) {
    writePng(
      '$repoRoot/$appIconDir/${entry.key}',
      renderIcon(entry.value),
    );
  }
}

void generateMacos(String repoRoot) {
  const dir = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';
  const sizes = {
    'app_icon_16.png': 16,
    'app_icon_32.png': 32,
    'app_icon_64.png': 64,
    'app_icon_128.png': 128,
    'app_icon_256.png': 256,
    'app_icon_512.png': 512,
    'app_icon_1024.png': 1024,
  };
  for (final entry in sizes.entries) {
    writePng('$repoRoot/$dir/${entry.key}', renderIcon(entry.value));
  }
}

void generateWeb(String repoRoot) {
  writePng(
    '$repoRoot/web/icons/Icon-192.png',
    renderIcon(192),
  );
  writePng(
    '$repoRoot/web/icons/Icon-512.png',
    renderIcon(512),
  );
  writePng(
    '$repoRoot/web/icons/Icon-maskable-192.png',
    renderIcon(192, contentScale: maskableContentScale),
  );
  writePng(
    '$repoRoot/web/icons/Icon-maskable-512.png',
    renderIcon(512, contentScale: maskableContentScale),
  );
  writePng('$repoRoot/web/favicon.png', renderIcon(32));

  // Root GitHub Pages assets
  writePng('$repoRoot/icons/Icon-192.png', renderIcon(192));
  writePng('$repoRoot/icons/Icon-512.png', renderIcon(512));
  writePng(
    '$repoRoot/icons/Icon-maskable-192.png',
    renderIcon(192, contentScale: maskableContentScale),
  );
  writePng(
    '$repoRoot/icons/Icon-maskable-512.png',
    renderIcon(512, contentScale: maskableContentScale),
  );
  writePng('$repoRoot/favicon.png', renderIcon(32));
}

void main(List<String> args) {
  const platforms = {'android', 'ios', 'macos', 'web'};
  final selected = args.where(platforms.contains).toSet();
  final positional = args.where((arg) => !platforms.contains(arg)).toList();
  final repoRoot = positional.isNotEmpty
      ? positional.first
      : Directory.current.parent.parent.path;
  final sourcePath = positional.length > 1
      ? positional[1]
      : '$repoRoot/tool/generate_icons/source_1024.png';

  source = img.decodePng(File(sourcePath).readAsBytesSync())!;
  prepareGem();
  stdout.writeln(
    'Source: ${source.width}x${source.height}, content scale: $launcherContentScale',
  );

  final runAll = selected.isEmpty;
  if (runAll || selected.contains('android')) generateAndroid(repoRoot);
  if (runAll || selected.contains('ios')) generateIos(repoRoot);
  if (runAll || selected.contains('macos')) generateMacos(repoRoot);
  if (runAll || selected.contains('web')) generateWeb(repoRoot);

  stdout.writeln('Done. Regenerated icons with safe-zone padding.');
}
