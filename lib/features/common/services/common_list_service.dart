import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/services/collections_service.dart';
import 'package:jade/features/common/services/tag_movies_service.dart';

/// 装配点判空：按可用连接构造实体列表数据源，未登录/无连接返回不可用数据源。
TagMoviesDataSource defaultTagMoviesDataSource() =>
    switch (ApiClient.instanceOrNull) {
      final api? => TagMoviesService(api),
      null => const UnavailableTagMoviesDataSource(),
    };

/// 装配点判空：按可用连接构造收藏数据源，未登录/无连接返回不可用数据源。
FavoritesDataSource defaultFavoritesDataSource() =>
    switch (ApiClient.instanceOrNull) {
      final api? => FavoritesService(api),
      null => const UnavailableFavoritesDataSource(),
    };
