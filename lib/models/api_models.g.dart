// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LoginRequest _$LoginRequestFromJson(Map<String, dynamic> json) => LoginRequest(
  username: json['username'] as String,
  password: json['password'] as String,
);

Map<String, dynamic> _$LoginRequestToJson(LoginRequest instance) =>
    <String, dynamic>{
      'username': instance.username,
      'password': instance.password,
    };

LoginResponse _$LoginResponseFromJson(Map<String, dynamic> json) =>
    LoginResponse(
      userId: (json['user_id'] as num).toInt(),
      username: json['username'] as String,
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: (json['expires_in'] as num).toInt(),
    );

Map<String, dynamic> _$LoginResponseToJson(LoginResponse instance) =>
    <String, dynamic>{
      'user_id': instance.userId,
      'username': instance.username,
      'access_token': instance.accessToken,
      'refresh_token': instance.refreshToken,
      'expires_in': instance.expiresIn,
    };

RefreshTokenRequest _$RefreshTokenRequestFromJson(Map<String, dynamic> json) =>
    RefreshTokenRequest(refreshToken: json['refresh_token'] as String);

Map<String, dynamic> _$RefreshTokenRequestToJson(
  RefreshTokenRequest instance,
) => <String, dynamic>{'refresh_token': instance.refreshToken};

RefreshTokenResponse _$RefreshTokenResponseFromJson(
  Map<String, dynamic> json,
) => RefreshTokenResponse(
  accessToken: json['access_token'] as String,
  expiresIn: (json['expires_in'] as num).toInt(),
);

Map<String, dynamic> _$RefreshTokenResponseToJson(
  RefreshTokenResponse instance,
) => <String, dynamic>{
  'access_token': instance.accessToken,
  'expires_in': instance.expiresIn,
};

ProductDto _$ProductDtoFromJson(Map<String, dynamic> json) => ProductDto(
  janCode: json['jan_code'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  imagePath: json['image_path'] as String?,
  deptNumber: (json['dept_number'] as num).toInt(),
  salesPeriod: (json['sales_period'] as num).toInt(),
  serverModifiedAt: json['server_modified_at'] as String?,
  modifiedBy: (json['modified_by'] as num?)?.toInt(),
);

Map<String, dynamic> _$ProductDtoToJson(ProductDto instance) =>
    <String, dynamic>{
      'jan_code': instance.janCode,
      'name': instance.name,
      'description': instance.description,
      'image_path': instance.imagePath,
      'dept_number': instance.deptNumber,
      'sales_period': instance.salesPeriod,
      'server_modified_at': instance.serverModifiedAt,
      'modified_by': instance.modifiedBy,
    };

ProductSyncRequest _$ProductSyncRequestFromJson(Map<String, dynamic> json) =>
    ProductSyncRequest(
      lastSyncTimestamp: json['last_sync_timestamp'] as String,
      clientTimestamp: json['client_timestamp'] as String,
      products: (json['products'] as List<dynamic>)
          .map((e) => ProductUpdateDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ProductSyncRequestToJson(ProductSyncRequest instance) =>
    <String, dynamic>{
      'last_sync_timestamp': instance.lastSyncTimestamp,
      'client_timestamp': instance.clientTimestamp,
      'products': instance.products,
    };

ProductUpdateDto _$ProductUpdateDtoFromJson(Map<String, dynamic> json) =>
    ProductUpdateDto(
      janCode: json['jan_code'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      imagePath: json['image_path'] as String?,
      deptNumber: (json['dept_number'] as num).toInt(),
      salesPeriod: (json['sales_period'] as num).toInt(),
      operation: json['operation'] as String,
    );

Map<String, dynamic> _$ProductUpdateDtoToJson(ProductUpdateDto instance) =>
    <String, dynamic>{
      'jan_code': instance.janCode,
      'name': instance.name,
      'description': instance.description,
      'image_path': instance.imagePath,
      'dept_number': instance.deptNumber,
      'sales_period': instance.salesPeriod,
      'operation': instance.operation,
    };

ProductSyncResponse _$ProductSyncResponseFromJson(Map<String, dynamic> json) =>
    ProductSyncResponse(
      appliedCount: (json['applied_count'] as num).toInt(),
      serverChanges: (json['server_changes'] as List<dynamic>)
          .map((e) => ProductDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      conflicts: (json['conflicts'] as List<dynamic>)
          .map((e) => ProductConflict.fromJson(e as Map<String, dynamic>))
          .toList(),
      serverTimestamp: json['server_timestamp'] as String,
    );

Map<String, dynamic> _$ProductSyncResponseToJson(
  ProductSyncResponse instance,
) => <String, dynamic>{
  'applied_count': instance.appliedCount,
  'server_changes': instance.serverChanges,
  'conflicts': instance.conflicts,
  'server_timestamp': instance.serverTimestamp,
};

ProductConflict _$ProductConflictFromJson(Map<String, dynamic> json) =>
    ProductConflict(
      janCode: json['jan_code'] as String,
      conflictType: json['conflict_type'] as String,
      serverVersion: ProductDto.fromJson(
        json['server_version'] as Map<String, dynamic>,
      ),
      clientVersion: ProductUpdateDto.fromJson(
        json['client_version'] as Map<String, dynamic>,
      ),
      resolution: json['resolution'] as String,
    );

Map<String, dynamic> _$ProductConflictToJson(ProductConflict instance) =>
    <String, dynamic>{
      'jan_code': instance.janCode,
      'conflict_type': instance.conflictType,
      'server_version': instance.serverVersion,
      'client_version': instance.clientVersion,
      'resolution': instance.resolution,
    };

InventoryDto _$InventoryDtoFromJson(Map<String, dynamic> json) => InventoryDto(
  id: (json['id'] as num).toInt(),
  janCode: json['jan_code'] as String,
  quantity: (json['quantity'] as num).toInt(),
  expirationDate: json['expiration_date'] as String,
  registrationDate: json['registration_date'] as String,
  isArchived: json['is_archived'] as bool,
  serverModifiedAt: json['server_modified_at'] as String?,
  modifiedBy: (json['modified_by'] as num?)?.toInt(),
);

Map<String, dynamic> _$InventoryDtoToJson(InventoryDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'jan_code': instance.janCode,
      'quantity': instance.quantity,
      'expiration_date': instance.expirationDate,
      'registration_date': instance.registrationDate,
      'is_archived': instance.isArchived,
      'server_modified_at': instance.serverModifiedAt,
      'modified_by': instance.modifiedBy,
    };

InventoryUpdateDto _$InventoryUpdateDtoFromJson(Map<String, dynamic> json) =>
    InventoryUpdateDto(
      id: (json['id'] as num?)?.toInt(),
      janCode: json['jan_code'] as String,
      quantity: (json['quantity'] as num).toInt(),
      expirationDate: json['expiration_date'] as String,
      registrationDate: json['registration_date'] as String,
      isArchived: json['is_archived'] as bool,
      operation: json['operation'] as String,
    );

Map<String, dynamic> _$InventoryUpdateDtoToJson(InventoryUpdateDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'jan_code': instance.janCode,
      'quantity': instance.quantity,
      'expiration_date': instance.expirationDate,
      'registration_date': instance.registrationDate,
      'is_archived': instance.isArchived,
      'operation': instance.operation,
    };

InventorySyncRequest _$InventorySyncRequestFromJson(
  Map<String, dynamic> json,
) => InventorySyncRequest(
  lastSyncTimestamp: json['last_sync_timestamp'] as String,
  clientTimestamp: json['client_timestamp'] as String,
  inventories: (json['inventories'] as List<dynamic>)
      .map((e) => InventoryUpdateDto.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$InventorySyncRequestToJson(
  InventorySyncRequest instance,
) => <String, dynamic>{
  'last_sync_timestamp': instance.lastSyncTimestamp,
  'client_timestamp': instance.clientTimestamp,
  'inventories': instance.inventories,
};

InventorySyncResponse _$InventorySyncResponseFromJson(
  Map<String, dynamic> json,
) => InventorySyncResponse(
  appliedCount: (json['applied_count'] as num).toInt(),
  createdIds: (json['created_ids'] as List<dynamic>)
      .map((e) => CreatedIdMapping.fromJson(e as Map<String, dynamic>))
      .toList(),
  serverChanges: (json['server_changes'] as List<dynamic>)
      .map((e) => InventoryDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  conflicts: (json['conflicts'] as List<dynamic>)
      .map((e) => InventoryConflict.fromJson(e as Map<String, dynamic>))
      .toList(),
  serverTimestamp: json['server_timestamp'] as String,
);

Map<String, dynamic> _$InventorySyncResponseToJson(
  InventorySyncResponse instance,
) => <String, dynamic>{
  'applied_count': instance.appliedCount,
  'created_ids': instance.createdIds,
  'server_changes': instance.serverChanges,
  'conflicts': instance.conflicts,
  'server_timestamp': instance.serverTimestamp,
};

CreatedIdMapping _$CreatedIdMappingFromJson(Map<String, dynamic> json) =>
    CreatedIdMapping(
      clientTempId: json['client_temp_id'] as String?,
      serverId: (json['server_id'] as num).toInt(),
    );

Map<String, dynamic> _$CreatedIdMappingToJson(CreatedIdMapping instance) =>
    <String, dynamic>{
      'client_temp_id': instance.clientTempId,
      'server_id': instance.serverId,
    };

InventoryConflict _$InventoryConflictFromJson(Map<String, dynamic> json) =>
    InventoryConflict(
      id: (json['id'] as num).toInt(),
      conflictType: json['conflict_type'] as String,
      serverVersion: InventoryDto.fromJson(
        json['server_version'] as Map<String, dynamic>,
      ),
      clientVersion: InventoryUpdateDto.fromJson(
        json['client_version'] as Map<String, dynamic>,
      ),
      resolution: json['resolution'] as String,
    );

Map<String, dynamic> _$InventoryConflictToJson(InventoryConflict instance) =>
    <String, dynamic>{
      'id': instance.id,
      'conflict_type': instance.conflictType,
      'server_version': instance.serverVersion,
      'client_version': instance.clientVersion,
      'resolution': instance.resolution,
    };

DepartmentDto _$DepartmentDtoFromJson(Map<String, dynamic> json) =>
    DepartmentDto(
      deptNumber: (json['dept_number'] as num).toInt(),
      name: json['name'] as String,
    );

Map<String, dynamic> _$DepartmentDtoToJson(DepartmentDto instance) =>
    <String, dynamic>{
      'dept_number': instance.deptNumber,
      'name': instance.name,
    };

SuccessResponse<T> _$SuccessResponseFromJson<T>(
  Map<String, dynamic> json,
  T Function(Object? json) fromJsonT,
) => SuccessResponse<T>(
  status: json['status'] as String,
  data: fromJsonT(json['data']),
  timestamp: json['timestamp'] as String,
);

Map<String, dynamic> _$SuccessResponseToJson<T>(
  SuccessResponse<T> instance,
  Object? Function(T value) toJsonT,
) => <String, dynamic>{
  'status': instance.status,
  'data': toJsonT(instance.data),
  'timestamp': instance.timestamp,
};

ErrorResponse _$ErrorResponseFromJson(Map<String, dynamic> json) =>
    ErrorResponse(
      status: json['status'] as String,
      error: ErrorDetail.fromJson(json['error'] as Map<String, dynamic>),
      timestamp: json['timestamp'] as String,
    );

Map<String, dynamic> _$ErrorResponseToJson(ErrorResponse instance) =>
    <String, dynamic>{
      'status': instance.status,
      'error': instance.error,
      'timestamp': instance.timestamp,
    };

ErrorDetail _$ErrorDetailFromJson(Map<String, dynamic> json) => ErrorDetail(
  code: json['code'] as String,
  message: json['message'] as String,
);

Map<String, dynamic> _$ErrorDetailToJson(ErrorDetail instance) =>
    <String, dynamic>{'code': instance.code, 'message': instance.message};

ProductListResponse _$ProductListResponseFromJson(Map<String, dynamic> json) =>
    ProductListResponse(
      products: (json['products'] as List<dynamic>)
          .map((e) => ProductDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: (json['total_count'] as num).toInt(),
      serverTimestamp: json['server_timestamp'] as String,
    );

Map<String, dynamic> _$ProductListResponseToJson(
  ProductListResponse instance,
) => <String, dynamic>{
  'products': instance.products,
  'total_count': instance.totalCount,
  'server_timestamp': instance.serverTimestamp,
};

InventoryListResponse _$InventoryListResponseFromJson(
  Map<String, dynamic> json,
) => InventoryListResponse(
  inventories: (json['inventories'] as List<dynamic>)
      .map((e) => InventoryDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  totalCount: (json['total_count'] as num).toInt(),
  serverTimestamp: json['server_timestamp'] as String,
);

Map<String, dynamic> _$InventoryListResponseToJson(
  InventoryListResponse instance,
) => <String, dynamic>{
  'inventories': instance.inventories,
  'total_count': instance.totalCount,
  'server_timestamp': instance.serverTimestamp,
};

DepartmentListResponse _$DepartmentListResponseFromJson(
  Map<String, dynamic> json,
) => DepartmentListResponse(
  departments: (json['departments'] as List<dynamic>)
      .map((e) => DepartmentDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  serverTimestamp: json['server_timestamp'] as String,
);

Map<String, dynamic> _$DepartmentListResponseToJson(
  DepartmentListResponse instance,
) => <String, dynamic>{
  'departments': instance.departments,
  'server_timestamp': instance.serverTimestamp,
};
