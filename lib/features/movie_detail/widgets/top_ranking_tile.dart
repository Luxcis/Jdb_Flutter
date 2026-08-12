import 'package:flutter/material.dart';

/// 榜单行：左半金黄色渐变序号 + 右半灰色渐变榜单名。
///
/// 样式复刻官方客户端（left_bg/right_bg 素材的竖渐变与圆角）：
/// 左半 60x24（#F6CD90→#F1C17A→#EDB765、左侧圆角），
/// 右半 150x24（#747474→#616161→#505050、右侧圆角），
/// 文字 fontSize 12 / FontWeight.w400 / height 1.5 / 居中，颜色固定不随主题变化。
class TopRankingTile extends StatelessWidget {
  const TopRankingTile({super.key, required this.ranking, required this.title});

  final int? ranking;
  final String title;

  static const Color _leftTextColor = Color(0xFF9F6000);
  static const Color _rightTextColor = Color(0xFFFFCA7A);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHalf(
          width: 60,
          colors: const [
            Color(0xFFF6CD90),
            Color(0xFFF1C17A),
            Color(0xFFEDB765),
          ],
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(4)),
          child: Text(
            'No.${ranking ?? ''}',
            style: const TextStyle(
              color: _leftTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
          ),
        ),
        _buildHalf(
          width: 150,
          colors: const [
            Color(0xFF747474),
            Color(0xFF616161),
            Color(0xFF505050),
          ],
          borderRadius: const BorderRadius.horizontal(
            right: Radius.circular(4),
          ),
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _rightTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHalf({
    required double width,
    required List<Color> colors,
    required BorderRadius borderRadius,
    required Widget child,
  }) {
    return Container(
      width: width,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }
}
