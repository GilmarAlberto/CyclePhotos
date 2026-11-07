import 'package:cyclephotos/tamanho.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatarTamanho', () {
    expect(formatarTamanho(512), '512 B');
    expect(formatarTamanho(850 * 1024), '850 KB');
    expect(formatarTamanho((3.4 * 1024 * 1024).round()), '3,4 MB');
    expect(formatarTamanho((1.25 * 1024 * 1024 * 1024).round()), '1,25 GB');
  });
}
