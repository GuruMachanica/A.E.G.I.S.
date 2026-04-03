import 'package:aegis_app/widgets/aegis_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders aegis logo widget', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: AegisLogo(size: 64)),
        ),
      ),
    );

    expect(find.byType(AegisLogo), findsOneWidget);
  });
}
