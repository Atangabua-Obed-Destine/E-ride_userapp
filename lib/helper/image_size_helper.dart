import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// How wide to decode a network image so it stays sharp in its box without
/// holding the full upload in memory. Uploads are up to 2500 px (about 18 MB
/// decoded each), which on a 2 GB phone runs out of memory after a few dozen.
class ImageSizeHelper {
  /// Pixels to decode for a box of [width] x [height] (logical). With cover, a
  /// photo up to twice as wide as tall still fills the box's height.
  /// Null (decode as is) when the box size is unknown.
  static int? decodeWidth(BuildContext context, double? width, double? height, {bool cover = true}) {
    final double ratio = MediaQuery.devicePixelRatioOf(context);
    final double screen = MediaQuery.sizeOf(context).width;
    final double w = (width != null && width.isFinite) ? width : screen;
    final double h = (height != null && height.isFinite) ? height : 0;
    final double logical = cover ? math.max(w, h * 2) : w;
    if (logical <= 0) return null;
    return (math.min(logical, screen * 1.5) * ratio).round();
  }
}
