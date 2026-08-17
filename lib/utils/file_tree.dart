import '../models/database.dart';

class FileTreeNode {
  final String name;
  final String path;
  final Document? document;
  final List<FileTreeNode> children;

  const FileTreeNode({
    required this.name,
    required this.path,
    this.document,
    this.children = const [],
  });

  bool get isFolder => document == null;
}

List<FileTreeNode> buildFileTree(List<Document> documents) {
  if (documents.isEmpty) return const [];

  final paths = documents
      .map((document) => _pathSegments(document.filePath))
      .toList();
  final commonDirectory = _commonPrefixLength(
    paths
        .map((segments) => segments.take(segments.length - 1).toList())
        .toList(),
  );
  final root = _MutableTreeNode(name: '', path: '');

  for (var index = 0; index < documents.length; index++) {
    final document = documents[index];
    final segments = paths[index];
    final relativeDirectories = segments
        .take(segments.length - 1)
        .skip(commonDirectory)
        .toList();
    var current = root;
    var currentPath = '';
    for (final directory in relativeDirectories) {
      currentPath = currentPath.isEmpty ? directory : '$currentPath/$directory';
      current = current.children.putIfAbsent(
        directory,
        () => _MutableTreeNode(name: directory, path: currentPath),
      );
    }
    final fileName = document.name;
    final filePath = currentPath.isEmpty ? fileName : '$currentPath/$fileName';
    current.children.putIfAbsent(
      fileName,
      () =>
          _MutableTreeNode(name: fileName, path: filePath, document: document),
    );
  }

  return _sortNodes(root.children.values.map((node) => node.toNode()).toList());
}

List<String> _pathSegments(String filePath) {
  return filePath
      .replaceAll('\\', '/')
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toList();
}

int _commonPrefixLength(List<List<String>> paths) {
  if (paths.isEmpty || paths.any((path) => path.isEmpty)) return 0;
  var length = paths.first.length;
  for (final path in paths.skip(1)) {
    length = length < path.length ? length : path.length;
    for (var index = 0; index < length; index++) {
      if (path[index] != paths.first[index]) {
        length = index;
        break;
      }
    }
  }
  return length;
}

List<FileTreeNode> _sortNodes(List<FileTreeNode> nodes) {
  nodes.sort((a, b) {
    if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return nodes;
}

class _MutableTreeNode {
  final String name;
  final String path;
  final Document? document;
  final Map<String, _MutableTreeNode> children = {};

  _MutableTreeNode({required this.name, required this.path, this.document});

  FileTreeNode toNode() {
    return FileTreeNode(
      name: name,
      path: path,
      document: document,
      children: _sortNodes(
        children.values.map((child) => child.toNode()).toList(),
      ),
    );
  }
}
