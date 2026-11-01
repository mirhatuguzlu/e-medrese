import 'package:e_medrese/presentation/widgets/tile_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (width, columns) in [(360.0, 2), (600.0, 3), (1000.0, 4)]) {
    testWidgets('$width genişlikte $columns sütun', (tester) async {
      tester.view
        ..physicalSize = Size(width, 1600)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                TileGrid(
                  children: [
                    for (var i = 0; i < 4; i++)
                      TileCard(
                        icon: const Icon(Icons.campaign_outlined),
                        title: 'Duyurular',
                        subtitle: 'Hocaların duyuruları',
                        onTap: (_) {},
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, columns);
    });
  }
}
