import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipala/http/search.dart';
import 'package:pilipala/models/common/search_type.dart';
import 'package:pilipala/utils/id_utils.dart';
import 'package:pilipala/utils/utils.dart';

class SearchPanelController extends GetxController {
  SearchPanelController({this.keyword, this.searchType});
  ScrollController scrollController = ScrollController();
  String? keyword;
  SearchType? searchType;
  RxInt page = 1.obs;
  RxList resultList = [].obs;
  
  // 结果排序方式 搜索类型为视频、专栏及相簿时
  RxString order = 'exact'.obs; // 默认为精准搜索
  
  // 视频时长筛选 仅用于搜索视频
  RxInt duration = 0.obs;
  
  // 视频分区筛选 仅用于搜索视频 -1时不传
  RxInt tids = (-1).obs;

  // 新增：加载状态控制
  RxBool isLoading = false.obs;
  RxBool hasMore = true.obs;
  int maxLoadPages = 10; // 最多加载10页防止无限循环
  int minResultCount = 20; // 最少需要20条筛选后的结果

  // 分词函数：用户通过空格控制分词
  List<String> _splitKeywords(String keyword) {
    keyword = keyword.trim();
    
    // 如果包含空格，按空格分词（用户自主控制）
    if (keyword.contains(' ')) {
      return keyword.split(' ').where((s) => s.trim().isNotEmpty).toList();
    }
    
    // 无空格时，不拆分，保持整体
    return [keyword];
  }

  // 客户端筛选：只保留包含所有关键词的结果
  List _filterByKeywords(List allResults) {
    // 只有在 order 为 exact 时才进行客户端筛选
    if (order.value != 'exact') {
      return allResults;
    }

    String searchTerm = keyword?.trim() ?? '';
    if (searchTerm.isEmpty) return allResults;
    
    List<String> keywords = _splitKeywords(searchTerm);
    
    return allResults.where((item) {
      String title = (item.title ?? '').toLowerCase();
      // 检查标题是否包含所有关键词（不区分大小写）
      return keywords.every((kw) => title.contains(kw.toLowerCase()));
    }).toList();
  }

  Future onSearch({type = 'init'}) async {
    // 防止重复加载
    if (isLoading.value) return {'status': false, 'msg': '加载中'};
    
    // 检查是否还有更多数据
    if (!hasMore.value && type == 'onLoad') {
      return {'status': false, 'msg': '没有更多了'};
    }

    // 防止无限加载
    if (page.value > maxLoadPages && type == 'onLoad') {
      hasMore.value = false;
      return {'status': false, 'msg': '已加载足够多的页面'};
    }

    isLoading.value = true;

    var result = await SearchHttp.searchByType(
      searchType: searchType!,
      keyword: keyword!,
      page: page.value,
      order: !['video', 'article'].contains(searchType!.type)
          ? null
          : (order.value == 'exact' ? null : order.value),
      duration: searchType!.type != 'video' ? null : duration.value,
      tids: searchType!.type != 'video' ? null : tids.value,
    );

    if (result['status']) {
      List rawList = result['data'].list ?? [];
      
      // 如果API返回空，说明真的没有更多了
      if (rawList.isEmpty) {
        hasMore.value = false;
        isLoading.value = false;
        return result;
      }

      // 客户端筛选
      List filteredList = _filterByKeywords(rawList);

      if (type == 'onRefresh') {
        resultList.value = filteredList;
      } else {
        resultList.addAll(filteredList);
      }

      page.value++;

      // 如果筛选后结果太少，自动加载下一页
      if (order.value == 'exact' && 
          resultList.length < minResultCount && 
          page.value <= maxLoadPages) {
        isLoading.value = false;
        return await onSearch(type: 'onLoad'); // 递归加载
      }

      // 首次加载时自动跳转（保持原有逻辑）
      if (type == 'init') {
        onPushDetail(keyword, resultList);
      }
    }

    isLoading.value = false;
    return result;
  }

  Future onRefresh() async {
    page.value = 1;
    hasMore.value = true;
    await onSearch(type: 'onRefresh');
  }

  // 返回顶部并刷新
  void animateToTop() async {
    if (scrollController.offset >=
        MediaQuery.of(Get.context!).size.height * 5) {
      scrollController.jumpTo(0);
    } else {
      await scrollController.animateTo(0,
          duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    }
  }

  void onPushDetail(keyword, resultList) async {
    // 匹配输入内容，如果是AV、BV号且有结果 直接跳转详情页
    Map matchRes = IdUtils.matchAvorBv(input: keyword);
    List matchKeys = matchRes.keys.toList();
    String? bvid;
    try {
      bvid = resultList.first.bvid;
    } catch (_) {
      bvid = null;
    }
    // keyword 可能输入纯数字
    int? aid;
    try {
      aid = resultList.first.aid;
    } catch (_) {
      aid = null;
    }
    if (matchKeys.isNotEmpty && searchType == SearchType.video ||
        aid.toString() == keyword) {
      String heroTag = Utils.makeHeroTag(bvid);
      int cid = await SearchHttp.ab2c(aid: aid, bvid: bvid);
      if (matchKeys.isNotEmpty &&
              matchKeys.first == 'BV' &&
              matchRes[matchKeys.first] == bvid ||
          matchKeys.isNotEmpty &&
              matchKeys.first == 'AV' &&
              matchRes[matchKeys.first] == aid ||
          aid.toString() == keyword) {
        Get.toNamed(
          '/video?bvid=$bvid&cid=$cid',
          arguments: {'videoItem': resultList.first, 'heroTag': heroTag},
        );
      }
    }
  }
}

---

## 🎯 核心改动说明

### 修改的函数：`_splitKeywords`

**之前（第 32-57 行）：**
```dart
// 自动按2字拆分
if (keyword.length % 2 == 0) {
  List<String> result = [];
  for (int i = 0; i < keyword.length; i += 2) {
    result.add(keyword.substring(i, i + 2));
  }
  return result;
}

**现在（第 32-42 行）：**
```dart
// 如果包含空格，按空格分词（用户自主控制）
if (keyword.contains(' ')) {
  return keyword.split(' ').where((s) => s.trim().isNotEmpty).toList();
}

// 无空格时，不拆分，保持整体
return [keyword];

---

## 🧪 测试对比

### 示例 1：无空格搜索
**输入：** `面包生虫`  
**分词：** `["面包生虫"]`  
**匹配：**
- ✅ "如何处理面包生虫问题"
- ✅ "面包生虫了怎么办"
- ❌ "面包和大米生虫"（不包含完整的"面包生虫"）

### 示例 2：空格分词搜索
**输入：** `面粉 虫`  
**分词：** `["面粉", "虫"]`  
**匹配：**
- ✅ "面粉生虫怎么办"
- ✅ "虫子爬进面粉里"
- ✅ "面粉容易长虫"
- ❌ "面包生虫"（不包含"面粉"）

### 示例 3：多个关键词
**输入：** `面包 制作 教程`  
**分词：** `["面包", "制作", "教程"]`  
**匹配：** 标题必须同时包含这3个词

---

## 💡 使用技巧

### 想要更多结果？
使用空格分词：`面粉 虫` → 匹配范围更广

### 想要精准结果？
不加空格：`面包生虫` → 只匹配完整包含这个词的

### 结果还是太少？
1. 尝试换其他排序方式（综合排序、最多播放等）
2. 调整最大加载页数（controller.dart 第 25 行改成 15 或 20）
3. 减少必需的最小结果数（controller.dart 第 26 行改成 10）

---

**修改完成！现在可以通过空格自由控制分词了** ✅