import 'package:flutter/material.dart';

class NewsStyles {
  // Color palette
  static const Color textPrimaryColor = Colors.black;
  static const Color textSecondaryColor = Color(0xFF616161); 
  static const Color textTertiaryColor = Color(0xFF757575); 
  static const Color backgroundLightColor = Colors.white;
  static const Color backgroundGreyColor = Color(0xFFF5F5F5); 
  static const Color overlayDarkColor = Colors.black26;
  static const Color errorColor = Colors.red;
  
  // Shadow properties
  static final defaultShadowColor = Colors.black.withOpacity(0.1);
  static final lightShadowColor = Colors.black.withOpacity(0.05);
  
  // Base text styles
  static const _baseTextStyle = TextStyle(
    fontFamily: 'Default', // You can change this to your app's font
  );
  
  static final _baseTitleStyle = _baseTextStyle.copyWith(
    fontWeight: FontWeight.bold,
  );
  
  static final _baseContentStyle = _baseTextStyle.copyWith(
    height: 1.6,
  );
  
  // Variant text styles
  static final titleStyle = _baseTitleStyle.copyWith(
    color: Colors.white,
    fontSize: 22,
  );

  static final articleTitleStyle = _baseTitleStyle.copyWith(
    fontSize: 22,
    color: textPrimaryColor,
  );

  static final gridTitleStyle = _baseTitleStyle.copyWith(
    fontSize: 14,
    color: textPrimaryColor,
  );

  static final dateStyle = _baseTextStyle.copyWith(
    color: Colors.white70,
    fontSize: 14,
  );

  static final articleDateStyle = _baseTextStyle.copyWith(
    color: textTertiaryColor,
    fontSize: 14,
  );

  static final gridDateStyle = _baseTextStyle.copyWith(
    color: textTertiaryColor,
    fontSize: 10,
  );

  static final excerptStyle = _baseContentStyle.copyWith(
    color: textSecondaryColor,
    fontSize: 14,
  );

  static final gridExcerptStyle = _baseContentStyle.copyWith(
    color: textSecondaryColor,
    fontSize: 12,
  );

  static final contentStyle = _baseContentStyle.copyWith(
    fontSize: 16,
  );

  static final imageCaptionStyle = _baseTextStyle.copyWith(
    fontStyle: FontStyle.italic,
    color: textSecondaryColor,
    fontSize: 12,
  );

  static final noMoreArticlesStyle = _baseTextStyle.copyWith(
    color: textTertiaryColor,
    fontSize: 14,
  );
  
  // NEW: Category label styles
  static final categoryLabelLight = _baseTextStyle.copyWith(
    color: Colors.white,
    fontSize: 12,
  );
  
  static final categoryLabelDark = _baseTextStyle.copyWith(
    color: Colors.black87,
    fontSize: 12,
  );
  
  static final categoryLabelGrid = _baseTextStyle.copyWith(
    color: Colors.black87,
    fontSize: 11,
  );
  
  static final categoryLabelBold = _baseTextStyle.copyWith(
    color: Colors.black87,
    fontSize: 12,
    fontWeight: FontWeight.bold,
  );
  
  // NEW: Separator styles
  static final separatorStyle = _baseTextStyle.copyWith(
    color: Colors.black45,
    fontSize: 11,
  );
  
  static final separatorStyleLarge = _baseTextStyle.copyWith(
    color: Colors.black45,
    fontSize: 12,
  );
  
  // Shadow configurations
  static final defaultShadow = BoxShadow(
    color: defaultShadowColor,
    spreadRadius: 0,
    blurRadius: 10,
    offset: const Offset(0, 4),
  );
  
  static final lightShadow = BoxShadow(
    color: lightShadowColor,
    spreadRadius: 0,
    blurRadius: 5,
    offset: const Offset(0, 2),
  );
  
  // Decorations
  static final cardDecoration = BoxDecoration(
    color: backgroundLightColor,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [defaultShadow],
  );

  static final gridItemDecoration = BoxDecoration(
    color: backgroundLightColor,
    borderRadius: BorderRadius.circular(8),
    boxShadow: [lightShadow],
  );

  static final gradientOverlay = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        Colors.black.withOpacity(0.8),
        Colors.transparent,
      ],
    ),
  );

  static final imageCaptionContainer = BoxDecoration(
    color: backgroundGreyColor,
  );

  static final backButtonContainer = BoxDecoration(
    color: overlayDarkColor,
    shape: BoxShape.circle,
  );
  
  // Layout constants
  static const gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    childAspectRatio: 0.75,
    crossAxisSpacing: 16.0,
    mainAxisSpacing: 16.0,
  );
  
  // Padding
  static const defaultPadding = EdgeInsets.all(16.0);
  static const smallPadding = EdgeInsets.all(10.0);
  static const verticalPadding = EdgeInsets.symmetric(vertical: 24.0);
  static const horizontalPadding = EdgeInsets.symmetric(horizontal: 16.0);
  
  // NEW: Additional padding variants
  static const topPadding = EdgeInsets.only(top: 8.0);
  static const bottomPadding = EdgeInsets.only(bottom: 8.0);
  static const articleItemPadding = EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 0);
  
  // NEW: Spacing constants
  static const smallSpace = 4.0;
  static const mediumSpace = 8.0;
  static const largeSpace = 16.0;
  static const extraLargeSpace = 24.0;
  
  // NEW: Standard sized boxes for spacing
  static const smallSpaceVertical = SizedBox(height: smallSpace);
  static const mediumSpaceVertical = SizedBox(height: mediumSpace);
  static const largeSpaceVertical = SizedBox(height: largeSpace);
  static const extraLargeSpaceVertical = SizedBox(height: extraLargeSpace);
  
  static const smallSpaceHorizontal = SizedBox(width: smallSpace);
  static const mediumSpaceHorizontal = SizedBox(width: mediumSpace);
  static const largeSpaceHorizontal = SizedBox(width: largeSpace);
  
  // Image properties
  static const featuredImageHeight = 220.0;
  static const featuredImageHeightLarge = 260.0; // Added for the +40 height
  static const articleImageHeight = 300.0;
  static const gridImageHeight = 120.0;
  
  // Placeholder
  static final placeholderColor = Colors.grey[300];
  
  // NEW: Error and status styles
  static const errorIconSize = 48.0;
  static const errorIconColor = errorColor;
  static const infoIconSize = 48.0;
  static const infoIconColor = Colors.grey;
  
  static const smallLoaderSize = 20.0;
  static const smallLoaderStrokeWidth = 2.0;
  
  // NEW: HTML styles
  static const htmlBodyFontSize = 16.0;
  static const htmlLineHeight = 1.6;
  static const htmlMarginBottom = 16.0;
  static const htmlFigureMargin = 12.0;
  static const htmlCaptionFontSize = 14.0;
  static const htmlCaptionPadding = 8.0;
}
