import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/constants/enums.dart';
import 'package:immich_mobile/entities/asset.entity.dart';
import 'package:immich_mobile/entities/album.entity.dart';
import 'package:immich_mobile/models/tags/root_tag.model.dart';
import 'package:immich_mobile/models/tags/tag_search_result.model.dart';
import 'package:immich_mobile/models/albums/album_search.model.dart';
import 'package:immich_mobile/providers/api.provider.dart';
import 'package:immich_mobile/repositories/asset.repository.dart';
import 'package:immich_mobile/services/folder.service.dart';
import 'package:immich_mobile/services/album.service.dart';
import 'package:immich_mobile/widgets/asset_grid/asset_grid_data_structure.dart';
import 'package:logging/logging.dart';
import 'package:openapi/api.dart';
import 'package:immich_mobile/services/api.service.dart';
import 'package:flutter/foundation.dart';

final getAllTagsProvider =
    FutureProvider.autoDispose<List<TagResponseDto>>((ref) async {
  final ApiService searchService = ref.watch(apiServiceProvider);

  final assetTags = await searchService.tagsApi.getAllTags();

  if (assetTags == null) {
    return [];
  }

  return assetTags;
});

class TagsNotifier extends StateNotifier<AsyncValue<List<TagResponseDto>>> {
  final ApiService _apiService;
  final Logger _log = Logger("FolderStructureNotifier");

  TagsNotifier(this._apiService) : super(const AsyncLoading());

  Future<void> fetchTags() async {
    try {
      final tags = await _apiService.tagsApi.getAllTags();
      state = AsyncData(tags ?? []);
    } catch (e, stack) {
      _log.severe("Failed to fetch tags", e, stack);
      state = AsyncError(e, stack);
    }
  }
}

final tagsProvider =
    StateNotifierProvider<TagsNotifier, AsyncValue<List<TagResponseDto>>>(
        (ref) {
  return TagsNotifier(
    ref.watch(apiServiceProvider),
  );
});

class TagsRenderListNotifier extends StateNotifier<AsyncValue<TagSearchResult>> {
  final ApiService _apiService;
  final AssetRepository _assetRepository;
  final AlbumService _albumService;
  final TagResponseDto? _tag;
  final Logger _log = Logger("TagsRenderListNotifier");

  TagsRenderListNotifier(
    this._apiService,
    this._assetRepository,
    this._albumService,
    this._tag,
  ) : super(const AsyncLoading());

  Future<void> fetchAssets() async {
    try {
      if (_tag == null) {
        state = AsyncData(TagSearchResult.empty());
      } else {
        final results = await _apiService.searchApi
            .searchAssets(MetadataSearchDto(tagIds: [_tag!.id]));
        final resultingIds =
            (results?.assets.items ?? []).map((x) => x.id).toList();
        final assets = await _assetRepository.getAllByRemoteId(resultingIds);
        final renderList =
            await RenderList.fromAssets(assets, GroupAssetsBy.none);

        state = AsyncData(TagSearchResult(albums: [], assets: renderList));
      }
    } catch (e, stack) {
      _log.severe("Failed to fetch tag assets", e, stack);
      state = AsyncError(e, stack);
    }
  }

  Future<void> searchAlbums(String searchTerm, QuickFilterMode filterMode) async {
    debugPrint("===== 开始执行 searchAlbums: $searchTerm, $filterMode =====");
    try {
      if (_tag == null) {
        debugPrint("_tag 为空，返回空列表");
        state = AsyncData(TagSearchResult.empty());
        return;
      }

      // 使用本地数据库搜索相册（与相册页面一致）
      final albums = await _albumService.search(searchTerm, filterMode);
      debugPrint("本地搜索到的相册数量: ${albums.length}");

      // 获取标签相关的资产（保持原有逻辑）
      final results = await _apiService.searchApi
          .searchAssets(MetadataSearchDto(tagIds: [_tag!.id]));
      final resultingIds =
          (results?.assets.items ?? []).map((x) => x.id).toList();
      final assets = await _assetRepository.getAllByRemoteId(resultingIds);
      final renderList =
          await RenderList.fromAssets(assets, GroupAssetsBy.none);

      state = AsyncData(TagSearchResult(
        albums: albums, // 直接使用Album实体
        assets: renderList,
      ));
      debugPrint("状态已更新");
    } catch (e, stack) {
      debugPrint("搜索出错: $e");
      _log.severe("Failed to search albums", e, stack);
      state = AsyncError(e, stack);
    }
    debugPrint("===== 结束执行 searchAlbums =====");
  }

  // 保留原有的searchByTagName方法，但改为调用新的searchAlbums方法
  Future<void> searchByTagName(String tagName) async {
    await searchAlbums(tagName, QuickFilterMode.all);
  }
}

final tagsRenderListProvider = StateNotifierProvider.family<
    TagsRenderListNotifier,
    AsyncValue<TagSearchResult>,
    TagResponseDto?>((ref, folder) {
  return TagsRenderListNotifier(
    ref.watch(apiServiceProvider),
    ref.watch(assetRepositoryProvider),
    ref.watch(albumServiceProvider),
    folder,
  );
});
