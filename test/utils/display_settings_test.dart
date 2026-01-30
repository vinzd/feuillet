import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feuillet/utils/display_settings.dart';

void main() {
  group('DisplaySettings', () {
    test('default values are correct', () {
      const settings = DisplaySettings();

      expect(settings.zoomLevel, 1.0);
      expect(settings.brightness, 0.0);
      expect(settings.contrast, 1.0);
    });

    test('defaults constant has default values', () {
      expect(DisplaySettings.defaults.zoomLevel, 1.0);
      expect(DisplaySettings.defaults.brightness, 0.0);
      expect(DisplaySettings.defaults.contrast, 1.0);
    });

    test('custom values are stored correctly', () {
      const settings = DisplaySettings(
        zoomLevel: 2.0,
        brightness: 0.3,
        contrast: 1.5,
      );

      expect(settings.zoomLevel, 2.0);
      expect(settings.brightness, 0.3);
      expect(settings.contrast, 1.5);
    });

    group('copyWith', () {
      test('creates new instance with updated zoomLevel', () {
        const original = DisplaySettings();
        final updated = original.copyWith(zoomLevel: 2.5);

        expect(updated.zoomLevel, 2.5);
        expect(updated.brightness, original.brightness);
        expect(updated.contrast, original.contrast);
      });

      test('creates new instance with updated brightness', () {
        const original = DisplaySettings();
        final updated = original.copyWith(brightness: 0.2);

        expect(updated.zoomLevel, original.zoomLevel);
        expect(updated.brightness, 0.2);
        expect(updated.contrast, original.contrast);
      });

      test('creates new instance with updated contrast', () {
        const original = DisplaySettings();
        final updated = original.copyWith(contrast: 1.8);

        expect(updated.zoomLevel, original.zoomLevel);
        expect(updated.brightness, original.brightness);
        expect(updated.contrast, 1.8);
      });

      test('creates new instance with multiple updated values', () {
        const original = DisplaySettings();
        final updated = original.copyWith(
          zoomLevel: 1.5,
          brightness: -0.2,
          contrast: 0.8,
        );

        expect(updated.zoomLevel, 1.5);
        expect(updated.brightness, -0.2);
        expect(updated.contrast, 0.8);
      });
    });

    group('createColorMatrix', () {
      test('returns list of 20 elements', () {
        const settings = DisplaySettings();
        final matrix = settings.createColorMatrix();

        expect(matrix.length, 20);
      });

      test('applies correct brightness offset', () {
        const settings = DisplaySettings(brightness: 0.1);
        final matrix = settings.createColorMatrix();

        // Brightness offset is brightness * 255
        expect(matrix[4], 0.1 * 255); // Red offset
        expect(matrix[9], 0.1 * 255); // Green offset
        expect(matrix[14], 0.1 * 255); // Blue offset
      });

      test('applies correct contrast scale', () {
        const settings = DisplaySettings(contrast: 1.5);
        final matrix = settings.createColorMatrix();

        expect(matrix[0], 1.5); // Red scale
        expect(matrix[6], 1.5); // Green scale
        expect(matrix[12], 1.5); // Blue scale
      });

      test('alpha channel is unchanged', () {
        const settings = DisplaySettings(brightness: 0.5, contrast: 2.0);
        final matrix = settings.createColorMatrix();

        expect(matrix[18], 1.0); // Alpha scale
        expect(matrix[19], 0.0); // Alpha offset
      });
    });

    group('colorFilter', () {
      test('returns ColorFilter with correct matrix', () {
        const settings = DisplaySettings(brightness: 0.1, contrast: 1.2);
        final filter = settings.colorFilter;

        expect(filter, isA<ColorFilter>());
      });
    });

    group('isDefault', () {
      test('returns true for default values', () {
        const settings = DisplaySettings();

        expect(settings.isDefault, isTrue);
      });

      test('returns false when zoomLevel is not default', () {
        const settings = DisplaySettings(zoomLevel: 1.5);

        expect(settings.isDefault, isFalse);
      });

      test('returns false when brightness is not default', () {
        const settings = DisplaySettings(brightness: 0.1);

        expect(settings.isDefault, isFalse);
      });

      test('returns false when contrast is not default', () {
        const settings = DisplaySettings(contrast: 1.2);

        expect(settings.isDefault, isFalse);
      });
    });

    group('equality', () {
      test('equal instances are equal', () {
        const a = DisplaySettings(zoomLevel: 1.5, brightness: 0.2);
        const b = DisplaySettings(zoomLevel: 1.5, brightness: 0.2);

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different instances are not equal', () {
        const a = DisplaySettings(zoomLevel: 1.5);
        const b = DisplaySettings(zoomLevel: 2.0);

        expect(a, isNot(equals(b)));
      });
    });

    group('constants', () {
      test('zoom range is valid', () {
        expect(DisplaySettings.minZoom, 0.5);
        expect(DisplaySettings.maxZoom, 3.0);
        expect(DisplaySettings.minZoom, lessThan(DisplaySettings.maxZoom));
      });

      test('brightness range is valid', () {
        expect(DisplaySettings.minBrightness, -0.5);
        expect(DisplaySettings.maxBrightness, 0.5);
        expect(
          DisplaySettings.minBrightness,
          lessThan(DisplaySettings.maxBrightness),
        );
      });

      test('contrast range is valid', () {
        expect(DisplaySettings.minContrast, 0.5);
        expect(DisplaySettings.maxContrast, 2.0);
        expect(
          DisplaySettings.minContrast,
          lessThan(DisplaySettings.maxContrast),
        );
      });
    });

    test('toString returns useful representation', () {
      const settings = DisplaySettings(
        zoomLevel: 1.5,
        brightness: 0.2,
        contrast: 1.3,
      );

      expect(settings.toString(), contains('1.5'));
      expect(settings.toString(), contains('0.2'));
      expect(settings.toString(), contains('1.3'));
    });
  });
}
