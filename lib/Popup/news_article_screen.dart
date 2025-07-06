import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Pages/News/news_styles.dart';
import '../Pages/News/news_service.dart';

class NewsArticleScreen extends StatelessWidget {
  final NewsArticle article;
  
  const NewsArticleScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,  // Zorgt ervoor dat de body achter de app bar wordt weergegeven
      appBar: AppBar(
        backgroundColor: Colors.transparent,  // Maak de achtergrond van de app bar transparant
        elevation: 0,  // Verwijdert de schaduw van de app bar
        iconTheme: const IconThemeData(color: Colors.white),  // Zet de kleur van de iconen in de app bar naar wit
        leading: IconButton(
          icon: Container(
            padding: NewsStyles.smallPadding,  // Kleinere padding rondom de knop
            decoration: NewsStyles.backButtonContainer,  // Achtergronddecoratie voor de knop
            child: const Center(
              child: Icon(Icons.arrow_back, size: 20),  // Pijl-icoon voor de terugknop
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),  // Ga terug naar de vorige pagina wanneer geklikt
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,  // Zorg ervoor dat de inhoud links begint
          children: [
            // Als er een afbeelding is, laat die dan zien
            if (article.imageUrl.isNotEmpty)
              Stack(
                children: [
                  SizedBox(
                    width: double.infinity,  // Breedte van de afbeelding is gelijk aan het scherm
                    height: NewsStyles.articleImageHeight,  // Specifieke hoogte van de afbeelding
                    child: CachedNetworkImage(
                      imageUrl: article.imageUrl,
                      width: double.infinity,
                      height: NewsStyles.articleImageHeight,
                      fit: BoxFit.cover,  // Zorg ervoor dat de afbeelding de ruimte vult
                      alignment: Alignment.center,  // Centreer de afbeelding in de beschikbare ruimte
                      errorWidget: (context, url, error) => Container(
                        height: NewsStyles.articleImageHeight,
                        color: NewsStyles.placeholderColor,
                        child: const Icon(Icons.error, size: 40),  // Toon een fouticoon bij een probleem
                      ),
                    ),
                  ),
                  // Overlays de titel van het artikel boven de afbeelding
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: NewsStyles.defaultPadding,  // Standaard padding rondom de titel
                      decoration: NewsStyles.gradientOverlay,  // Zorgt voor een transparante overlay met een gradient
                      child: Text(
                        article.title,
                        style: NewsStyles.titleStyle,  // Pas de stijl van de titel aan
                        maxLines: 3,  // Beperk het aantal regels van de titel
                        overflow: TextOverflow.ellipsis,  // Voeg '...' toe als de titel te lang is
                      ),
                    ),
                  ),
                ],
              ),
            
            // Toon de metadata als de afbeelding beschikbaar is
            if (article.imageUrl.isNotEmpty)
              Container(
                width: double.infinity,  // Maak de container zo breed als het scherm
                margin: EdgeInsets.zero,  // Verwijder de marge om ongewenste witte ruimte te elimineren
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),  // Padding rondom de metadata
                decoration: BoxDecoration(
                  color: NewsStyles.backgroundGreyColor,  // Achtergrondkleur voor de metadata
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // Zorg ervoor dat de tekst links uitgelijnd is
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center, // Zorg ervoor dat alles verticaal gecentreerd is
                      children: [
                        Expanded(
                          child: Row(
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
                            ],
                          ),
                        ),
                        if (article.imageCaption != null && article.imageCaption!.isNotEmpty)
                          Expanded(
                            child: Text(
                              article.imageCaption!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF757575),
                                height: 1.0,
                              ),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                            ),
                          ),
                      ],
                    ),
                    if (article.author.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4), // Voeg wat ruimte toe boven de "Door:"-tekst
                        child: Text(
                          "Door: ${article.author}",
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                            height: 1.0,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            
            // Hoofdinhoud van het artikel
            Padding(
              padding: EdgeInsets.all(16.0),  // Gebruik standaard padding voor het artikel
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Als er geen afbeelding is, toon dan alleen de titel en metadata
                  if (article.imageUrl.isEmpty) ...[
                    Text(
                      article.title,
                      style: NewsStyles.articleTitleStyle,  // Stijl de titel
                    ),
                    NewsStyles.smallSpaceVertical,
                    Row(
                      children: [
                        Text(
                          article.category,
                          style: NewsStyles.categoryLabelDark,  // Stijl voor de categorie
                        ),
                        NewsStyles.mediumSpaceHorizontal,
                        Text(
                          "•",  // Separator
                          style: NewsStyles.separatorStyle,
                        ),
                        NewsStyles.mediumSpaceHorizontal,
                        Text(
                          _formatDate(article.date),  // Geformatteerde datum
                          style: NewsStyles.articleDateStyle,  // Stijl voor de datum
                        ),
                      ],
                    ),
                    NewsStyles.largeSpaceVertical,  // Voeg ruimte toe tussen de metadata en de content
                  ],
                  _buildArticleContent(article.content, context),  // Bouw de content van het artikel op
                  NewsStyles.largeSpaceVertical,  // Extra ruimte onderaan
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Functie om de datum te formatteren
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);  // Zet de datum om naar een DateTime-object
      return DateFormat('d MMMM yyyy').format(date);  // Format de datum naar het gewenste formaat
    } catch (e) {
      return dateString;  // Als er iets misgaat, retourneer de originele string
    }
  }

  // Functie om de HTML content van het artikel weer te geven
  Widget _buildArticleContent(String htmlContent, BuildContext context) {
    final screenWidth = (MediaQuery.of(context).size.width - NewsStyles.htmlCaptionPadding * 2) * 0.92;
    final imageHeight = screenWidth * (2/3);

    // Vervang YouTube iframes met een aangepaste knop
    final modifiedContent = _replaceYouTubeIframes(htmlContent);
    
    return Html(
      data: modifiedContent,
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
        "img": Style(
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
          width: Width(screenWidth),
          fontSize: FontSize(NewsStyles.htmlCaptionFontSize),
          color: Colors.grey,
          textAlign: TextAlign.center,
          backgroundColor: NewsStyles.backgroundGreyColor,
        ),
        "div.youtube-container": Style(
          width: Width(screenWidth),
          margin: Margins.symmetric(vertical: 16),
          alignment: Alignment.center,
        ),
        "div.youtube-container-custom": Style(
          backgroundColor: const Color(0xFFb03333),
          margin: Margins.symmetric(vertical: 16),
          textAlign: TextAlign.center,
          padding: HtmlPaddings.all(8),
        ),
        "div.youtube-container-custom a": Style(
          color: Colors.white,
          display: Display.block,
          padding: HtmlPaddings.all(12),
          textDecoration: TextDecoration.none,
          fontWeight: FontWeight.bold,
        ),
      },
      onLinkTap: (String? url, _, __) async {
        if (url != null) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        }
      },
    );
  }

  String _replaceYouTubeIframes(String content) {
    // Detecteer zowel iframes als ytp-cued-thumbnail-overlay divs
    final regex = RegExp(r'(?:<iframe[^>]*(?:youtube\.com|youtu\.be)[^>]*?\/embed\/([a-zA-Z0-9_-]+)[^>]*>)|(?:<div class="ytp-cued-thumbnail-overlay"[^>]*>.*?vi\/([a-zA-Z0-9_-]+)\/[^"]*".*?<\/div>)', dotAll: true);
    
    return content.replaceAllMapped(regex, (match) {
      // Pak de video ID van ofwel de iframe (group 1) of de thumbnail (group 2)
      final videoId = match.group(1) ?? match.group(2);
      if (videoId == null) return match.group(0) ?? '';
      
      final youtubeUrl = 'https://youtu.be/$videoId';
      return """
        <div class="youtube-container-custom">
          <a href="$youtubeUrl">
            Bekijk de video op YouTube
          </a>
        </div>
      """;
    });
  }
}
