// API Request/Response models

import 'package:json_annotation/json_annotation.dart';

part 'api_models.g.dart';

// ==================== Authentication Models ====================

@JsonSerializable()
class LoginRequest {
  final String username;
  final String password;

  LoginRequest({required this.username, required this.password});

  factory LoginRequest.fromJson(Map<String, dynamic> json) =>
      _$LoginRequestFromJson(json);
  Map<String, dynamic> toJson() => _$LoginRequestToJson(this);
}

@JsonSerializable()
class LoginResponse {
  @JsonKey(name: 'user_id')
  final int userId;
  final String username;
  @JsonKey(name: 'access_token')
  final String accessToken;
  @JsonKey(name: 'refresh_token')
  final String refreshToken;
  @JsonKey(name: 'expires_in')
  final int expiresIn;

  LoginResponse({
    required this.userId,
    required this.username,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) =>
      _$LoginResponseFromJson(json);
  Map<String, dynamic> toJson() => _$LoginResponseToJson(this);
}

@JsonSerializable()
class RefreshTokenRequest {
  @JsonKey(name: 'refresh_token')
  final String refreshToken;

  RefreshTokenRequest({required this.refreshToken});

  factory RefreshTokenRequest.fromJson(Map<String, dynamic> json) =>
      _$RefreshTokenRequestFromJson(json);
  Map<String, dynamic> toJson() => _$RefreshTokenRequestToJson(this);
}

@JsonSerializable()
class RefreshTokenResponse {
  @JsonKey(name: 'access_token')
  final String accessToken;
  @JsonKey(name: 'expires_in')
  final int expiresIn;

  RefreshTokenResponse({
    required this.accessToken,
    required this.expiresIn,
  });

  factory RefreshTokenResponse.fromJson(Map<String, dynamic> json) =>
      _$RefreshTokenResponseFromJson(json);
  Map<String, dynamic> toJson() => _$RefreshTokenResponseToJson(this);
}

// ==================== Product Models ====================

@JsonSerializable()
class ProductDto {
  @JsonKey(name: 'jan_code')
  final String janCode;
  final String name;
  final String? description;
  @JsonKey(name: 'image_path')
  final String? imagePath;
  @JsonKey(name: 'dept_number')
  final int deptNumber;
  @JsonKey(name: 'sales_period')
  final int salesPeriod;
  @JsonKey(name: 'server_modified_at')
  final String? serverModifiedAt;
  @JsonKey(name: 'modified_by')
  final int? modifiedBy;

  ProductDto({
    required this.janCode,
    required this.name,
    this.description,
    this.imagePath,
    required this.deptNumber,
    required this.salesPeriod,
    this.serverModifiedAt,
    this.modifiedBy,
  });

  factory ProductDto.fromJson(Map<String, dynamic> json) =>
      _$ProductDtoFromJson(json);
  Map<String, dynamic> toJson() => _$ProductDtoToJson(this);
}

@JsonSerializable()
class ProductSyncRequest {
  @JsonKey(name: 'last_sync_timestamp')
  final String lastSyncTimestamp;
  @JsonKey(name: 'client_timestamp')
  final String clientTimestamp;
  final List<ProductUpdateDto> products;

  ProductSyncRequest({
    required this.lastSyncTimestamp,
    required this.clientTimestamp,
    required this.products,
  });

  factory ProductSyncRequest.fromJson(Map<String, dynamic> json) =>
      _$ProductSyncRequestFromJson(json);
  Map<String, dynamic> toJson() => _$ProductSyncRequestToJson(this);
}

@JsonSerializable()
class ProductUpdateDto {
  @JsonKey(name: 'jan_code')
  final String janCode;
  final String name;
  final String? description;
  @JsonKey(name: 'image_path')
  final String? imagePath;
  @JsonKey(name: 'dept_number')
  final int deptNumber;
  @JsonKey(name: 'sales_period')
  final int salesPeriod;
  final String operation; // create, update, delete

  ProductUpdateDto({
    required this.janCode,
    required this.name,
    this.description,
    this.imagePath,
    required this.deptNumber,
    required this.salesPeriod,
    required this.operation,
  });

  factory ProductUpdateDto.fromJson(Map<String, dynamic> json) =>
      _$ProductUpdateDtoFromJson(json);
  Map<String, dynamic> toJson() => _$ProductUpdateDtoToJson(this);
}

@JsonSerializable()
class ProductSyncResponse {
  @JsonKey(name: 'applied_count')
  final int appliedCount;
  @JsonKey(name: 'server_changes')
  final List<ProductDto> serverChanges;
  final List<ProductConflict> conflicts;
  @JsonKey(name: 'server_timestamp')
  final String serverTimestamp;

  ProductSyncResponse({
    required this.appliedCount,
    required this.serverChanges,
    required this.conflicts,
    required this.serverTimestamp,
  });

  factory ProductSyncResponse.fromJson(Map<String, dynamic> json) =>
      _$ProductSyncResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ProductSyncResponseToJson(this);
}

@JsonSerializable()
class ProductConflict {
  @JsonKey(name: 'jan_code')
  final String janCode;
  @JsonKey(name: 'conflict_type')
  final String conflictType; // newer_on_server, newer_on_client
  @JsonKey(name: 'server_version')
  final ProductDto serverVersion;
  @JsonKey(name: 'client_version')
  final ProductUpdateDto clientVersion;
  final String resolution; // server_wins, client_wins

  ProductConflict({
    required this.janCode,
    required this.conflictType,
    required this.serverVersion,
    required this.clientVersion,
    required this.resolution,
  });

  factory ProductConflict.fromJson(Map<String, dynamic> json) =>
      _$ProductConflictFromJson(json);
  Map<String, dynamic> toJson() => _$ProductConflictToJson(this);
}

// ==================== Inventory Models ====================

@JsonSerializable()
class InventoryDto {
  final int id;
  @JsonKey(name: 'jan_code')
  final String janCode;
  final int quantity;
  @JsonKey(name: 'expiration_date')
  final String expirationDate;
  @JsonKey(name: 'registration_date')
  final String registrationDate;
  @JsonKey(name: 'is_archived')
  final bool isArchived;
  @JsonKey(name: 'server_modified_at')
  final String? serverModifiedAt;
  @JsonKey(name: 'modified_by')
  final int? modifiedBy;

  InventoryDto({
    required this.id,
    required this.janCode,
    required this.quantity,
    required this.expirationDate,
    required this.registrationDate,
    required this.isArchived,
    this.serverModifiedAt,
    this.modifiedBy,
  });

  factory InventoryDto.fromJson(Map<String, dynamic> json) =>
      _$InventoryDtoFromJson(json);
  Map<String, dynamic> toJson() => _$InventoryDtoToJson(this);
}

@JsonSerializable()
class InventoryUpdateDto {
  final int? id; // null for new items
  @JsonKey(name: 'jan_code')
  final String janCode;
  final int quantity;
  @JsonKey(name: 'expiration_date')
  final String expirationDate;
  @JsonKey(name: 'registration_date')
  final String registrationDate;
  @JsonKey(name: 'is_archived')
  final bool isArchived;
  final String operation; // create, update, delete

  InventoryUpdateDto({
    required this.id,
    required this.janCode,
    required this.quantity,
    required this.expirationDate,
    required this.registrationDate,
    required this.isArchived,
    required this.operation,
  });

  factory InventoryUpdateDto.fromJson(Map<String, dynamic> json) =>
      _$InventoryUpdateDtoFromJson(json);
  Map<String, dynamic> toJson() => _$InventoryUpdateDtoToJson(this);
}

@JsonSerializable()
class InventorySyncRequest {
  @JsonKey(name: 'last_sync_timestamp')
  final String lastSyncTimestamp;
  @JsonKey(name: 'client_timestamp')
  final String clientTimestamp;
  final List<InventoryUpdateDto> inventories;

  InventorySyncRequest({
    required this.lastSyncTimestamp,
    required this.clientTimestamp,
    required this.inventories,
  });

  factory InventorySyncRequest.fromJson(Map<String, dynamic> json) =>
      _$InventorySyncRequestFromJson(json);
  Map<String, dynamic> toJson() => _$InventorySyncRequestToJson(this);
}

@JsonSerializable()
class InventorySyncResponse {
  @JsonKey(name: 'applied_count')
  final int appliedCount;
  @JsonKey(name: 'created_ids')
  final List<CreatedIdMapping> createdIds;
  @JsonKey(name: 'server_changes')
  final List<InventoryDto> serverChanges;
  final List<InventoryConflict> conflicts;
  @JsonKey(name: 'server_timestamp')
  final String serverTimestamp;

  InventorySyncResponse({
    required this.appliedCount,
    required this.createdIds,
    required this.serverChanges,
    required this.conflicts,
    required this.serverTimestamp,
  });

  factory InventorySyncResponse.fromJson(Map<String, dynamic> json) =>
      _$InventorySyncResponseFromJson(json);
  Map<String, dynamic> toJson() => _$InventorySyncResponseToJson(this);
}

@JsonSerializable()
class CreatedIdMapping {
  @JsonKey(name: 'client_temp_id')
  final String? clientTempId;
  @JsonKey(name: 'server_id')
  final int serverId;

  CreatedIdMapping({
    required this.clientTempId,
    required this.serverId,
  });

  factory CreatedIdMapping.fromJson(Map<String, dynamic> json) =>
      _$CreatedIdMappingFromJson(json);
  Map<String, dynamic> toJson() => _$CreatedIdMappingToJson(this);
}

@JsonSerializable()
class InventoryConflict {
  final int id;
  @JsonKey(name: 'conflict_type')
  final String conflictType;
  @JsonKey(name: 'server_version')
  final InventoryDto serverVersion;
  @JsonKey(name: 'client_version')
  final InventoryUpdateDto clientVersion;
  final String resolution;

  InventoryConflict({
    required this.id,
    required this.conflictType,
    required this.serverVersion,
    required this.clientVersion,
    required this.resolution,
  });

  factory InventoryConflict.fromJson(Map<String, dynamic> json) =>
      _$InventoryConflictFromJson(json);
  Map<String, dynamic> toJson() => _$InventoryConflictToJson(this);
}

// ==================== Department Models ====================

@JsonSerializable()
class DepartmentDto {
  @JsonKey(name: 'dept_number')
  final int deptNumber;
  final String name;

  DepartmentDto({
    required this.deptNumber,
    required this.name,
  });

  factory DepartmentDto.fromJson(Map<String, dynamic> json) =>
      _$DepartmentDtoFromJson(json);
  Map<String, dynamic> toJson() => _$DepartmentDtoToJson(this);
}

// ==================== Generic Response Wrappers ====================

@JsonSerializable(genericArgumentFactories: true)
class SuccessResponse<T> {
  final String status;
  final T data;
  final String timestamp;

  SuccessResponse({
    required this.status,
    required this.data,
    required this.timestamp,
  });

  factory SuccessResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object?) fromJsonT,
  ) =>
      _$SuccessResponseFromJson(json, fromJsonT);
  Map<String, dynamic> toJson(Object Function(T value) toJsonT) =>
      _$SuccessResponseToJson(this, toJsonT);
}

@JsonSerializable()
class ErrorResponse {
  final String status;
  final ErrorDetail error;
  final String timestamp;

  ErrorResponse({
    required this.status,
    required this.error,
    required this.timestamp,
  });

  factory ErrorResponse.fromJson(Map<String, dynamic> json) =>
      _$ErrorResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ErrorResponseToJson(this);
}

@JsonSerializable()
class ErrorDetail {
  final String code;
  final String message;

  ErrorDetail({
    required this.code,
    required this.message,
  });

  factory ErrorDetail.fromJson(Map<String, dynamic> json) =>
      _$ErrorDetailFromJson(json);
  Map<String, dynamic> toJson() => _$ErrorDetailToJson(this);
}

// ==================== List Response Wrappers ====================

@JsonSerializable()
class ProductListResponse {
  final List<ProductDto> products;
  @JsonKey(name: 'total_count')
  final int totalCount;
  @JsonKey(name: 'server_timestamp')
  final String serverTimestamp;

  ProductListResponse({
    required this.products,
    required this.totalCount,
    required this.serverTimestamp,
  });

  factory ProductListResponse.fromJson(Map<String, dynamic> json) =>
      _$ProductListResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ProductListResponseToJson(this);
}

@JsonSerializable()
class InventoryListResponse {
  final List<InventoryDto> inventories;
  @JsonKey(name: 'total_count')
  final int totalCount;
  @JsonKey(name: 'server_timestamp')
  final String serverTimestamp;

  InventoryListResponse({
    required this.inventories,
    required this.totalCount,
    required this.serverTimestamp,
  });

  factory InventoryListResponse.fromJson(Map<String, dynamic> json) =>
      _$InventoryListResponseFromJson(json);
  Map<String, dynamic> toJson() => _$InventoryListResponseToJson(this);
}

@JsonSerializable()
class DepartmentListResponse {
  final List<DepartmentDto> departments;
  @JsonKey(name: 'server_timestamp')
  final String serverTimestamp;

  DepartmentListResponse({
    required this.departments,
    required this.serverTimestamp,
  });

  factory DepartmentListResponse.fromJson(Map<String, dynamic> json) =>
      _$DepartmentListResponseFromJson(json);
  Map<String, dynamic> toJson() => _$DepartmentListResponseToJson(this);
}
