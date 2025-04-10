import 'package:flutter/material.dart';
import '../services/log_service.dart';
import '../Pages/Category/category_news_page.dart';
import '../Pages/News/news_page.dart';

class CategoryInfo {
  final String name;
  final int id;
  
  const CategoryInfo(this.name, this.id);
}

class NewsContainer extends StatefulWidget {
  const NewsContainer({super.key});

  @override
  State<NewsContainer> createState() => _NewsContainerState();
}

class _NewsContainerState extends State<NewsContainer> {
  // Category definitions with their IDs
  static const List<CategoryInfo> _categories = [
    CategoryInfo('Nieuws', 0), // 0 is a special ID for the all news page
    CategoryInfo('112', 67),
    CategoryInfo('Cultuur', 73),
    CategoryInfo('Evenementen', 72),
    CategoryInfo('Gemeente', 71),
    CategoryInfo('Politiek', 69),
    CategoryInfo('Regio', 1),
  ];

  int _selectedCategoryIndex = 0;

  @override
  void initState() {
    super.initState();
    LogService.log('NewsContainer: Initializing with category selector', category: 'navigation');
  }

  void _onCategorySelected(int index) {
    LogService.log(
      'NewsContainer: Category changed from ${_categories[_selectedCategoryIndex].name} to ${_categories[index].name}', 
      category: 'navigation'
    );
    setState(() {
      _selectedCategoryIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 5, // Minimal top padding
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        automaticallyImplyLeading: false, // Remove the back button
        title: null, // No title text
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            width: double.infinity,
            height: 50,
            color: Theme.of(context).colorScheme.primary,
            padding: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
            alignment: Alignment.center,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final isSelected = index == _selectedCategoryIndex;
                return GestureDetector(
                  onTap: () => _onCategorySelected(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected 
                        ? Colors.white 
                        : Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        _categories[index].name,
                        style: TextStyle(
                          color: isSelected 
                            ? Theme.of(context).colorScheme.primary 
                            : Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      body: _buildCurrentCategoryPage(),
    );
  }

  Widget _buildCurrentCategoryPage() {
    // If we're on the main news page (index 0), show the regular NewsPage
    if (_selectedCategoryIndex == 0) {
      return const NewsPage(key: ValueKey('news-all'), isInContainer: true);
    }
    
    // Otherwise, show the category-specific page
    final category = _categories[_selectedCategoryIndex];
    return CategoryNewsPage(
      key: ValueKey('category-${category.id}'),  // Add a unique key for each category
      title: category.name,
      categoryId: category.id,
    );
  }
}
