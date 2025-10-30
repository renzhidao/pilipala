
// ignore_for_file: invalid_use_of_protected_member

import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipala/common/skeleton/media_bangumi.dart';
import 'package:pilipala/common/skeleton/video_card_h.dart';
import 'package:pilipala/common/widgets/http_error.dart';
import 'package:pilipala/models/common/search_type.dart';

import 'controller.dart';
import 'widgets/article_panel.dart';
import 'widgets/live_panel.dart';
import 'widgets/media_bangumi_panel.dart';
import 'widgets/user_panel.dart';
import 'widgets/video_panel.dart';

class SearchPanel extends StatefulWidget {
  final String? keyword;
  final SearchType? searchType;
  final String? tag;
  const SearchPanel(
      {required this.keyword, required this.searchType, this.tag, Key? key})
      : super(key: key);

  @override
  State<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<SearchPanel>
    with AutomaticKeepAliveClientMixin {
  late SearchPanelController _searchPanelController;

  late Future _futureBuilderFuture;
  late ScrollController scrollController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _searchPanelController = Get.put(
      SearchPanelController(
        keyword: widget.keyword,
        searchType: widget.searchType,
      ),
      tag: widget.searchType!.type + widget.keyword!,
    );

    /// 专栏默认排序
    if (widget.searchType == SearchType.article) {
      _searchPanelController.order.value = 'totalrank';
    }
    scrollController = _searchPanelController.scrollController;
    scrollController.addListener(() async {
      if (scrollController.position.pixels >=
          scrollController.position.maxScrollExtent - 100) {
        EasyThrottle.throttle('history', const Duration(seconds: 1), () {
          _searchPanelController.onSearch(type: 'onLoad');
        });
      }
    });
    _futureBuilderFuture = _searchPanelController.onSearch();
  }

  @override
  void dispose() {
    scrollController.removeListener(() {});
    super.dispose();
  }

  // 所有非“视频”类型的公共“精准”开关条
  Widget _exactToggleBar() {
    return Container(
      width: double.infinity,
      height: 36,
      padding: const EdgeInsets.only(left: 8, right: 12),
      color: Theme.of(context).colorScheme.surface,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Obx(
          () => FilterChip(
            label: const Text('精准'),
            selected: _searchPanelController.order.value == 'exact',
            showCheckmark: false,
            labelStyle: TextStyle(
              color: _searchPanelController.order.value == 'exact'
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
            ),
            selectedColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            side: BorderSide.none,
            onSelected: (selected) async {
              _searchPanelController.order.value = selected ? 'exact' : '';
              await _searchPanelController.onRefresh();
            },
          ),
        ),
      ),
    );
  }

  // 包装一个带“精准开关”的内容（仅非视频类型使用）
  Widget _withExactBar(Widget child) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 36),
          child: child,
        ),
        _exactToggleBar(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: () async {
        await _searchPanelController.onRefresh();
      },
      child: FutureBuilder(
        future: _futureBuilderFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.data != null) {
              Map data = snapshot.data as Map;
              var ctr = _searchPanelController;
              RxList list = ctr.resultList;
              if (data['status']) {
                return Obx(() {
                  // 根据搜索类型选择渲染内容
                  switch (widget.searchType) {
                    case SearchType.video:
                      // 视频类型：保留原有视频面板（自带“精准/筛选”UI）
                      return SearchVideoPanel(
                        ctr: _searchPanelController,
                        list: list.value,
                      );

                    case SearchType.media_bangumi:
                      // 番剧：在列表上方添加“精准”开关
                      return _withExactBar(
                        searchMbangumiPanel(context, ctr, list),
                      );

                    case SearchType.bili_user:
                      // 用户：在列表上方添加“精准”开关
                      return _withExactBar(
                        searchUserPanel(context, ctr, list),
                      );

                    case SearchType.live_room:
                      // 直播：在列表上方添加“精准”开关
                      return _withExactBar(
                        searchLivePanel(context, ctr, list),
                      );

                    case SearchType.article:
                      // 专栏：在列表上方添加“精准”开关
                      return _withExactBar(
                        SearchArticlePanel(
                          ctr: _searchPanelController,
                          list: list.value,
                        ),
                      );

                    default:
                      return const SizedBox();
                  }
                });
              } else {
                return CustomScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  slivers: [
                    HttpError(
                      errMsg: data['msg'],
                      fn: () {
                        setState(() {
                          _searchPanelController.onSearch();
                        });
                      },
                    ),
                  ],
                );
              }
            } else {
              return CustomScrollView(
                physics: const NeverScrollableScrollPhysics(),
                slivers: [
                  HttpError(
                    errMsg: '没有相关数据',
                    fn: () {
                      setState(() {
                        _searchPanelController.onSearch();
                      });
                    },
                  ),
                ],
              );
            }
          } else {
            // 骨架屏
            return ListView.builder(
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: false,
              itemCount: 15,
              itemBuilder: (context, index) {
                switch (widget.searchType) {
                  case SearchType.video:
                    return const VideoCardHSkeleton();
                  case SearchType.media_bangumi:
                    return const MediaBangumiSkeleton();
                  case SearchType.bili_user:
                    return const VideoCardHSkeleton();
                  case SearchType.live_room:
                    return const VideoCardHSkeleton();
                  default:
                    return const VideoCardHSkeleton();
                }
              },
            );
          }
        },
      ),
    );
  }
}
