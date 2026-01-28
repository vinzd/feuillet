import 'package:flutter/material.dart';
import '../models/database.dart';

/// Card widget to display a PDF in the library grid view
class PdfCard extends StatelessWidget {
  final Document document;
  final VoidCallback onTap;

  const PdfCard({
    super.key,
    required this.document,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail area (placeholder for now)
            Expanded(
              child: Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(
                  Icons.picture_as_pdf,
                  size: 64,
                ),
              ),
            ),

            // PDF info
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.name,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${document.pageCount} pages',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.color
                              ?.withOpacity(0.6),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
