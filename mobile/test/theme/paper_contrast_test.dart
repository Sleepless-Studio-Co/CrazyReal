import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/widgets/paper.dart';

import 'contrast_audit.dart';

void main() {
  for (final (name, p) in [
    ('light', PaperColors.light),
    ('dark', PaperColors.dark)
  ]) {
    group('$name palette (WCAG AA)', () {
      final surfaces = {'bg': p.bg, 'card': p.card, 'field': p.field};

      for (final (fgName, fg, min) in [
        ('ink', p.ink, 4.5),
        ('inkMuted', p.inkMuted, 4.5),
        ('accent', p.accent, 4.5),
        ('danger', p.danger, 4.5),
        ('success', p.success, 4.5),
      ]) {
        for (final MapEntry(key: bgName, value: bg) in surfaces.entries) {
          test('$fgName on $bgName >= $min:1', () {
            expect(contrastRatio(fg, bg), greaterThanOrEqualTo(min));
          });
        }
      }

      test('ink and inkMuted stay readable on chips', () {
        expect(contrastRatio(p.ink, p.chip), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(p.inkMuted, p.chip), greaterThanOrEqualTo(4.5));
      });

      test('the image placeholder is distinguishable from the card', () {
        expect(p.placeholder, isNot(p.card));
      });
    });
  }

  test('the dark palette really is dark and the light one light', () {
    expect(PaperColors.dark.bg.computeLuminance(), lessThan(0.05));
    expect(PaperColors.dark.ink.computeLuminance(), greaterThan(0.6));
    expect(PaperColors.light.bg.computeLuminance(), greaterThan(0.7));
    expect(PaperColors.light.ink.computeLuminance(), lessThan(0.05));
  });

  test('white text stays readable on the fixed filled colours', () {
    for (final fill in [paperAccentStrong, paperDanger, paperSuccess]) {
      expect(contrastRatio(Colors.white, fill), greaterThanOrEqualTo(4.5));
    }
  });

  testWidgets('paperTheme exposes the palette matching its brightness',
      (tester) async {
    expect(
        paperTheme(Brightness.dark).extension<PaperColors>(), PaperColors.dark);
    expect(paperTheme(Brightness.light).extension<PaperColors>(),
        PaperColors.light);
    expect(paperTheme(Brightness.dark).scaffoldBackgroundColor,
        PaperColors.dark.bg);
    expect(paperTheme(Brightness.dark).colorScheme.onSurface,
        PaperColors.dark.ink);
  });
}
