class CatalogSearchRequest {
  const CatalogSearchRequest({
    required this.query,
    this.category,
    this.brand,
    this.available = false,
    this.verified = false,
    this.ordering,
    this.page = 1,
    this.pageSize = 20,
  });

  final String query;
  final String? category;
  final String? brand;
  final bool available;
  final bool verified;
  final String? ordering;
  final int page;
  final int pageSize;

  CatalogSearchRequest withPage(int page) => CatalogSearchRequest(
    query: query,
    category: category,
    brand: brand,
    available: available,
    verified: verified,
    ordering: ordering,
    page: page,
    pageSize: pageSize,
  );

  Map<String, dynamic> toQueryParameters() => {
    'q': query,
    'page': page,
    'page_size': pageSize,
    if (category != null && category!.isNotEmpty) 'category': category,
    if (brand != null && brand!.isNotEmpty) 'brand': brand,
    if (available) 'available': 'true',
    if (verified) 'verified': 'true',
    if (ordering != null && ordering!.isNotEmpty) 'ordering': ordering,
  };

  @override
  bool operator ==(Object other) =>
      other is CatalogSearchRequest &&
      other.query == query &&
      other.category == category &&
      other.brand == brand &&
      other.available == available &&
      other.verified == verified &&
      other.ordering == ordering &&
      other.page == page &&
      other.pageSize == pageSize;

  @override
  int get hashCode => Object.hash(
    query,
    category,
    brand,
    available,
    verified,
    ordering,
    page,
    pageSize,
  );
}
