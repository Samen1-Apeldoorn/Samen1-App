import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:flutter_html/flutter_html.dart';
import '../styles/article_styles.dart';
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
            padding: ArticleStyles.backButtonPadding,
            decoration: ArticleStyles.backButtonContainer,
            child: const Icon(Icons.arrow_back),
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
                  CachedNetworkImage(
                    imageUrl: article.imageUrl,
                    width: double.infinity,
                    height: ArticleStyles.articleImageHeight,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: ArticleStyles.articleImageHeight,
                      color: ArticleStyles.placeholderColor,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: ArticleStyles.articleImageHeight,
                      color: ArticleStyles.placeholderColor,
                      child: const Icon(Icons.error, size: 40),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: ArticleStyles.defaultPadding,
                      decoration: ArticleStyles.gradientOverlay,
                      child: Text(
                        article.title,
                        style: ArticleStyles.titleStyle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            
            if (article.imageUrl.isNotEmpty)
              Padding(
                padding: ArticleStyles.defaultPadding,
                child: Row(
                  children: [
                    Text(
                      article.category,
                      style: ArticleStyles.categoryStyle,
                    ),
                    ArticleStyles.mediumSpaceHorizontal,
                    Text(
                      "•",
                      style: ArticleStyles.separatorStyle,
                    ),
                    ArticleStyles.mediumSpaceHorizontal,
                    Text(
                      _formatDate(article.date),
                      style: ArticleStyles.dateStyle,
                    ),
                  ],
                ),
              ),
            
            Padding(
              padding: ArticleStyles.defaultPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (article.imageUrl.isEmpty) ...[
                    Text(
                      article.title,
                      style: ArticleStyles.articleTitleStyle,
                    ),
                    ArticleStyles.smallSpaceVertical,
                    Row(
                      children: [
                        Text(
                          article.category,
                          style: ArticleStyles.categoryStyle,
                        ),
                        ArticleStyles.mediumSpaceHorizontal,
                        Text(
                          "•",
                          style: ArticleStyles.separatorStyle,
                        ),
                        ArticleStyles.mediumSpaceHorizontal,
                        Text(
                          _formatDate(article.date),
                          style: ArticleStyles.dateStyle,
                        ),
                      ],
                    ),
                    ArticleStyles.largeSpaceVertical,
                  ],
                  _buildArticleContent(article.content, context),
                  ArticleStyles.largeSpaceVertical,
                  if (article.imageCaption != null && article.imageCaption!.isNotEmpty)
                    Container(
                      padding: ArticleStyles.captionPadding,
                      decoration: ArticleStyles.imageCaptionContainer,
                      child: Row(
                        children: [
                          const Icon(Icons.photo_camera, size: 16, color: Colors.grey),
                          ArticleStyles.mediumSpaceHorizontal,
                          Expanded(
                            child: Text(
                              article.imageCaption!,
                              style: ArticleStyles.imageCaptionStyle,
                            ),
                          ),
                        ],
                      ),
                    ),
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
    return Html(
      data: htmlContent,
      style: {
        "body": Style(
          fontSize: FontSize(ArticleStyles.htmlBodyFontSize),
          fontWeight: FontWeight.normal,
          color: Colors.black87,
          lineHeight: LineHeight(ArticleStyles.htmlLineHeight),
        ),
        "p": Style(
          margin: Margins.only(bottom: ArticleStyles.htmlMarginBottom),
        ),
        "strong": Style(
          fontWeight: FontWeight.bold,
        ),
        "img": Style(
          padding: HtmlPaddings.zero,
          margin: Margins.only(top: 8.0, bottom: 8.0),
          display: Display.block,
        ),
        "figure": Style(
          margin: Margins.symmetric(vertical: ArticleStyles.htmlFigureMargin),
          display: Display.block,
        ),
        "figcaption": Style(
          padding: HtmlPaddings.all(ArticleStyles.htmlCaptionPadding),
          fontSize: FontSize(ArticleStyles.htmlCaptionFontSize),
          color: Colors.grey,
          textAlign: TextAlign.center,
          backgroundColor: ArticleStyles.backgroundGreyColor,
        ),
      },
    );
  }
}
