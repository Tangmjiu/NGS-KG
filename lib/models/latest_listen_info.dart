class LatestListenInfo {
  final Map<String, dynamic>? info;
  final int position;
  final Map<String, dynamic>? devInfo;

  const LatestListenInfo({this.info, this.position = 0, this.devInfo});

  String? get deviceLabel => devInfo?['wording'] as String?;
}
