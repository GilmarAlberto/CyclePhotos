import 'package:flutter_test/flutter_test.dart';
import 'package:cyclephotos/album_page.dart';

void main() {
  test('duracaoTexto formata minutos e segundos', () {
    expect(duracaoTexto(const Duration(seconds: 75)), '1:15');
    expect(duracaoTexto(const Duration(seconds: 5)), '0:05');
  });
}
