import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// PDF'i uygulama içinde gösterir.
class PdfPage extends StatelessWidget {
  /// [url]'deki PDF, başlıkta [title].
  const PdfPage({required this.title, required this.url, super.key});

  /// Başlık.
  final String title;

  /// İndirme adresi.
  final String url;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: SfPdfViewer.network(url),
  );
}
