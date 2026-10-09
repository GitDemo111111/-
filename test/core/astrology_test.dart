import 'package:birthday_keeper/core/astrology.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('constellationOf', () {
    test('每个星座的起点', () {
      expect(constellationOf(1, 20), '水瓶座');
      expect(constellationOf(2, 19), '双鱼座');
      expect(constellationOf(3, 21), '白羊座');
      expect(constellationOf(4, 20), '金牛座');
      expect(constellationOf(5, 21), '双子座');
      expect(constellationOf(6, 22), '巨蟹座');
      expect(constellationOf(7, 23), '狮子座');
      expect(constellationOf(8, 23), '处女座');
      expect(constellationOf(9, 23), '天秤座');
      expect(constellationOf(10, 24), '天蝎座');
      expect(constellationOf(11, 23), '射手座');
      expect(constellationOf(12, 22), '摩羯座');
    });

    test('起点前一天属于上一个星座', () {
      expect(constellationOf(1, 19), '摩羯座');
      expect(constellationOf(5, 20), '金牛座');
      expect(constellationOf(12, 21), '射手座');
      expect(constellationOf(2, 18), '水瓶座');
    });

    test('年初属于摩羯座', () {
      expect(constellationOf(1, 1), '摩羯座');
    });
  });

  group('chineseZodiacOf', () {
    test('已知年份', () {
      expect(chineseZodiacOf(1984), '鼠');
      expect(chineseZodiacOf(1990), '马');
      expect(chineseZodiacOf(2000), '龙');
      expect(chineseZodiacOf(2024), '龙');
      expect(chineseZodiacOf(2025), '蛇');
      expect(chineseZodiacOf(2026), '马');
    });

    test('12 年一轮回', () {
      expect(chineseZodiacOf(1990), chineseZodiacOf(2002));
      expect(chineseZodiacOf(1990), chineseZodiacOf(1978));
    });

    test('公元 4 年之前也不会取到负数下标', () {
      expect(chineseZodiacOf(3), isNotEmpty);
      expect(chineseZodiacOf(1), isNotEmpty);
    });
  });
}
