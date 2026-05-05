import 'package:flutter/foundation.dart';

class LikedSongsProvider extends ChangeNotifier {
  final Set<int> _likedIds = {};

  Set<int> get likedIds => _likedIds;

  bool isLiked(int id) => _likedIds.contains(id);

  void toggle(int id) {
    if (_likedIds.contains(id)) {
      _likedIds.remove(id);
    } else {
      _likedIds.add(id);
    }
    notifyListeners();
  }
}
