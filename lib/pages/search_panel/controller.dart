
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipala/http/search.dart';
import 'package:pilipala/models/common/search_type.dart';
import 'package:pilipala/utils/id_utils.dart';
import 'package:pilipala/utils/utils.dart';

class SearchPanelController extends GetxController {
  SearchPanelController({this.keyword, this.searchType});

  // 外部传入
  ScrollController scrollController = ScrollController();
  String? keyword;
  SearchType? searchType;

  // 分页与结果
  RxInt page = 1.obs;
  RxList resultList = [].obs;

  // 排序（"exact"=精准），要求：仅在精准时启用“包含词”过滤
  RxString order = ''.obs;

  // 视频特有筛选
  RxInt duration = 0.obs; // 时长
  RxInt tids = (-1).obs;  // 分区，-1 不传

  // 解析后的包含/排除词
  List<String> _includes = [];
  List<String> _excludes = [];

  // 解析搜索词：
  // - 以空格分词
  // - 以 "-" 开头的为排除词（-xx）→ 所有模式都生效
  // - 其他为包含词 → 仅在精准模式(exact)生效
  void _parseTerms(String text) {
    final tokens =
        text.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    _includes = [];
    _excludes = [];
    for (final t in tokens) {
      if (t.startsWith('-') && t.length > 1) {
        _excludes.add(t.substring(1));
      } else {
        _includes.add(t);
      }
    }
  }

  // 把一个 item 的可检索文本尽可能汇总（标题、描述、标签、作者名等）
  String _collectText(dynamic item) {
    // 尝试读取若干常见字段，尽最大可能覆盖不同类型的数据模型
    StringBuffer buf = StringBuffer();

    // 工具
    void add(dynamic v) {
      if (v == null) return;
      final s = v.toString().trim();
      if (s.isNotEmpty) {
        buf.write(' ');
        buf.write(s);
      }
    }

    // 标题/titleList
    try {
      add(item.title);
    } catch (_) {}
    try {
      if (item.titleList is List) {
        final list = item.titleList as List;
        for (final seg in list) {
          try {
            add(seg['text']);
          } catch (_) {
            add(seg.toString());
          }
        }
      }
    } catch (_) {}

    // 描述/副标题/简介
    try {
      add(item.description);
    } catch (_) {}
    try {
      add(item.subTitle);
    } catch (_) {}
    try {
      add(item.desc);
    } catch (_) {}

    // 标签/分类/风格/地区
    try {
      add(item.tag);
    } catch (_) {}
    try {
      add(item.tags);
    } catch (_) {}
    try {
      add(item.cateName);
    } catch (_) {}
    try {
      add(item.styles);
    } catch (_) {}
    try {
      add(item.areas);
    } catch (_) {}

    // bangumi 额外字段
    try {
      add(item.orgTitle);
    } catch (_) {}
    try {
      add(item.indexShow);
    } catch (_) {}
    try {
      add(item.buttonText);
    } catch (_) {}
    try {
      add(item.seasonTypeName);
    } catch (_) {}

    // 用户/直播相关
    try {
      add(item.uname);
    } catch (_) {}
    try {
      add(item.usign);
    } catch (_) {}

    // up 主名称
    try {
      add(item.owner?.name);
    } catch (_) {}

    // 最兜底（尽量避免，但能提升覆盖面）
    try {
      // 某些模型 toString 会包含主要字段
      add(item.toString());
    } catch (_) {}

    return buf.toString().toLowerCase();
  }

  // 应用过滤：
  // - 排除词：永远生效（所有模式 & 所有类型）
  // - 包含词：仅在精准模式(order=='exact')时启用（对所有搜索类型）
  List _applyFilter(List raw) {
    if (_excludes.isEmpty && _includes.isEmpty) return raw;

    final bool isExact = order.value == 'exact';
    final List<String> exc = _excludes.map((e) => e.toLowerCase()).toList();
    final List<String> inc = _includes.map((e) => e.toLowerCase()).toList();

    return raw.where((item) {
      final hay = _collectText(item); // 汇总文本（小写）

      // 排除词：任意命中即剔除（始终生效）
      for (final kw in exc) {
        if (kw.isNotEmpty && hay.contains(kw)) {
          return false;
        }
      }

      // 包含词：仅精准时要求全部命中
      if (isExact && inc.isNotEmpty) {
        for (final kw in inc) {
          if (kw.isEmpty) continue;
          if (!hay.contains(kw)) return false;
        }
      }

      return true;
    }).toList();
  }

  Future onSearch({type = 'init'}) async {
    final result = await SearchHttp.searchByType(
      searchType: searchType!,
      keyword: keyword ?? '',
      page: page.value,
      // 后端 order 只对部分类型生效；客户端过滤会对所有类型生效（见 _applyFilter）
      order: !['video', 'article'].contains(searchType!.type)
          ? null
          : (order.value == '' ? null : order.value),
      duration: searchType!.type != 'video' ? null : duration.value,
      tids: searchType!.type != 'video' ? null : tids.value,
    );

    if (result['status']) {
      // 解析包含/排除词
      _parseTerms(keyword ?? '');

      // 原始数据
      List list = result['data'].list ?? [];

      // 客户端过滤（排除词：所有模式；包含词：仅精准）
      list = _applyFilter(list);

      if (type == 'onRefresh') {
        resultList.value = list;
      } else {
        resultList.addAll(list);
      }
      page.value++;

      // 仅投稿视频的 AV/BV 快速直达
      onPushDetail(keyword, resultList);
    }
    return result;
  }

  Future onRefresh() async {
    page.value = 1;
    await onSearch(type: 'onRefresh');
  }

  // 返回顶部并刷新
  void animateToTop() async {
    final ctx = Get.context;
    if (ctx == null) return;
    if (scrollController.offset >= MediaQuery.of(ctx).size.height * 5) {
      scrollController.jumpTo(0);
    } else {
      await scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  // 仅视频：AV/BV 命中直接进详情
  void onPushDetail(keyword, resultList) async {
    if (searchType != SearchType.video) return;

    // BV/AV 解析
    final Map matchRes = IdUtils.matchAvorBv(input: keyword);
    final List matchKeys = matchRes.keys.toList();

    String? bvid;
    int? aid;

    try {
      bvid = resultList.first.bvid;
    } catch (_) {}
    try {
      aid = resultList.first.aid;
    } catch (_) {}

    if (matchKeys.isNotEmpty || aid.toString() == keyword) {
      final String heroTag = Utils.makeHeroTag(bvid);
      final int cid = await SearchHttp.ab2c(aid: aid, bvid: bvid);

      final bool bvHit = matchKeys.isNotEmpty &&
          matchKeys.first == 'BV' &&
          matchRes[matchKeys.first] == bvid;
      final bool avHit = matchKeys.isNotEmpty &&
          matchKeys.first == 'AV' &&
          matchRes[matchKeys.first] == aid;
      final bool aidEq = aid.toString() == keyword;

      if (cid > 0 && (bvHit || avHit || aidEq)) {
        Get.toNamed(
          '/video?bvid=$bvid&cid=$cid',
          arguments: {'videoItem': resultList.first, 'heroTag': heroTag},
        );
      }
    }
  }
}