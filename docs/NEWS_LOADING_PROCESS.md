# News Loading Process Documentation

This document outlines the process used in `NewsPage` to fetch and display news articles (both general and category-specific) from the Omroep Apeldoorn API. The goal is to provide a smooth user experience by loading articles efficiently and proactively.

## Overview

The `NewsPage` widget handles displaying news lists. It can show general news or news filtered by a specific category ID passed during instantiation. The loading mechanism employs several strategies:

1.  **Initial Load:** Load the first full page of articles (general or category-specific).
2.  **Preloading:** Fetch the next page of articles before the user reaches the end of the current list.
3.  **On-Demand Loading:** Load the next page when the user scrolls near the bottom if preloading hasn't completed or wasn't triggered.
4.  **Smart Pull-to-Refresh:** Fetch the first page and prepend only new articles without clearing the existing list.
5.  **Lifecycle Management:** Ensure API calls and state updates don't occur after the page is disposed.
6.  **Structured State Management:** Uses a `LoadState` enum (`initial`, `loadingInitial`, `loadingMore`, `preloading`, `refreshing`, `idle`, `error`, `allLoaded`) to manage UI and loading logic.

## LoadState Enum

*   `initial`: Before any loading starts.
*   `loadingInitial`: Loading the very first page. UI shows a central indicator.
*   `loadingMore`: Loading subsequent pages (triggered by scroll). UI shows a footer indicator.
*   `preloading`: Preloading the next page in the background. No direct UI change.
*   `refreshing`: Pull-to-refresh is active. `RefreshIndicator` shows.
*   `idle`: Load/preload/refresh finished, waiting for user action or scroll trigger.
*   `error`: An error occurred, and the article list is empty. UI shows an error message with a retry button.
*   `allLoaded`: The API indicated no more articles are available. UI shows a footer message.

## Detailed Steps

1.  **Initialization (`initState`)**:
    *   `NewsPage` receives an optional `categoryId`.
    *   `_loadState` is `LoadState.initial`.
    *   `_loadNews(isInitialLoad: true)` is called.

2.  **Loading Articles (`_loadNews`)**:
    *   Sets `_loadState` to `loadingInitial` or `loadingMore`.
    *   Checks if articles for the `_currentPage` are in `_preloadedArticles`.
        *   If yes: Uses preloaded data, clears `_preloadedArticles`.
        *   If no: Fetches the `_currentPage` from the API.
            *   If `widget.categoryId` is null: Uses `NewsService.getNews`.
            *   If `widget.categoryId` is provided: Uses `NewsService.getNewsByCategory`.
    *   On completion:
        *   If articles received: Adds them to `_articles`, increments `_currentPage`, sets `_loadState` to `idle`. Calls `_preloadNextPage`.
        *   If empty list received: Sets `_hasMoreArticles` to `false`. Sets `_loadState` to `allLoaded` (or `error` if `_articles` is still empty).
        *   If error occurred: Sets `_loadState` to `error` (if `_articles` is empty) or `idle` (if articles were already present).
    *   Calls `setState` to update the UI based on the final `_loadState`.

3.  **Scrolling and Preloading (`_scrollListener`, `_preloadNextPage`)**:
    *   `_scrollListener` checks scroll position.
    *   If near 80% (`scrollThreshold`), `_loadState` is `idle`, `_hasMoreArticles` is true, and `_preloadedArticles` is empty:
        *   Calls `_preloadNextPage`.
    *   `_preloadNextPage`:
        *   Sets `_loadState` to `preloading` (without `setState`).
        *   Fetches the *next* page (`_currentPage`) using the appropriate `NewsService` method based on `widget.categoryId`.
        *   Stores result in `_preloadedArticles`.
        *   Sets `_loadState` back to `idle` (without `setState`). Handles errors by clearing `_preloadedArticles`.

4.  **Loading More Articles On Demand (`_scrollListener`)**:
    *   If near bottom (`nearBottom`), `_loadState` is `idle`, and `_hasMoreArticles` is true:
        *   Calls `_loadNews()` after a short delay.
        *   `_loadNews` will use preloaded data if available or fetch directly.

5.  **End of Articles**:
    *   When `_loadNews` receives an empty list, `_hasMoreArticles` becomes `false`, and `_loadState` becomes `allLoaded`. The footer message is shown.

6.  **Smart Pull-to-Refresh (`_refreshNews`)**:
    *   User pulls down, `RefreshIndicator` triggers `_refreshNews`.
    *   Sets `_loadState` to `refreshing`. Clears `_preloadedArticles`.
    *   Fetches page 1 from the API (using the correct `NewsService` method based on `widget.categoryId`).
    *   Compares fetched article IDs with existing IDs in `_articles`.
    *   Filters out duplicates, keeping only genuinely new articles.
    *   Inserts new articles at the beginning of `_articles` using `insertAll(0, newArticles)`.
    *   Resets `_currentPage` logic (next page is 2), sets `_hasMoreArticles` to true.
    *   Sets `_loadState` back to `idle`.
    *   Calls `_preloadNextPage` to fetch page 2.
    *   Handles errors by setting `_loadState` to `idle` (or `error` if list was empty) and showing a SnackBar.

7.  **Error Handling**:
    *   Errors during `_loadNews` or `_refreshNews` transition to `LoadState.error` only if `_articles` is empty. Otherwise, they revert to `LoadState.idle`, potentially showing a SnackBar.
    *   The `_buildErrorView` is shown only when `_loadState == LoadState.error` and `_articles.isEmpty`.

8.  **Lifecycle Management (`mounted`)**:
    *   Checks prevent `setState` calls after disposal. `dispose` cleans up listeners.

## API Endpoints Used

*   **General News**: `https://api.omroepapeldoorn.nl/api/nieuws?per_page={count}&page={page_number}&_embed=true`
    *   Used when `NewsPage` is instantiated without a `categoryId`.
*   **Category News**: `https://api.omroepapeldoorn.nl/api/categorie?per_page={count}&page={page_number}&categorie={category_id}&_embed=true`
    *   Used when `NewsPage` is instantiated *with* a `categoryId`.

Parameters:
*   `per_page`: Set to `_fullPageCount` (15).
*   `page`: The page number being requested.
*   `_embed=true`: To include featured media details.
*   `categorie={category_id}`: Added only for category-specific requests.

This consolidated approach simplifies maintenance while providing the necessary functionality for both general and category news display.

## Future Improvements

Here are potential areas for future enhancement of the news loading process:

*   **Robust Preload Error Handling:**
    *   Implement a simple retry mechanism (e.g., one retry after a short delay) if a `_preloadNextPage` call fails due to network issues or temporary server errors.
    *   Ensure detailed logging of preload failures to aid debugging.

*   **Caching:**
    *   Implement local caching (e.g., using `shared_preferences` for simple data or a database like `sqflite` or `hive` for more complex storage) to store fetched articles.
    *   On subsequent app launches or page visits, display cached data immediately while fetching updates in the background. This improves perceived performance and reduces redundant API calls. Consider cache expiration strategies.


