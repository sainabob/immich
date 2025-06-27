import 'package:immich_mobile/entities/asset.entity.dart';
import 'package:immich_mobile/widgets/asset_grid/asset_grid_data_structure.dart';
import 'package:immich_mobile/entities/album.entity.dart';

class TagSearchResult {
  final List<Album> albums;
  final RenderList assets;

  TagSearchResult({
    required this.albums,
    required this.assets,
  });

  static TagSearchResult empty() {
    return TagSearchResult(
      albums: [],
      assets: RenderList.empty(),
    );
  }
}