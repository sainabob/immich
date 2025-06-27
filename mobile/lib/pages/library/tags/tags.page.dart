// ignore_for_file: avoid-local-functions, prefer-single-widget-per-file, arguments-ordering, prefer-trailing-comma, prefer-for-loop-in-children, avoid-redundant-else, unnecessary-trailing-comma, function-always-returns-null

import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/constants/enums.dart';
import 'package:immich_mobile/entities/album.entity.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/extensions/theme_extensions.dart';
import 'package:immich_mobile/models/tags/recursive_tag.model.dart';
import 'package:immich_mobile/models/tags/root_tag.model.dart';
import 'package:immich_mobile/pages/common/large_leading_tile.dart';
import 'package:immich_mobile/providers/multiselect.provider.dart';
import 'package:immich_mobile/providers/tags.provider.dart';
import 'package:immich_mobile/providers/timeline.provider.dart';
import 'package:immich_mobile/repositories/tags_api.repository.dart';
import 'package:immich_mobile/routing/router.dart';
import 'package:immich_mobile/services/asset.service.dart';
import 'package:immich_mobile/services/timeline.service.dart';
import 'package:immich_mobile/utils/bytes_units.dart';
import 'package:immich_mobile/widgets/album/album_thumbnail_card.dart';
import 'package:immich_mobile/widgets/asset_grid/asset_grid_data_structure.dart';
import 'package:immich_mobile/widgets/asset_grid/multiselect_grid.dart';
import 'package:immich_mobile/widgets/asset_grid/thumbnail_image.dart';
import 'package:immich_mobile/widgets/common/immich_toast.dart';
import 'package:openapi/api.dart';
import 'package:immich_mobile/widgets/common/immich_app_bar.dart';
import 'package:flutter/foundation.dart';

@RoutePage()
class TagsPage extends HookConsumerWidget {
  final TagResponseDto? initalTag;

  const TagsPage({super.key, this.initalTag});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTag = useState<TagResponseDto?>(initalTag);
    final tagsProviderWatcher = ref.watch(tagsProvider);

    useEffect(
      () {
        ref.read(tagsProvider.notifier).fetchTags();
        if (currentTag.value != null) {
          // ref
          //     .read(tagsRenderListProvider(currentTag.value).notifier)
          //     .searchByTagName(currentTag.value!.name);
        }
        if (tagsProviderWatcher is AsyncData && tagsProviderWatcher.value != null && currentTag.value == null) {
          List<TagResponseDto> rootTags = tagsProviderWatcher.value!
              .where((x) => x.parentId == null)
              .toList();
          if (rootTags.isNotEmpty) {
            currentTag.value = rootTags.first;
            ref
                .read(tagsRenderListProvider(rootTags.first).notifier)
                .searchByTagName(rootTags.first.name);
          }
        }
      },
      [tagsProviderWatcher],
    );

    void selectTag(TagResponseDto selectedTag) {
      // 无论是一级标签还是子标签，都更新当前标签并搜索
      currentTag.value = selectedTag;
      // 搜索包含该标签名称的相册和资产
      ref.read(tagsRenderListProvider(selectedTag).notifier).searchByTagName(selectedTag.name);
    }

    Widget getHorizontalTagView(List<TagResponseDto> allTags) {
      List<TagResponseDto> rootTags = allTags.where((x) => x.parentId == null).toList();

      return Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 8),
          child: DefaultTabController(
            length: rootTags.length,
            child: TabBar(
              isScrollable: true,
              tabs: rootTags.map((tag) {
                return Tab(
                  text: tag.name,
                  // icon: isSelected ? Icon(Icons.check) : null,
                );
              }).toList(),
              onTap: (index) => selectTag(rootTags[index]),
              // indicator: const UnderlineTabIndicator(borderSide: BorderSide.none),
              // labelPadding: EdgeInsets.zero,
              // padding: EdgeInsets.zero,
              // splashFactory: NoSplash.splashFactory, // 去除点击水波纹效果
              
            ),
          ),
      
      );
    }

    Widget buildTagList(BuildContext context, WidgetRef ref) {
      final tagsAsyncValue = ref.watch(tagsProvider);

      return tagsAsyncValue.when(
        data: (alltags) {
          // 获取所有一级标签
          List<TagResponseDto> rootTags = alltags.where((x) => x.parentId == null).toList();

          // 如果当前选择的是二级标签，获取其父标签
          TagResponseDto? parentTag = currentTag.value?.parentId != null
              ? alltags.firstWhereOrNull((tag) => tag.id == currentTag.value?.parentId)
              : null;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              getHorizontalTagView(alltags), // 显示一级标签
              if (parentTag != null || (currentTag.value != null && currentTag.value!.parentId == null))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: alltags
                        .where((tag) =>
                            tag.parentId == (parentTag?.id ?? currentTag.value?.id))
                        .map((subTag) {
                      bool isSelected = currentTag.value?.name == subTag.name;
                      return FilterChip(
                        label: Text(subTag.name),
                        selected: isSelected,
                        onSelected: (_) => selectTag(subTag),
                        backgroundColor: Colors.transparent,
                        selectedColor: context.colorScheme.primaryContainer,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      );
                    })
                        .toList(),
                  ),
                ),
            ],
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (error, stack) {
          ImmichToast.show(
            context: context,
            msg: "failed_to_load_tags".tr(),
            toastType: ToastType.error,
          );
          return Center(child: const Text("failed_to_load_tags").tr());
        },
      );
    }

    MultiselectGrid buildMultiselectGrid() {
      return MultiselectGrid(
        // 使用 Provider 创建一个新的 ProviderListenable<AsyncValue<RenderList>>
        renderListProvider: Provider((ref) => ref.watch(tagsRenderListProvider(currentTag.value)).whenData((result) => result.assets)),
        favoriteEnabled: true,
        editEnabled: true,
        unfavorite: true,
      );
    }

    // 构建相册网格
    Widget buildAlbumGrid(List<Album> albums) {
      if (albums.isEmpty) {
        return const SizedBox.shrink();
      }
    
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.builder(
            physics: const ClampingScrollPhysics(),
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 250,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: .7,
            ),
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final album = albums[index];
              return AlbumGridItem(album: album); // 提取为独立组件
            },
          ),
          const SizedBox(height: 16),
        ],
      );
    }

    return Scaffold(
      appBar: const ImmichAppBar(),
      body: Column(
        children: [
          // 显示标签列表
          IntrinsicHeight(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.colorScheme.surface.withOpacity(0.8),
              ),
              child: buildTagList(context, ref),
            ),
          ),
          // 显示搜索结果（相册和资产）
          Expanded(
            child: ref.read(tagsRenderListProvider(currentTag.value)).when(
              data: (result) {
                return Column(
                  children: [
                    // 显示相册网格
                    buildAlbumGrid(result.albums),
                    // 显示资产网格
                    Expanded(
                      child: MultiselectGrid(
                        renderListProvider: Provider((ref) => ref.watch(tagsRenderListProvider(currentTag.value)).whenData((result) => result.assets)),
                        favoriteEnabled: true,
                        editEnabled: true,
                        unfavorite: true,
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) {
                return Center(child: Text("加载失败: $error"));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TagsPath extends StatelessWidget {
  final TagResponseDto? currentFolder;
  final List<TagResponseDto> root;

  const TagsPath({
    super.key,
    required this.currentFolder,
    required this.root,
  });

  @override
  Widget build(BuildContext context) {
    if (currentFolder == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                currentFolder!.value,
                style: TextStyle(
                  fontFamily: 'Inconsolata',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: context.colorScheme.onSurface.withAlpha(175),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AlbumGridItem extends HookWidget {
  final Album album;
  
  const AlbumGridItem({super.key, required this.album});
  
  @override
  Widget build(BuildContext context) {
    return AlbumThumbnailCard(
      album: album,
      onTap: () {
        context.pushRoute(AlbumViewerRoute(albumId: album.id));
      },
    );
  }
}
