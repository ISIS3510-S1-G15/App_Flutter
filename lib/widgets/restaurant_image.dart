import 'dart:io';
import 'package:flutter/material.dart';
import '../models/restaurant.dart';
import '../services/image_disk_cache.dart';
import '../theme/app_theme.dart';

// The picture of a restaurant, used by every screen.
// - If the backend sends image_url, the picture is downloaded once and kept on disk (ImageDiskCache),
//   so it also shows without internet after the first time.
// - Otherwise the bundled picture of its image_key is used.
// - While loading, or with no internet and no saved copy, a placeholder with an icon is drawn
//   instead of an empty gap.
class RestaurantImage extends StatefulWidget {
  final Restaurant restaurant;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color? placeholderColor;

  const RestaurantImage(
    this.restaurant, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholderColor,
  });

  @override
  State<RestaurantImage> createState() => _RestaurantImageState();
}

class _RestaurantImageState extends State<RestaurantImage> {
  Future<File?>? _file;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(RestaurantImage old) {
    super.didUpdateWidget(old);
    if (old.restaurant.imageUrl != widget.restaurant.imageUrl) _load();
  }

  void _load() {
    final url = widget.restaurant.imageUrl;
    _file = url == null ? null : ImageDiskCache.instance.file(url);
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.restaurant.imageUrl;
    if (url == null) return _asset();

    final cached = ImageDiskCache.instance.peek(url);
    if (cached != null) return _fromFile(cached);

    return FutureBuilder<File?>(
      future: _file,
      builder: (context, snap) {
        final file = snap.data;
        if (file != null) return _fromFile(file);
        return _placeholder(loading: snap.connectionState != ConnectionState.done);
      },
    );
  }

  Widget _asset() => Image.asset(
        widget.restaurant.image,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (_, _, _) => _placeholder(),
      );

  Widget _fromFile(File file) => Image.file(
        file,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (_, _, _) => _placeholder(),
      );

  Widget _placeholder({bool loading = false}) {
    final small = (widget.width ?? double.infinity) < 80 || (widget.height ?? double.infinity) < 80;
    return Container(
      width: widget.width,
      height: widget.height,
      color: widget.placeholderColor ?? AppColors.closed.withValues(alpha: 0.3),
      alignment: Alignment.center,
      child: loading
          ? null
          : Icon(Icons.restaurant, color: AppColors.muted, size: small ? 22 : 36),
    );
  }
}
