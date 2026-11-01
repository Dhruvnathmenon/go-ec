import 'dart:math' as math;
import 'dart:ui';

/// Brand colours, measured from the current splash screen and the logo PNG.
class GoEcColors {
  static const blue = Color(0xFF003DBA);
  static const green = Color(0xFF11EDAF);
  static const white = Color(0xFFFFFFFF);
}

/// The Go EC logo rebuilt as geometry.
///
/// Units are pixels of the master PNG at half size (4875 x 4875), so every number
/// here can be checked against "goec logo rgb.png" divided by 2. Change a number
/// and the shape follows; nothing is traced except the two tagline words.
class GoEcGeometry {
  GoEcGeometry._();

  // Big G mark. Drawn upright with the cord horizontal, then rotated by [tiltDeg].
  static const markCenter = Offset(1267.05, 1889.69);
  static const markR = 1192.0;
  static const markInnerR = 783.0;
  static const tiltDeg = -34.25; // negative = counter-clockwise on screen
  static const gapTop = -329.0, gapBottom = -176.0; // band cut out of the ring's upper right
  static const cordX0 = 140.0, cordX1 = 900.0, cordY0 = -176.0, cordY1 = 230.0;
  static const cordRoot = 790.0; // where the cord leaves the ring
  static const bodyX0 = -155.0, bodyX1 = 157.0, bodyY0 = -257.0, bodyY1 = 302.0, bodyRadius = 7.0;
  // Prongs: y top, y bottom, x of the rounded tip.
  static const prongs = <List<double>>[
    [-156, -90, -385],
    [-12, 52, -277],
    [136, 200, -387],
  ];
  static const bolt = <Offset>[
    Offset(-114, -13), Offset(4, 10), Offset(4, -34), Offset(141, -11),
    Offset(141, 70), Offset(48, 25), Offset(45, 73),
  ];
  // Widest solid spot inside the bolt: where the camera dives, and how much room it has.
  static const boltCore = Offset(100, 18);
  static const boltCoreRadius = 27.0;

  // The four letter rings share one ring size.
  static const ringR = 501.5, ringInnerR = 331.0;
  static const letterG = Offset(3201, 1340);
  static const letterO = Offset(4297, 1340);
  static const letterE = Offset(3201, 2440); // the g mirrored top to bottom
  static const letterC = Offset(4299, 2440);
  static const gGapTop = -143.0, gGapBottom = -72.0; // band cut from the g's upper right
  static const gBarTop = -72.0, gBarBottom = 93.0, gBarCapX = 21.0;
  static const cGap = 88.0; // half height of the c's opening
  static const hingeY = 1890.0; // line between the g and the e; the e flips on it

  // Lockup area in source units, and how it sits on screen (matches the current splash).
  static const box = Rect.fromLTWH(60, 690, 4760, 3660);
  static const widthShare = 0.4836; // box width / screen width
  static const centerYShare = 0.477; // box centre / screen height

  // Tagline placement: words are traced at the PNG's position, then moved here.
  static const taglineCenterX = 2438.0, taglineTop = 3866.0, taglineScale = 1.057;

  static double _xOn(double radius, double y) => math.sqrt(radius * radius - y * y);

  /// Ring with a horizontal band [yTop, yBottom] removed on the right, centred at 0,0.
  static Path openRing(double r1, double r2, double yTop, double yBottom) {
    return Path()
      ..moveTo(_xOn(r1, yBottom), yBottom)
      ..arcToPoint(Offset(_xOn(r1, yTop), yTop), radius: Radius.circular(r1), largeArc: true, clockwise: true)
      ..lineTo(_xOn(r2, yTop), yTop)
      ..arcToPoint(Offset(_xOn(r2, yBottom), yBottom), radius: Radius.circular(r2), largeArc: true, clockwise: false)
      ..close();
  }

  // Solid shapes wind clockwise on screen; the bolt winds the other way so it cuts a hole.
  static void _rect(Path p, double x0, double y0, double x1, double y1) {
    p
      ..moveTo(x0, y0)
      ..lineTo(x1, y0)
      ..lineTo(x1, y1)
      ..lineTo(x0, y1)
      ..close();
  }

  static void _roundRect(Path p, double x0, double y0, double x1, double y1, double k) {
    final r = Radius.circular(k);
    p
      ..moveTo(x0 + k, y0)
      ..lineTo(x1 - k, y0)
      ..arcToPoint(Offset(x1, y0 + k), radius: r)
      ..lineTo(x1, y1 - k)
      ..arcToPoint(Offset(x1 - k, y1), radius: r)
      ..lineTo(x0 + k, y1)
      ..arcToPoint(Offset(x0, y1 - k), radius: r)
      ..lineTo(x0, y0 + k)
      ..arcToPoint(Offset(x0 + k, y0), radius: r)
      ..close();
  }

  static void _prong(Path p, double y0, double y1, double tip, double xEnd) {
    final k = (y1 - y0) / 2, cx = tip + k;
    p
      ..moveTo(cx, y0)
      ..lineTo(xEnd, y0)
      ..lineTo(xEnd, y1)
      ..lineTo(cx, y1)
      ..arcToPoint(Offset(cx, y0), radius: Radius.circular(k))
      ..close();
  }

  static void _polygon(Path p, List<Offset> pts, {required bool hole}) {
    var area = 0.0;
    for (var i = 0; i < pts.length; i++) {
      final a = pts[i], b = pts[(i + 1) % pts.length];
      area += a.dx * b.dy - b.dx * a.dy;
    }
    final list = (area > 0) == !hole ? pts : pts.reversed.toList();
    p.moveTo(list.first.dx, list.first.dy);
    for (final q in list.skip(1)) {
      p.lineTo(q.dx, q.dy);
    }
    p.close();
  }

  // ---- Mark, in its upright frame (cord along +x), centred at the ring centre.
  static final Path ring = openRing(markR, markInnerR, gapTop, gapBottom);
  static final Path cord = () {
    final p = Path();
    _rect(p, cordX0, cordY0, cordX1, cordY1);
    return p;
  }();
  static final Path plug = () {
    final p = Path();
    _roundRect(p, bodyX0, bodyY0, bodyX1, bodyY1, bodyRadius);
    for (final pr in prongs) {
      _prong(p, pr[0], pr[1], pr[2], bodyX0 + 5);
    }
    _polygon(p, bolt, hole: true);
    return p;
  }();
  static final Path boltShape = () {
    final p = Path();
    _polygon(p, bolt, hole: false);
    return p;
  }();

  // ---- Letters, each centred at 0,0.
  static final Path gLetter = () {
    const big = Radius.circular(ringR), small = Radius.circular(ringInnerR);
    final k = (gBarBottom - gBarTop) / 2;
    return Path()
      ..moveTo(_xOn(ringR, gGapTop), gGapTop)
      ..arcToPoint(Offset(_xOn(ringR, gBarTop), gBarTop), radius: big, largeArc: true, clockwise: false)
      ..lineTo(gBarCapX, gBarTop)
      ..arcToPoint(Offset(gBarCapX, gBarBottom), radius: Radius.circular(k), clockwise: false)
      ..lineTo(_xOn(ringInnerR, gBarBottom), gBarBottom)
      ..arcToPoint(Offset(_xOn(ringInnerR, gGapTop), gGapTop), radius: small, largeArc: true, clockwise: true)
      ..close();
  }();
  static final Path cLetter = openRing(ringR, ringInnerR, -cGap, cGap);
  static final Path oLetter = Path()
    ..fillType = PathFillType.evenOdd
    ..addOval(Rect.fromCircle(center: Offset.zero, radius: ringR))
    ..addOval(Rect.fromCircle(center: Offset.zero, radius: ringInnerR));

  // ---- Tagline words, traced from the PNG as polygons (source units).
  static final Path powering = _parse(_poweringData);
  static final Path future = _parse(_futureData);
  static final Rect taglineBounds = powering.getBounds().expandToInclude(future.getBounds());

  /// Reads the traced word data: "M x y x y ... Z" polygons, even-odd filled.
  static Path _parse(String d) {
    final p = Path()..fillType = PathFillType.evenOdd;
    final tokens = RegExp(r'[MZ]|-?\d+(?:\.\d+)?').allMatches(d).map((m) => m.group(0)!).toList();
    var i = 0;
    var first = true;
    while (i < tokens.length) {
      final t = tokens[i];
      if (t == 'M') {
        first = true;
        i++;
      } else if (t == 'Z') {
        p.close();
        i++;
      } else {
        final x = double.parse(tokens[i]), y = double.parse(tokens[i + 1]);
        if (first) {
          p.moveTo(x, y);
          first = false;
        } else {
          p.lineTo(x, y);
        }
        i += 2;
      }
    }
    return p;
  }

  static const _poweringData =
      'M2568 3475 2549 3483 2525 3501 2510 3522 2500 3544 2495 3568 2493 3601 2497 3634 2504 3658 2518 3683 2536 3704 2558 3717 2583 3724 2614 3724 2636 3718 2659 3704 2676 3686 2679 3685 2680 3705 2678 3742 2672 3759 2660 3772 2647 3780 2633 3783 2604 3784 2583 3780 2568 3770 2546 3745 2531 3738 2520 3739 2508 3747 2502 3758 2502 3772 2510 3787 2524 3800 2546 3814 2566 3821 2599 3827 2633 3827 2669 3821 2694 3811 2715 3796 2728 3778 2737 3752 2742 3716 2742 3509 2739 3492 2736 3483 2727 3474 2720 3472 2705 3472 2697 3475 2688 3484 2684 3498 2684 3511 2680 3512 2657 3490 2634 3477 2607 3472 2589 3472ZM2613 3517 2638 3520 2651 3528 2660 3536 2673 3556 2680 3586 2678 3626 2669 3649 2650 3670 2626 3678 2600 3676 2588 3671 2578 3664 2564 3646 2559 3630 2556 3609 2557 3577 2560 3562 2568 3545 2581 3530 2592 3522ZM2226 3477 2220 3484 2216 3500 2216 3700 2218 3712 2224 3720 2237 3730 2252 3730 2264 3726 2274 3714 2277 3701 2277 3602 2282 3558 2291 3540 2304 3528 2320 3520 2341 3518 2363 3526 2371 3535 2376 3549 2380 3577 2380 3700 2382 3709 2390 3722 2402 3730 2417 3730 2430 3724 2436 3717 2442 3698 2442 3558 2438 3528 2426 3502 2410 3486 2392 3477 2371 3472 2344 3472 2312 3481 2294 3494 2274 3512 2270 3488 2260 3476 2252 3472 2236 3472ZM2024 3477 2004 3472 1974 3474 1961 3480 1938 3508 1936 3508 1934 3492 1928 3480 1919 3473 1898 3472 1890 3475 1881 3486 1876 3506 1876 3698 1882 3718 1894 3728 1912 3730 1921 3728 1928 3722 1936 3710 1938 3694 1939 3590 1944 3558 1954 3539 1961 3531 1970 3526 1986 3524 2028 3533 2038 3529 2046 3521 2050 3507 2046 3494 2034 3482ZM1184 3480 1180 3486 1177 3496 1182 3516 1242 3696 1251 3715 1262 3726 1276 3730 1292 3730 1304 3724 1310 3716 1322 3688 1359 3554 1362 3555 1402 3694 1411 3715 1422 3726 1434 3730 1453 3730 1461 3726 1470 3716 1486 3679 1542 3512 1544 3490 1540 3484 1532 3475 1524 3472 1504 3473 1492 3488 1443 3652 1440 3652 1394 3495 1390 3487 1378 3475 1369 3472 1350 3472 1340 3477 1330 3489 1281 3652 1278 3652 1238 3512 1227 3482 1222 3476 1213 3472 1198 3472ZM992 3473 966 3480 941 3495 925 3509 909 3532 900 3556 894 3586 894 3616 900 3646 910 3672 926 3692 942 3708 958 3717 980 3726 1006 3730 1032 3730 1060 3726 1083 3717 1107 3700 1122 3683 1134 3664 1143 3637 1146 3614 1147 3590 1141 3556 1134 3538 1121 3516 1102 3497 1085 3486 1068 3478 1048 3473ZM1010 3517 1038 3519 1056 3528 1072 3546 1078 3558 1083 3578 1083 3624 1076 3648 1068 3661 1056 3674 1044 3680 1032 3684 1008 3684 992 3678 984 3673 967 3652 958 3624 958 3578 965 3553 974 3538 987 3526ZM2112 3471 2101 3476 2094 3482 2087 3500 2087 3701 2090 3714 2101 3726 2112 3730 2122 3730 2134 3726 2141 3720 2148 3702 2148 3498 2143 3484 2134 3476 2125 3472ZM1664 3475 1640 3484 1618 3499 1602 3516 1590 3539 1582 3562 1578 3587 1580 3622 1586 3654 1599 3679 1612 3695 1632 3712 1654 3722 1693 3730 1731 3730 1760 3722 1790 3706 1806 3690 1814 3677 1816 3666 1815 3656 1811 3650 1800 3644 1788 3645 1784 3647 1755 3674 1737 3684 1717 3690 1695 3690 1672 3681 1655 3664 1646 3646 1642 3630 1642 3617 1773 3616 1790 3614 1806 3609 1815 3601 1820 3586 1820 3568 1814 3542 1804 3522 1793 3507 1776 3492 1760 3482 1740 3475 1712 3470 1693 3470ZM1642 3574 1648 3552 1654 3540 1664 3528 1680 3517 1694 3514 1707 3514 1730 3520 1744 3532 1755 3552 1760 3579 1758 3581 1644 3581ZM807 3396 788 3388 760 3382 628 3381 609 3386 598 3398 592 3418 592 3694 598 3714 611 3728 620 3730 636 3730 648 3722 656 3712 660 3694 661 3590 733 3590 780 3584 801 3576 816 3568 828 3558 839 3542 846 3528 852 3506 852 3470 850 3454 837 3424 824 3408ZM661 3433 735 3433 754 3437 764 3442 778 3458 784 3478 782 3502 776 3515 764 3527 741 3536 716 3539 662 3539ZM2118 3378 2105 3380 2091 3392 2087 3403 2087 3414 2096 3431 2105 3436 2118 3439 2130 3436 2143 3428 2148 3416 2148 3401 2146 3394 2138 3384Z';
  static const _futureData =
      'M4122 3478 4098 3472 4070 3473 4057 3479 4044 3493 4033 3508 4030 3508 4028 3496 4024 3484 4013 3473 3992 3472 3986 3474 3976 3484 3972 3496 3970 3512 3970 3694 3974 3716 3986 3728 3996 3730 4010 3730 4024 3720 4030 3709 4032 3698 4034 3585 4039 3558 4047 3540 4058 3529 4065 3526 4081 3524 4124 3533 4135 3527 4140 3522 4144 3510 4143 3499 4130 3484ZM3890 3476 3880 3471 3868 3471 3855 3477 3846 3488 3843 3500 3843 3602 3840 3642 3834 3656 3819 3672 3800 3681 3791 3683 3778 3683 3761 3677 3752 3668 3744 3653 3740 3619 3740 3504 3735 3486 3728 3477 3716 3472 3696 3473 3685 3482 3678 3502 3678 3648 3684 3684 3690 3695 3706 3713 3721 3722 3742 3729 3765 3730 3785 3728 3798 3724 3816 3714 3842 3690 3845 3688 3850 3716 3863 3728 3872 3730 3885 3730 3898 3720 3904 3701 3904 3502 3901 3488ZM3430 3475 3419 3471 3406 3472 3396 3476 3386 3487 3382 3500 3382 3606 3378 3642 3373 3655 3360 3670 3340 3681 3330 3683 3317 3683 3300 3677 3287 3662 3283 3652 3279 3616 3279 3500 3272 3482 3268 3477 3256 3472 3240 3472 3225 3480 3218 3501 3218 3658 3228 3692 3244 3712 3260 3722 3276 3728 3294 3730 3324 3728 3338 3724 3355 3714 3380 3690 3384 3688 3388 3710 3393 3720 3402 3728 3410 3730 3424 3730 3438 3719 3444 3702 3444 3502 3438 3484ZM4244 3478 4222 3490 4200 3508 4188 3526 4178 3546 4171 3572 4169 3610 4172 3637 4180 3661 4191 3681 4206 3698 4222 3711 4244 3722 4275 3730 4312 3730 4331 3728 4360 3718 4378 3708 4398 3688 4406 3674 4408 3664 4406 3655 4402 3650 4390 3644 4376 3646 4347 3672 4328 3684 4309 3690 4287 3690 4265 3682 4245 3664 4236 3644 4232 3617 4375 3615 4397 3609 4406 3600 4411 3584 4408 3552 4398 3528 4386 3510 4373 3497 4355 3484 4338 3477 4314 3472 4283 3470ZM4233 3575 4242 3544 4254 3528 4270 3517 4298 3514 4315 3518 4324 3523 4336 3534 4347 3556 4350 3580 4234 3581ZM3544 3384 3530 3392 3522 3404 3520 3414 3520 3475 3518 3477 3496 3479 3488 3486 3483 3497 3486 3510 3493 3516 3501 3520 3520 3522 3520 3666 3524 3692 3532 3708 3544 3720 3555 3726 3576 3730 3604 3730 3622 3728 3644 3718 3653 3708 3654 3696 3650 3686 3643 3681 3631 3679 3614 3683 3598 3683 3589 3678 3584 3670 3582 3657 3582 3522 3611 3520 3626 3514 3633 3505 3633 3492 3630 3486 3621 3479 3612 3476 3582 3476 3582 3416 3578 3400 3572 3392 3563 3386 3552 3383ZM3156 3384 3145 3381 2965 3381 2948 3386 2936 3398 2932 3411 2932 3690 2936 3713 2940 3719 2950 3728 2960 3730 2978 3728 2990 3721 2998 3706 3000 3696 3000 3574 3122 3574 3137 3568 3144 3560 3146 3552 3145 3541 3139 3530 3125 3524 3000 3523 2999 3435 3002 3432 3144 3433 3152 3431 3166 3421 3170 3410 3167 3395Z';
}
