import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aplicacion_moviles/api_service.dart';
import 'package:aplicacion_moviles/main.dart';

void main() {
  testWidgets('muestra el acceso y abre el catálogo reutilizable', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(MyApp(apiService: ApiService()));

    expect(find.text('Baquero Notes'), findsOneWidget);
    expect(find.text('Inicia sesión'), findsOneWidget);
    expect(find.bySemanticsLabel('Correo electrónico'), findsOneWidget);
    expect(find.bySemanticsLabel('Contraseña'), findsOneWidget);

    await tester.tap(find.text('Ver catálogo de componentes'));
    await tester.pumpAndSettle();

    expect(find.text('Catálogo de componentes'), findsOneWidget);
    expect(find.text('AppButton'), findsOneWidget);
    expect(find.text('AppTextField'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('admite fuente ampliada sin bloquear el desplazamiento', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaleFactor: 1.5),
        child: MyApp(apiService: ApiService()),
      ),
    );

    expect(find.byType(Scrollable), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
