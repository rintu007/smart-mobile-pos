/// Plain Dart — the one field this app currently needs from `GET /stores`'s
/// response (`id`); `name` is carried along for the local cache row/future
/// UI use, per store_context.dart's docstring.
class StoreSummary {
  const StoreSummary({required this.id, required this.name});

  final String id;
  final String name;
}
