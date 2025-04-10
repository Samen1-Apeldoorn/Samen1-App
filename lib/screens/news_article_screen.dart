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
                      placeholder: (context, url) => Container(
                        height: NewsStyles.articleImageHeight,
                        color: NewsStyles.placeholderColor,  // Vervang de afbeelding door een placeholder
                        child: const Center(child: CircularProgressIndicator()),
                      ),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,  // Zorg ervoor dat de elementen links uitgelijnd zijn
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
                      "•",  // Een separator
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black87,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(article.date),  // Formatteer de datum
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
    // Bereken de hoogte van de afbeelding op basis van een 16:9 verhouding
    final imageHeight = screenWidth * (9/16);
    
    return Html(
      data: htmlContent,  // De HTML content die je wilt renderen
      style: {
        "body": Style(
          fontSize: FontSize(NewsStyles.htmlBodyFontSize),  // Stel de lettergrootte in voor de tekst
          fontWeight: FontWeight.normal,
          color: Colors.black87,
          lineHeight: LineHeight(NewsStyles.htmlLineHeight),
        ),
        "p": Style(  // Stijl voor paragraaf
          margin: Margins.only(bottom: NewsStyles.htmlMarginBottom),  // Ruimte onder elke paragraaf
        ),
        "strong": Style(  // Stijl voor vetgedrukte tekst
          fontWeight: FontWeight.bold,
        ),
        "img": Style(  // Stijl voor afbeeldingen
          width: Width(screenWidth),  // Breedte van de afbeelding gebaseerd op het scherm
          height: Height(imageHeight),  // Hoogte berekend met de 16:9 verhouding
          alignment: Alignment.center,  // Centraal uitlijnen van de afbeelding
        ),
        "figure": Style(
          margin: Margins.symmetric(vertical: NewsStyles.htmlFigureMargin),
          display: Display.block,
        ),
        "figcaption": Style(  // Stijl voor bijschriften bij afbeeldingen
          padding: HtmlPaddings.all(NewsStyles.htmlCaptionPadding),
          width: Width(screenWidth),  // Zorg ervoor dat de bijschriften net iets smaller zijn dan de afbeelding
          fontSize: FontSize(NewsStyles.htmlCaptionFontSize),
          color: Colors.grey,
          textAlign: TextAlign.center,  // Centreer de bijschriften
          backgroundColor: NewsStyles.backgroundGreyColor,
        ),
      },
    );
  }
}
