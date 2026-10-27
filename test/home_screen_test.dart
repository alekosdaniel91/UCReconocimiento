import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uc_reconocimiento/main.dart';

void main() {
  testWidgets('home shows the Koolnova unit and the main actions', (
    tester,
  ) async {
    await tester.pumpWidget(const UcReconocimientoApp());
    await tester.pumpAndSettle();

    expect(find.text('Radio Central Unit HYBRID'), findsOneWidget);
    expect(find.text('Identificar puertos'), findsOneWidget);
    expect(find.text('Instalación guiada'), findsOneWidget);

    await tester.ensureVisible(find.text('Catálogo de puertos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Catálogo de puertos'));
    await tester.pumpAndSettle();
    expect(find.text('Lateral de ZONAS'), findsOneWidget);
    expect(find.byType(ListTile), findsWidgets);
  });
}
