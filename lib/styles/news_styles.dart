import 'package:flutter/material.dart';

class NewsStyles {
  // Text styles
  static const titleStyle = TextStyle(
    color: Colors.white,
    fontSize: 22,
    fontWeight: FontWeight.bold,
  );

  static const articleTitleStyle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
  );

  static const gridTitleStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.bold,
  );

  static const dateStyle = TextStyle(
    color: Colors.white70,
    fontSize: 14,
  );

  static const articleDateStyle = TextStyle(
    color: Color(0xFF757575), // grey[600]
    fontSize: 14,
  );

  static const gridDateStyle = TextStyle(
    color: Color(0xFF757575), // grey[600]
    fontSize: 10,
  );

  static const excerptStyle = TextStyle(
    color: Color(0xFF616161), // grey[700]
    fontSize: 14,
  );

  static const gridExcerptStyle = TextStyle(
    color: Color(0xFF616161), // grey[700]
    fontSize: 12,
  );

  static const contentStyle = TextStyle(
    fontSize: 16,
    height: 1.6,
  );

  static const imageCaptionStyle = TextStyle(
    fontStyle: FontStyle.italic,
    color: Color(0xFF616161), // grey[700]
    fontSize: 12,
  );

  static const noMoreArticlesStyle = TextStyle(
    color: Color(0xFF757575), // grey[600]
    fontSize: 14,
  );

  // Decorations
  static final cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        spreadRadius: 0,
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static final gridItemDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(8),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        spreadRadius: 0,
        blurRadius: 5,
        offset: const Offset(0, 2),
      ),
    ],
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
    color: Color(0xFFF5F5F5), // grey[100]
  );

  static final backButtonContainer = BoxDecoration(
    color: Colors.black26,
    shape: BoxShape.circle,
  );
  
  // Layout constants
  static const gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    childAspectRatio: 0.75,
    crossAxisSpacing: 16.0,
    mainAxisSpacing: 16.0,
  );
  
  static const defaultPadding = EdgeInsets.all(16.0);
  static const smallPadding = EdgeInsets.all(10.0);
  static const verticalPadding = EdgeInsets.symmetric(vertical: 24.0);
  static const horizontalPadding = EdgeInsets.symmetric(horizontal: 16.0);
  
  // Image properties
  static const featuredImageHeight = 220.0;
  static const articleImageHeight = 300.0;
  static const gridImageHeight = 120.0;
  
  // Placeholder colors
  static final placeholderColor = Colors.grey[300];
}
