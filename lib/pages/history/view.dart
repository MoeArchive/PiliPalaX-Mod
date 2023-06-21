import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipala/common/skeleton/video_card_h.dart';
import 'package:pilipala/common/widgets/http_error.dart';
import 'package:pilipala/pages/history/index.dart';

import 'widgets/item.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final HistoryController _historyController = Get.put(HistoryController());
  Future? _futureBuilderFuture;

  @override
  void initState() {
    _futureBuilderFuture = _historyController.queryHistoryList();
    super.initState();

    _historyController.scrollController.addListener(
      () {
        if (_historyController.scrollController.position.pixels >=
            _historyController.scrollController.position.maxScrollExtent -
                300) {
          if (!_historyController.isLoadingMore) {
            _historyController.onLoad();
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('观看记录'),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _historyController.onRefresh();
          return;
        },
        child: CustomScrollView(
          controller: _historyController.scrollController,
          slivers: [
            FutureBuilder(
              future: _futureBuilderFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  Map data = snapshot.data;
                  if (data['status']) {
                    return Obx(
                      () => SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          return HistoryItem(
                            videoItem: _historyController.historyList[index],
                          );
                        }, childCount: _historyController.historyList.length),
                      ),
                    );
                  } else {
                    return HttpError(
                      errMsg: data['msg'],
                      fn: () => setState(() {}),
                    );
                  }
                } else {
                  // 骨架屏
                  return SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return const VideoCardHSkeleton();
                    }, childCount: 10),
                  );
                }
              },
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.of(context).padding.bottom + 10,
              ),
            )
          ],
        ),
      ),
    );
  }
}