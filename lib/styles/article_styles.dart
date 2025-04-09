import 'package:flutter/material.dart';

class ArticleStyles {
  // Colors
  static const Color backgroundGreyColor = Color(0xFFF5F5F5);
  static final Color placeholderColor = Colors.grey[300]!;
  
  // Text Styles
  static const TextStyle titleStyle = TextStyle(
    color: Colors.white,
    fontSize: 22,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle articleTitleStyle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: Colors.black87,
  );

  static const TextStyle categoryStyle = TextStyle(
    color: Colors.black87,
    fontSize: 12,
  );

  static const TextStyle dateStyle = TextStyle(
    color: Color(0xFF757575),
    fontSize: 14,
  );

  static const TextStyle separatorStyle = TextStyle(
    color: Colors.black45,
    fontSize: 12,
  );

  static const TextStyle imageCaptionStyle = TextStyle(
    fontStyle: FontStyle.italic,
    color: Color(0xFF616161),
    fontSize: 12,
  );

  // Decorations
  static final BoxDecoration gradientOverlay = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        Colors.black.withAlpha(204),
        Colors.transparent,
      ],
    ),
  );

  static const BoxDecoration imageCaptionContainer = BoxDecoration(
    color: backgroundGreyColor,
  );

  static final BoxDecoration backButtonContainer = BoxDecoration(
    color: Colors.black26,
    shape: BoxShape.circle,
  );

  // Padding and Spacing
  static const EdgeInsets defaultPadding = EdgeInsets.all(16.0);
  static const EdgeInsets captionPadding = EdgeInsets.all(12.0);
  static const EdgeInsets backButtonPadding = EdgeInsets.all(8.0);

  static const SizedBox smallSpaceVertical = SizedBox(height: 4.0);
  static const SizedBox mediumSpaceHorizontal = SizedBox(width: 8.0);
  static const SizedBox largeSpaceVertical = SizedBox(height: 16.0);

  // Dimensions
  static const double articleImageHeight = 300.0;
  
  // HTML Styles
  static const double htmlBodyFontSize = 16.0;
  static const double htmlLineHeight = 1.6;
  static const double htmlMarginBottom = 16.0;
  static const double htmlFigureMargin = 12.0;
  static const double htmlCaptionFontSize = 14.0;
  static const double htmlCaptionPadding = 8.0;
}
