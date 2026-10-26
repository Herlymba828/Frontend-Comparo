class RepositoryResult<T> {
  const RepositoryResult({
    required this.value,
    this.cachedAtUtc,
    this.isExpired = false,
  });

  final T value;
  final DateTime? cachedAtUtc;
  final bool isExpired;

  bool get isFromCache => cachedAtUtc != null;
}
