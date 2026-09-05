import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../data_layer/Models/app_models.dart';

class PlannerPdfService {
  Future<Uint8List> create({
    required String planName,
    required List<PlanDay> days,
  }) async {
    final document = pw.Document(title: planName, author: 'FindIt My');
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(34),
        build: (_) => <pw.Widget>[
          pw.Text(
            planName,
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            '${days.length} day travel itinerary',
            style: const pw.TextStyle(color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 20),
          ...days.expand(
            (day) => <pw.Widget>[
              pw.Header(
                level: 1,
                text:
                    '${day.label}  ${day.date.year}-${day.date.month.toString().padLeft(2, '0')}-${day.date.day.toString().padLeft(2, '0')}',
              ),
              if (day.activities.isEmpty)
                pw.Text('No activities planned.')
              else
                ...day.activities.map(
                  (a) => pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 8),
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: <pw.Widget>[
                        pw.Text(
                          '${a.time}  ${a.title}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(a.location),
                        pw.Text(
                          a.category,
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                          ),
                        ),
                        if (a.notes.isNotEmpty) pw.Text(a.notes),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
    return document.save();
  }
}
