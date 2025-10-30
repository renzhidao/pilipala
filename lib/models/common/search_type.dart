class SearchType {
  final String type;
  final String label;
  const SearchType(this.type, this.label);

  static const video = SearchType('video', '视频');
  static const media_bangumi = SearchType('media_bangumi', '番剧');
  static const media_ft = SearchType('media_ft', '影视');
  static const live_room = SearchType('live_room', '直播');
  static const bili_user = SearchType('bili_user', 'UP主');
  static const article = SearchType('article', '专栏');

  static const values = [
    video,
    media_bangumi,
    media_ft,
    live_room,
    bili_user,
    article,
  ];
}

enum ArchiveFilterType {
  exact,        // 精准匹配
  totalrank,    // 综合排序
  click,        // 最多播放
  pubdate,      // 最新发布
  dm,           // 最多弹幕
  stow;         // 最多收藏

  String get description => switch (this) {
    ArchiveFilterType.exact => '精准',
    ArchiveFilterType.totalrank => '综合排序',
    ArchiveFilterType.click => '最多播放',
    ArchiveFilterType.pubdate => '最新发布',
    ArchiveFilterType.dm => '最多弹幕',
    ArchiveFilterType.stow => '最多收藏',
  };
}

enum ArticleFilterType {
  totalrank,    // 综合排序
  click,        // 最多阅读
  pubdate,      // 最新发布
  attention;    // 最多喜欢

  String get description => switch (this) {
    ArticleFilterType.totalrank => '综合排序',
    ArticleFilterType.click => '最多阅读',
    ArticleFilterType.pubdate => '最新发布',
    ArticleFilterType.attention => '最多喜欢',
  };
}
