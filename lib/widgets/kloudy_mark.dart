import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/kloudy_theme.dart';

/// The compact Kloudy brand mark: a cloud with a path moving upward.
class KloudyMark extends StatelessWidget {
  final double size;

  const KloudyMark({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .105),
      decoration: BoxDecoration(
        color: kKloudyNavy,
        borderRadius: BorderRadius.circular(size * .27),
      ),
      child: SvgPicture.asset('assets/images/kloudy_mark.svg'),
    );
  }
}
