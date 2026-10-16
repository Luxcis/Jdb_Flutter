/// MissAV 页面解析：番号规范化、Dean Edwards packer 解码与 surrit 播放列表提取。
///
/// 算法与 `docs/main/missav/player.html` 的 `unesc` / `radix` / `unpack` /
/// `extractSurritMaster` / `normalizeCode` 等价移植；radix 取页面实际值（16/38/62
/// 等通用进制），不限于来源注释里的 16/62。
library;

const _alphabet = '0123456789abcdefghijklmnopqrstuvwxyz';

final _packerPattern = RegExp(
  r"eval\(function\(p,a,c,k,e,d\).*?\}\(\s*'(.*?)'\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*'(.*?)'\s*\.split\('\|'\)\s*,\s*0\s*,\s*\{\}\s*\)\)",
  dotAll: true,
  multiLine: true,
);

final _surritUuidPattern = RegExp(
  r'surrit\.com/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})',
);

/// 把任意形态输入规范化为 missav 番号（小写、无空白）。
///
/// 支持完整 missav 链接（含语言段与路径）与纯番号；无法识别路径形态时按
/// 纯番号处理（去空白、转小写）。
String normalizeMissavCode(String input) {
  final value = input.trim();
  if (value.isEmpty) return '';
  final linkMatch =
      RegExp(
        r'missav[^/]*/[a-z-]{0,6}/([\w-]+)',
        caseSensitive: false,
      ).firstMatch(value) ??
      RegExp(
        r'https?://[^/]+/([\w-]+)/?$',
        caseSensitive: false,
      ).firstMatch(value) ??
      RegExp(r'/([\w-]+)/?$').firstMatch(value);
  if (linkMatch != null) return linkMatch.group(1)!.toLowerCase();
  return value
      .replaceAll(RegExp(r'\s+'), '')
      .toLowerCase()
      .replaceFirst(RegExp(r'^https?://'), '');
}

/// 从页面 HTML 中提取 surrit master 播放列表地址；找不到时返回 `null`。
///
/// 先在页面原文与全部 packer 解码产物中查找 `surrit.com/{uuid}`，取第一个
/// 匹配并还原为 `https://surrit.com/{uuid}/playlist.m3u8`。
String? extractSurritMasterUrl(String html) {
  var decoded = html;
  for (final match in _packerPattern.allMatches(html)) {
    try {
      final unpacked = unpackPackerScript(
        match.group(1)!,
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
        match.group(4)!,
      );
      decoded += '\n$unpacked';
    } on Object {
      // 单个 packer 解码失败不影响其他块与原文兜底。
    }
  }
  final uuid = _surritUuidPattern.firstMatch(decoded)?.group(1);
  if (uuid == null) return null;
  return 'https://surrit.com/$uuid/playlist.m3u8';
}

/// 解码一个 packer 脚本（`p`、`a`、`c`、`k` 为 `eval(function(p,a,c,k,e,d)…)`
/// 的对应实参）。
String unpackPackerScript(
  String payload,
  int radixBase,
  int count,
  String keywords,
) {
  var source = _unescape(payload);
  final table = <String, String>{};
  final parts = keywords.split('|');
  for (var index = 0; index < count; index++) {
    final token = radixBase == 10 ? '$index' : _radix(index, radixBase);
    table[token] = (index < parts.length && parts[index].isNotEmpty)
        ? parts[index]
        : token;
  }
  final tokens = table.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  final pattern = RegExp(
    r'\b(?:' + tokens.map((token) => RegExp.escape(token)).join('|') + r')\b',
    multiLine: true,
  );
  source = source.replaceAllMapped(
    pattern,
    (match) => table[match.group(0)] ?? match.group(0)!,
  );
  return source;
}

String _unescape(String source) {
  final buffer = StringBuffer();
  var index = 0;
  while (index < source.length) {
    final char = source[index];
    if (char == r'\' && index + 1 < source.length) {
      final next = source[index + 1];
      const simple = {'n': '\n', 't': '\t', 'r': '\r', '0': '\x00'};
      if (simple.containsKey(next)) {
        buffer.write(simple[next]);
        index += 2;
        continue;
      }
      if (next == 'x' && index + 4 <= source.length) {
        final code = int.tryParse(
          source.substring(index + 2, index + 4),
          radix: 16,
        );
        if (code != null) {
          buffer.writeCharCode(code);
          index += 4;
          continue;
        }
      }
      if (next == 'u' && index + 6 <= source.length) {
        final code = int.tryParse(
          source.substring(index + 2, index + 6),
          radix: 16,
        );
        if (code != null) {
          buffer.writeCharCode(code);
          index += 6;
          continue;
        }
      }
      buffer.write(next);
      index += 2;
      continue;
    }
    buffer.write(char);
    index += 1;
  }
  return buffer.toString();
}

String _radix(int value, int radixBase) {
  final digits = <int>[];
  var current = value;
  do {
    final remainder = current % radixBase;
    digits.add(
      remainder > 35 ? remainder + 29 : _alphabet.codeUnitAt(remainder),
    );
    current ~/= radixBase;
  } while (current != 0);
  return String.fromCharCodes(digits.reversed);
}
