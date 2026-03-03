import 'package:path/path.dart' as p;
import 'annotation_service.dart';

/// Given a score file name (e.g., "Bach - Suite 1.pdf"), returns the
/// corresponding sidecar file name ("Bach - Suite 1.feuillet.json").
///
/// Works with both bare file names and full paths.
String sidecarFileName(String scoreFileName) {
  final dir = p.dirname(scoreFileName);
  final baseName = p.basenameWithoutExtension(scoreFileName);
  final sidecar = '$baseName.feuillet.json';
  if (dir == '.' && !scoreFileName.contains(p.separator)) {
    return sidecar;
  }
  return p.join(dir, sidecar);
}

/// Holds the strokes for a single page within a sidecar layer.
class SidecarPageAnnotations {
  final int pageNumber;
  final List<DrawingStroke> strokes;

  SidecarPageAnnotations({required this.pageNumber, required this.strokes});

  Map<String, dynamic> toJson() => {
    'pageNumber': pageNumber,
    'strokes': strokes.map((s) => s.toJson()).toList(),
  };

  factory SidecarPageAnnotations.fromJson(Map<String, dynamic> json) {
    return SidecarPageAnnotations(
      pageNumber: json['pageNumber'] as int,
      strokes: (json['strokes'] as List)
          .map((s) => DrawingStroke.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Represents a single annotation layer in a sidecar file.
class SidecarLayer {
  final String name;
  final bool isVisible;
  final int orderIndex;
  final List<SidecarPageAnnotations> annotations;

  SidecarLayer({
    required this.name,
    required this.isVisible,
    required this.orderIndex,
    required this.annotations,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'isVisible': isVisible,
    'orderIndex': orderIndex,
    'annotations': annotations.map((a) => a.toJson()).toList(),
  };

  factory SidecarLayer.fromJson(Map<String, dynamic> json) {
    return SidecarLayer(
      name: json['name'] as String,
      isVisible: json['isVisible'] as bool,
      orderIndex: json['orderIndex'] as int,
      annotations: (json['annotations'] as List)
          .map(
            (a) => SidecarPageAnnotations.fromJson(a as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

/// Top-level sidecar file data model for annotation sync via Syncthing.
class AnnotationSidecar {
  final int version;
  final DateTime modifiedAt;
  final List<SidecarLayer> layers;

  AnnotationSidecar({
    required this.version,
    required this.modifiedAt,
    required this.layers,
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'modifiedAt': modifiedAt.toUtc().toIso8601String(),
    'layers': layers.map((l) => l.toJson()).toList(),
  };

  factory AnnotationSidecar.fromJson(Map<String, dynamic> json) {
    return AnnotationSidecar(
      version: json['version'] as int,
      modifiedAt: DateTime.parse(json['modifiedAt'] as String),
      layers: (json['layers'] as List)
          .map((l) => SidecarLayer.fromJson(l as Map<String, dynamic>))
          .toList(),
    );
  }
}
