import 'fade_in_slide.dart' as shared;

class FadeInSlide extends shared.FadeInSlide {
  const FadeInSlide({
    super.key,
    required super.child,
    super.duration = const Duration(milliseconds: 500),
    super.delay = Duration.zero,
    super.slideOffset = 30.0,
  });
}

class BounceOnTap extends shared.BounceOnTap {
  const BounceOnTap({
    super.key,
    required super.child,
    required super.onTap,
  }) : super(scaleFactor: 0.95);
}