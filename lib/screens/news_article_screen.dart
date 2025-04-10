import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:flutter_html/flutter_html.dart';
import '../styles/news_styles.dart';
import '../services/news_service.dart';

class NewsArticleScreen extends StatelessWidget {
  final NewsArticle article;
  
  const NewsArticleScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: Container(
            padding: NewsStyles.smallPadding,
            decoration: NewsStyles.backButtonContainer,
            child: const Center(
              child: Icon(Icons.arrow_back, size: 20),
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article.imageUrl.isNotEmpty)
              Stack(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: NewsStyles.articleImageHeight,
                    child: CachedNetworkImage(
                      imageUrl: article.imageUrl,
                      width: double.infinity,
                      height: NewsStyles.articleImageHeight,
                      fit: BoxFit.cover,
                      alignment: Alignment.center, // Center the image content
                      placeholder: (context, url) => Container(
                        height: NewsStyles.articleImageHeight,
                        color: NewsStyles.placeholderColor,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: NewsStyles.articleImageHeight,
                        color: NewsStyles.placeholderColor,
                        child: const Icon(Icons.error, size: 40),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: NewsStyles.defaultPadding,
                      decoration: NewsStyles.gradientOverlay,
                      child: Text(
                        article.title,
                        style: NewsStyles.titleStyle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            
            if (article.imageUrl.isNotEmpty)
              Container(
                width: double.infinity,
                margin: EdgeInsets.zero, // Remove margin to eliminate the white gap
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: NewsStyles.backgroundGreyColor,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      article.category,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "•",
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black87,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(article.date),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF757575),
                        height: 1.0,
                      ),
                    ),
                    if (article.imageCaption != null && article.imageCaption!.isNotEmpty) ...[
                      const Spacer(),
                      Text(
                        article.imageCaption!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF757575),
                          height: 1.0,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            
            Padding(
              padding: NewsStyles.defaultPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (article.imageUrl.isEmpty) ...[
                    Text(
                      article.title,
                      style: NewsStyles.articleTitleStyle,
                    ),
                    NewsStyles.smallSpaceVertical,
                    Row(
                      children: [
                        Text(
                          article.category,
                          style: NewsStyles.categoryLabelDark,
                        ),
                        NewsStyles.mediumSpaceHorizontal,
                        Text(
                          "•",
                          style: NewsStyles.separatorStyle,
                        ),
                        NewsStyles.mediumSpaceHorizontal,
                        Text(
                          _formatDate(article.date),
                          style: NewsStyles.articleDateStyle,
                        ),
                      ],
                    ),
                    NewsStyles.largeSpaceVertical,
                  ],
                  _buildArticleContent(article.content, context),
                  NewsStyles.largeSpaceVertical,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('d MMMM yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildArticleContent(String htmlContent, BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width - 32.0; // Account for padding
    // Calculate height based on a 16:9 aspect ratio
    final imageHeight = screenWidth * (9/16);
    
    return Html(
      data: htmlContent,
      style: {
        "body": Style(
          fontSize: FontSize(NewsStyles.htmlBodyFontSize),
          fontWeight: FontWeight.normal,
          color: Colors.black87,
          lineHeight: LineHeight(NewsStyles.htmlLineHeight),
        ),
        "p": Style(
          margin: Margins.only(bottom: NewsStyles.htmlMarginBottom),
        ),
        "strong": Style(
          fontWeight: FontWeight.bold,
        ),
        "img": Style(
          padding: HtmlPaddings.zero,
          margin: Margins.only(top: 8.0, bottom: 8.0),
          display: Display.block,
          width: Width(screenWidth),
          height: Height(imageHeight),
          alignment: Alignment.center,
        ),
        "figure": Style(
          margin: Margins.symmetric(vertical: NewsStyles.htmlFigureMargin),
          display: Display.block,
        ),
        "figcaption": Style(
          padding: HtmlPaddings.all(NewsStyles.htmlCaptionPadding),
          fontSize: FontSize(NewsStyles.htmlCaptionFontSize),
          color: Colors.grey,
          textAlign: TextAlign.center,
          backgroundColor: NewsStyles.backgroundGreyColor,
        ),
      },
    );
  }
}
