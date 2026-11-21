// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_db.dart';

// ignore_for_file: type=lint
class $LocalStoresTable extends LocalStores
    with TableInfo<$LocalStoresTable, LocalStore> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalStoresTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [serverId, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_stores';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalStore> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serverId};
  @override
  LocalStore map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalStore(
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $LocalStoresTable createAlias(String alias) {
    return $LocalStoresTable(attachedDatabase, alias);
  }
}

class LocalStore extends DataClass implements Insertable<LocalStore> {
  final String serverId;
  final String name;
  const LocalStore({required this.serverId, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<String>(serverId);
    map['name'] = Variable<String>(name);
    return map;
  }

  LocalStoresCompanion toCompanion(bool nullToAbsent) {
    return LocalStoresCompanion(serverId: Value(serverId), name: Value(name));
  }

  factory LocalStore.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalStore(
      serverId: serializer.fromJson<String>(json['serverId']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<String>(serverId),
      'name': serializer.toJson<String>(name),
    };
  }

  LocalStore copyWith({String? serverId, String? name}) =>
      LocalStore(serverId: serverId ?? this.serverId, name: name ?? this.name);
  LocalStore copyWithCompanion(LocalStoresCompanion data) {
    return LocalStore(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalStore(')
          ..write('serverId: $serverId, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(serverId, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalStore &&
          other.serverId == this.serverId &&
          other.name == this.name);
}

class LocalStoresCompanion extends UpdateCompanion<LocalStore> {
  final Value<String> serverId;
  final Value<String> name;
  final Value<int> rowid;
  const LocalStoresCompanion({
    this.serverId = const Value.absent(),
    this.name = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalStoresCompanion.insert({
    required String serverId,
    required String name,
    this.rowid = const Value.absent(),
  }) : serverId = Value(serverId),
       name = Value(name);
  static Insertable<LocalStore> custom({
    Expression<String>? serverId,
    Expression<String>? name,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (name != null) 'name': name,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalStoresCompanion copyWith({
    Value<String>? serverId,
    Value<String>? name,
    Value<int>? rowid,
  }) {
    return LocalStoresCompanion(
      serverId: serverId ?? this.serverId,
      name: name ?? this.name,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalStoresCompanion(')
          ..write('serverId: $serverId, ')
          ..write('name: $name, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalUsersTable extends LocalUsers
    with TableInfo<$LocalUsersTable, LocalUser> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalUsersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storeIdMeta = const VerificationMeta(
    'storeId',
  );
  @override
  late final GeneratedColumn<String> storeId = GeneratedColumn<String>(
    'store_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [serverId, storeId, name, email];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_users';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalUser> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('store_id')) {
      context.handle(
        _storeIdMeta,
        storeId.isAcceptableOrUnknown(data['store_id']!, _storeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_storeIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serverId};
  @override
  LocalUser map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalUser(
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      storeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}store_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      )!,
    );
  }

  @override
  $LocalUsersTable createAlias(String alias) {
    return $LocalUsersTable(attachedDatabase, alias);
  }
}

class LocalUser extends DataClass implements Insertable<LocalUser> {
  final String serverId;
  final String storeId;
  final String name;
  final String email;
  const LocalUser({
    required this.serverId,
    required this.storeId,
    required this.name,
    required this.email,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<String>(serverId);
    map['store_id'] = Variable<String>(storeId);
    map['name'] = Variable<String>(name);
    map['email'] = Variable<String>(email);
    return map;
  }

  LocalUsersCompanion toCompanion(bool nullToAbsent) {
    return LocalUsersCompanion(
      serverId: Value(serverId),
      storeId: Value(storeId),
      name: Value(name),
      email: Value(email),
    );
  }

  factory LocalUser.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalUser(
      serverId: serializer.fromJson<String>(json['serverId']),
      storeId: serializer.fromJson<String>(json['storeId']),
      name: serializer.fromJson<String>(json['name']),
      email: serializer.fromJson<String>(json['email']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<String>(serverId),
      'storeId': serializer.toJson<String>(storeId),
      'name': serializer.toJson<String>(name),
      'email': serializer.toJson<String>(email),
    };
  }

  LocalUser copyWith({
    String? serverId,
    String? storeId,
    String? name,
    String? email,
  }) => LocalUser(
    serverId: serverId ?? this.serverId,
    storeId: storeId ?? this.storeId,
    name: name ?? this.name,
    email: email ?? this.email,
  );
  LocalUser copyWithCompanion(LocalUsersCompanion data) {
    return LocalUser(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      storeId: data.storeId.present ? data.storeId.value : this.storeId,
      name: data.name.present ? data.name.value : this.name,
      email: data.email.present ? data.email.value : this.email,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalUser(')
          ..write('serverId: $serverId, ')
          ..write('storeId: $storeId, ')
          ..write('name: $name, ')
          ..write('email: $email')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(serverId, storeId, name, email);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalUser &&
          other.serverId == this.serverId &&
          other.storeId == this.storeId &&
          other.name == this.name &&
          other.email == this.email);
}

class LocalUsersCompanion extends UpdateCompanion<LocalUser> {
  final Value<String> serverId;
  final Value<String> storeId;
  final Value<String> name;
  final Value<String> email;
  final Value<int> rowid;
  const LocalUsersCompanion({
    this.serverId = const Value.absent(),
    this.storeId = const Value.absent(),
    this.name = const Value.absent(),
    this.email = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalUsersCompanion.insert({
    required String serverId,
    required String storeId,
    required String name,
    required String email,
    this.rowid = const Value.absent(),
  }) : serverId = Value(serverId),
       storeId = Value(storeId),
       name = Value(name),
       email = Value(email);
  static Insertable<LocalUser> custom({
    Expression<String>? serverId,
    Expression<String>? storeId,
    Expression<String>? name,
    Expression<String>? email,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (storeId != null) 'store_id': storeId,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalUsersCompanion copyWith({
    Value<String>? serverId,
    Value<String>? storeId,
    Value<String>? name,
    Value<String>? email,
    Value<int>? rowid,
  }) {
    return LocalUsersCompanion(
      serverId: serverId ?? this.serverId,
      storeId: storeId ?? this.storeId,
      name: name ?? this.name,
      email: email ?? this.email,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (storeId.present) {
      map['store_id'] = Variable<String>(storeId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalUsersCompanion(')
          ..write('serverId: $serverId, ')
          ..write('storeId: $storeId, ')
          ..write('name: $name, ')
          ..write('email: $email, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProductsTable extends Products with TableInfo<$ProductsTable, Product> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProductsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storeIdMeta = const VerificationMeta(
    'storeId',
  );
  @override
  late final GeneratedColumn<String> storeId = GeneratedColumn<String>(
    'store_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _barcodeMeta = const VerificationMeta(
    'barcode',
  );
  @override
  late final GeneratedColumn<String> barcode = GeneratedColumn<String>(
    'barcode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _costPriceMeta = const VerificationMeta(
    'costPrice',
  );
  @override
  late final GeneratedColumn<int> costPrice = GeneratedColumn<int>(
    'cost_price',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sellPriceMeta = const VerificationMeta(
    'sellPrice',
  );
  @override
  late final GeneratedColumn<int> sellPrice = GeneratedColumn<int>(
    'sell_price',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stockMeta = const VerificationMeta('stock');
  @override
  late final GeneratedColumn<int> stock = GeneratedColumn<int>(
    'stock',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _photoPathMeta = const VerificationMeta(
    'photoPath',
  );
  @override
  late final GeneratedColumn<String> photoPath = GeneratedColumn<String>(
    'photo_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<int> dirty = GeneratedColumn<int>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    storeId,
    name,
    barcode,
    costPrice,
    sellPrice,
    stock,
    category,
    photoPath,
    isArchived,
    createdAt,
    updatedAt,
    deletedAt,
    dirty,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'products';
  @override
  VerificationContext validateIntegrity(
    Insertable<Product> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('store_id')) {
      context.handle(
        _storeIdMeta,
        storeId.isAcceptableOrUnknown(data['store_id']!, _storeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_storeIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('barcode')) {
      context.handle(
        _barcodeMeta,
        barcode.isAcceptableOrUnknown(data['barcode']!, _barcodeMeta),
      );
    }
    if (data.containsKey('cost_price')) {
      context.handle(
        _costPriceMeta,
        costPrice.isAcceptableOrUnknown(data['cost_price']!, _costPriceMeta),
      );
    } else if (isInserting) {
      context.missing(_costPriceMeta);
    }
    if (data.containsKey('sell_price')) {
      context.handle(
        _sellPriceMeta,
        sellPrice.isAcceptableOrUnknown(data['sell_price']!, _sellPriceMeta),
      );
    } else if (isInserting) {
      context.missing(_sellPriceMeta);
    }
    if (data.containsKey('stock')) {
      context.handle(
        _stockMeta,
        stock.isAcceptableOrUnknown(data['stock']!, _stockMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('photo_path')) {
      context.handle(
        _photoPathMeta,
        photoPath.isAcceptableOrUnknown(data['photo_path']!, _photoPathMeta),
      );
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {storeId, barcode},
  ];
  @override
  Product map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Product(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      storeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}store_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      barcode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}barcode'],
      ),
      costPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cost_price'],
      )!,
      sellPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sell_price'],
      )!,
      stock: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stock'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      photoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_path'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dirty'],
      )!,
    );
  }

  @override
  $ProductsTable createAlias(String alias) {
    return $ProductsTable(attachedDatabase, alias);
  }
}

class Product extends DataClass implements Insertable<Product> {
  final String id;
  final String storeId;
  final String name;
  final String? barcode;
  final int costPrice;
  final int sellPrice;
  final int stock;
  final String category;
  final String photoPath;
  final bool isArchived;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  final int dirty;
  const Product({
    required this.id,
    required this.storeId,
    required this.name,
    this.barcode,
    required this.costPrice,
    required this.sellPrice,
    required this.stock,
    required this.category,
    required this.photoPath,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.dirty,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['store_id'] = Variable<String>(storeId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || barcode != null) {
      map['barcode'] = Variable<String>(barcode);
    }
    map['cost_price'] = Variable<int>(costPrice);
    map['sell_price'] = Variable<int>(sellPrice);
    map['stock'] = Variable<int>(stock);
    map['category'] = Variable<String>(category);
    map['photo_path'] = Variable<String>(photoPath);
    map['is_archived'] = Variable<bool>(isArchived);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['dirty'] = Variable<int>(dirty);
    return map;
  }

  ProductsCompanion toCompanion(bool nullToAbsent) {
    return ProductsCompanion(
      id: Value(id),
      storeId: Value(storeId),
      name: Value(name),
      barcode: barcode == null && nullToAbsent
          ? const Value.absent()
          : Value(barcode),
      costPrice: Value(costPrice),
      sellPrice: Value(sellPrice),
      stock: Value(stock),
      category: Value(category),
      photoPath: Value(photoPath),
      isArchived: Value(isArchived),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      dirty: Value(dirty),
    );
  }

  factory Product.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Product(
      id: serializer.fromJson<String>(json['id']),
      storeId: serializer.fromJson<String>(json['storeId']),
      name: serializer.fromJson<String>(json['name']),
      barcode: serializer.fromJson<String?>(json['barcode']),
      costPrice: serializer.fromJson<int>(json['costPrice']),
      sellPrice: serializer.fromJson<int>(json['sellPrice']),
      stock: serializer.fromJson<int>(json['stock']),
      category: serializer.fromJson<String>(json['category']),
      photoPath: serializer.fromJson<String>(json['photoPath']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      dirty: serializer.fromJson<int>(json['dirty']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'storeId': serializer.toJson<String>(storeId),
      'name': serializer.toJson<String>(name),
      'barcode': serializer.toJson<String?>(barcode),
      'costPrice': serializer.toJson<int>(costPrice),
      'sellPrice': serializer.toJson<int>(sellPrice),
      'stock': serializer.toJson<int>(stock),
      'category': serializer.toJson<String>(category),
      'photoPath': serializer.toJson<String>(photoPath),
      'isArchived': serializer.toJson<bool>(isArchived),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'dirty': serializer.toJson<int>(dirty),
    };
  }

  Product copyWith({
    String? id,
    String? storeId,
    String? name,
    Value<String?> barcode = const Value.absent(),
    int? costPrice,
    int? sellPrice,
    int? stock,
    String? category,
    String? photoPath,
    bool? isArchived,
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    int? dirty,
  }) => Product(
    id: id ?? this.id,
    storeId: storeId ?? this.storeId,
    name: name ?? this.name,
    barcode: barcode.present ? barcode.value : this.barcode,
    costPrice: costPrice ?? this.costPrice,
    sellPrice: sellPrice ?? this.sellPrice,
    stock: stock ?? this.stock,
    category: category ?? this.category,
    photoPath: photoPath ?? this.photoPath,
    isArchived: isArchived ?? this.isArchived,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    dirty: dirty ?? this.dirty,
  );
  Product copyWithCompanion(ProductsCompanion data) {
    return Product(
      id: data.id.present ? data.id.value : this.id,
      storeId: data.storeId.present ? data.storeId.value : this.storeId,
      name: data.name.present ? data.name.value : this.name,
      barcode: data.barcode.present ? data.barcode.value : this.barcode,
      costPrice: data.costPrice.present ? data.costPrice.value : this.costPrice,
      sellPrice: data.sellPrice.present ? data.sellPrice.value : this.sellPrice,
      stock: data.stock.present ? data.stock.value : this.stock,
      category: data.category.present ? data.category.value : this.category,
      photoPath: data.photoPath.present ? data.photoPath.value : this.photoPath,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Product(')
          ..write('id: $id, ')
          ..write('storeId: $storeId, ')
          ..write('name: $name, ')
          ..write('barcode: $barcode, ')
          ..write('costPrice: $costPrice, ')
          ..write('sellPrice: $sellPrice, ')
          ..write('stock: $stock, ')
          ..write('category: $category, ')
          ..write('photoPath: $photoPath, ')
          ..write('isArchived: $isArchived, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dirty: $dirty')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    storeId,
    name,
    barcode,
    costPrice,
    sellPrice,
    stock,
    category,
    photoPath,
    isArchived,
    createdAt,
    updatedAt,
    deletedAt,
    dirty,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Product &&
          other.id == this.id &&
          other.storeId == this.storeId &&
          other.name == this.name &&
          other.barcode == this.barcode &&
          other.costPrice == this.costPrice &&
          other.sellPrice == this.sellPrice &&
          other.stock == this.stock &&
          other.category == this.category &&
          other.photoPath == this.photoPath &&
          other.isArchived == this.isArchived &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.dirty == this.dirty);
}

class ProductsCompanion extends UpdateCompanion<Product> {
  final Value<String> id;
  final Value<String> storeId;
  final Value<String> name;
  final Value<String?> barcode;
  final Value<int> costPrice;
  final Value<int> sellPrice;
  final Value<int> stock;
  final Value<String> category;
  final Value<String> photoPath;
  final Value<bool> isArchived;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> dirty;
  final Value<int> rowid;
  const ProductsCompanion({
    this.id = const Value.absent(),
    this.storeId = const Value.absent(),
    this.name = const Value.absent(),
    this.barcode = const Value.absent(),
    this.costPrice = const Value.absent(),
    this.sellPrice = const Value.absent(),
    this.stock = const Value.absent(),
    this.category = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProductsCompanion.insert({
    required String id,
    required String storeId,
    required String name,
    this.barcode = const Value.absent(),
    required int costPrice,
    required int sellPrice,
    this.stock = const Value.absent(),
    this.category = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.isArchived = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       storeId = Value(storeId),
       name = Value(name),
       costPrice = Value(costPrice),
       sellPrice = Value(sellPrice),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Product> custom({
    Expression<String>? id,
    Expression<String>? storeId,
    Expression<String>? name,
    Expression<String>? barcode,
    Expression<int>? costPrice,
    Expression<int>? sellPrice,
    Expression<int>? stock,
    Expression<String>? category,
    Expression<String>? photoPath,
    Expression<bool>? isArchived,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? dirty,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (storeId != null) 'store_id': storeId,
      if (name != null) 'name': name,
      if (barcode != null) 'barcode': barcode,
      if (costPrice != null) 'cost_price': costPrice,
      if (sellPrice != null) 'sell_price': sellPrice,
      if (stock != null) 'stock': stock,
      if (category != null) 'category': category,
      if (photoPath != null) 'photo_path': photoPath,
      if (isArchived != null) 'is_archived': isArchived,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (dirty != null) 'dirty': dirty,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProductsCompanion copyWith({
    Value<String>? id,
    Value<String>? storeId,
    Value<String>? name,
    Value<String?>? barcode,
    Value<int>? costPrice,
    Value<int>? sellPrice,
    Value<int>? stock,
    Value<String>? category,
    Value<String>? photoPath,
    Value<bool>? isArchived,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<int>? dirty,
    Value<int>? rowid,
  }) {
    return ProductsCompanion(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      costPrice: costPrice ?? this.costPrice,
      sellPrice: sellPrice ?? this.sellPrice,
      stock: stock ?? this.stock,
      category: category ?? this.category,
      photoPath: photoPath ?? this.photoPath,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      dirty: dirty ?? this.dirty,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (storeId.present) {
      map['store_id'] = Variable<String>(storeId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (barcode.present) {
      map['barcode'] = Variable<String>(barcode.value);
    }
    if (costPrice.present) {
      map['cost_price'] = Variable<int>(costPrice.value);
    }
    if (sellPrice.present) {
      map['sell_price'] = Variable<int>(sellPrice.value);
    }
    if (stock.present) {
      map['stock'] = Variable<int>(stock.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (photoPath.present) {
      map['photo_path'] = Variable<String>(photoPath.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<int>(dirty.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductsCompanion(')
          ..write('id: $id, ')
          ..write('storeId: $storeId, ')
          ..write('name: $name, ')
          ..write('barcode: $barcode, ')
          ..write('costPrice: $costPrice, ')
          ..write('sellPrice: $sellPrice, ')
          ..write('stock: $stock, ')
          ..write('category: $category, ')
          ..write('photoPath: $photoPath, ')
          ..write('isArchived: $isArchived, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dirty: $dirty, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SalesTable extends Sales with TableInfo<$SalesTable, Sale> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SalesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storeIdMeta = const VerificationMeta(
    'storeId',
  );
  @override
  late final GeneratedColumn<String> storeId = GeneratedColumn<String>(
    'store_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<String> number = GeneratedColumn<String>(
    'number',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<int> total = GeneratedColumn<int>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paidMeta = const VerificationMeta('paid');
  @override
  late final GeneratedColumn<int> paid = GeneratedColumn<int>(
    'paid',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _changeMeta = const VerificationMeta('change');
  @override
  late final GeneratedColumn<int> change = GeneratedColumn<int>(
    'change',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<String> method = GeneratedColumn<String>(
    'method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('ok'),
  );
  static const VerificationMeta _voidReasonMeta = const VerificationMeta(
    'voidReason',
  );
  @override
  late final GeneratedColumn<String> voidReason = GeneratedColumn<String>(
    'void_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _voidedAtMeta = const VerificationMeta(
    'voidedAt',
  );
  @override
  late final GeneratedColumn<int> voidedAt = GeneratedColumn<int>(
    'voided_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<int> dirty = GeneratedColumn<int>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    storeId,
    number,
    total,
    paid,
    change,
    method,
    status,
    voidReason,
    createdAt,
    updatedAt,
    voidedAt,
    dirty,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sales';
  @override
  VerificationContext validateIntegrity(
    Insertable<Sale> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('store_id')) {
      context.handle(
        _storeIdMeta,
        storeId.isAcceptableOrUnknown(data['store_id']!, _storeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_storeIdMeta);
    }
    if (data.containsKey('number')) {
      context.handle(
        _numberMeta,
        number.isAcceptableOrUnknown(data['number']!, _numberMeta),
      );
    } else if (isInserting) {
      context.missing(_numberMeta);
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    } else if (isInserting) {
      context.missing(_totalMeta);
    }
    if (data.containsKey('paid')) {
      context.handle(
        _paidMeta,
        paid.isAcceptableOrUnknown(data['paid']!, _paidMeta),
      );
    } else if (isInserting) {
      context.missing(_paidMeta);
    }
    if (data.containsKey('change')) {
      context.handle(
        _changeMeta,
        change.isAcceptableOrUnknown(data['change']!, _changeMeta),
      );
    }
    if (data.containsKey('method')) {
      context.handle(
        _methodMeta,
        method.isAcceptableOrUnknown(data['method']!, _methodMeta),
      );
    } else if (isInserting) {
      context.missing(_methodMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('void_reason')) {
      context.handle(
        _voidReasonMeta,
        voidReason.isAcceptableOrUnknown(data['void_reason']!, _voidReasonMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('voided_at')) {
      context.handle(
        _voidedAtMeta,
        voidedAt.isAcceptableOrUnknown(data['voided_at']!, _voidedAtMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {storeId, number},
  ];
  @override
  Sale map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Sale(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      storeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}store_id'],
      )!,
      number: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}number'],
      )!,
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total'],
      )!,
      paid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paid'],
      )!,
      change: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}change'],
      )!,
      method: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}method'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      voidReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}void_reason'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      ),
      voidedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}voided_at'],
      ),
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dirty'],
      )!,
    );
  }

  @override
  $SalesTable createAlias(String alias) {
    return $SalesTable(attachedDatabase, alias);
  }
}

class Sale extends DataClass implements Insertable<Sale> {
  final String id;
  final String storeId;
  final String number;
  final int total;
  final int paid;
  final int change;
  final String method;
  final String status;
  final String? voidReason;
  final int createdAt;
  final int? updatedAt;
  final int? voidedAt;
  final int dirty;
  const Sale({
    required this.id,
    required this.storeId,
    required this.number,
    required this.total,
    required this.paid,
    required this.change,
    required this.method,
    required this.status,
    this.voidReason,
    required this.createdAt,
    this.updatedAt,
    this.voidedAt,
    required this.dirty,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['store_id'] = Variable<String>(storeId);
    map['number'] = Variable<String>(number);
    map['total'] = Variable<int>(total);
    map['paid'] = Variable<int>(paid);
    map['change'] = Variable<int>(change);
    map['method'] = Variable<String>(method);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || voidReason != null) {
      map['void_reason'] = Variable<String>(voidReason);
    }
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<int>(updatedAt);
    }
    if (!nullToAbsent || voidedAt != null) {
      map['voided_at'] = Variable<int>(voidedAt);
    }
    map['dirty'] = Variable<int>(dirty);
    return map;
  }

  SalesCompanion toCompanion(bool nullToAbsent) {
    return SalesCompanion(
      id: Value(id),
      storeId: Value(storeId),
      number: Value(number),
      total: Value(total),
      paid: Value(paid),
      change: Value(change),
      method: Value(method),
      status: Value(status),
      voidReason: voidReason == null && nullToAbsent
          ? const Value.absent()
          : Value(voidReason),
      createdAt: Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      voidedAt: voidedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(voidedAt),
      dirty: Value(dirty),
    );
  }

  factory Sale.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Sale(
      id: serializer.fromJson<String>(json['id']),
      storeId: serializer.fromJson<String>(json['storeId']),
      number: serializer.fromJson<String>(json['number']),
      total: serializer.fromJson<int>(json['total']),
      paid: serializer.fromJson<int>(json['paid']),
      change: serializer.fromJson<int>(json['change']),
      method: serializer.fromJson<String>(json['method']),
      status: serializer.fromJson<String>(json['status']),
      voidReason: serializer.fromJson<String?>(json['voidReason']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int?>(json['updatedAt']),
      voidedAt: serializer.fromJson<int?>(json['voidedAt']),
      dirty: serializer.fromJson<int>(json['dirty']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'storeId': serializer.toJson<String>(storeId),
      'number': serializer.toJson<String>(number),
      'total': serializer.toJson<int>(total),
      'paid': serializer.toJson<int>(paid),
      'change': serializer.toJson<int>(change),
      'method': serializer.toJson<String>(method),
      'status': serializer.toJson<String>(status),
      'voidReason': serializer.toJson<String?>(voidReason),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int?>(updatedAt),
      'voidedAt': serializer.toJson<int?>(voidedAt),
      'dirty': serializer.toJson<int>(dirty),
    };
  }

  Sale copyWith({
    String? id,
    String? storeId,
    String? number,
    int? total,
    int? paid,
    int? change,
    String? method,
    String? status,
    Value<String?> voidReason = const Value.absent(),
    int? createdAt,
    Value<int?> updatedAt = const Value.absent(),
    Value<int?> voidedAt = const Value.absent(),
    int? dirty,
  }) => Sale(
    id: id ?? this.id,
    storeId: storeId ?? this.storeId,
    number: number ?? this.number,
    total: total ?? this.total,
    paid: paid ?? this.paid,
    change: change ?? this.change,
    method: method ?? this.method,
    status: status ?? this.status,
    voidReason: voidReason.present ? voidReason.value : this.voidReason,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    voidedAt: voidedAt.present ? voidedAt.value : this.voidedAt,
    dirty: dirty ?? this.dirty,
  );
  Sale copyWithCompanion(SalesCompanion data) {
    return Sale(
      id: data.id.present ? data.id.value : this.id,
      storeId: data.storeId.present ? data.storeId.value : this.storeId,
      number: data.number.present ? data.number.value : this.number,
      total: data.total.present ? data.total.value : this.total,
      paid: data.paid.present ? data.paid.value : this.paid,
      change: data.change.present ? data.change.value : this.change,
      method: data.method.present ? data.method.value : this.method,
      status: data.status.present ? data.status.value : this.status,
      voidReason: data.voidReason.present
          ? data.voidReason.value
          : this.voidReason,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      voidedAt: data.voidedAt.present ? data.voidedAt.value : this.voidedAt,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Sale(')
          ..write('id: $id, ')
          ..write('storeId: $storeId, ')
          ..write('number: $number, ')
          ..write('total: $total, ')
          ..write('paid: $paid, ')
          ..write('change: $change, ')
          ..write('method: $method, ')
          ..write('status: $status, ')
          ..write('voidReason: $voidReason, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('voidedAt: $voidedAt, ')
          ..write('dirty: $dirty')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    storeId,
    number,
    total,
    paid,
    change,
    method,
    status,
    voidReason,
    createdAt,
    updatedAt,
    voidedAt,
    dirty,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Sale &&
          other.id == this.id &&
          other.storeId == this.storeId &&
          other.number == this.number &&
          other.total == this.total &&
          other.paid == this.paid &&
          other.change == this.change &&
          other.method == this.method &&
          other.status == this.status &&
          other.voidReason == this.voidReason &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.voidedAt == this.voidedAt &&
          other.dirty == this.dirty);
}

class SalesCompanion extends UpdateCompanion<Sale> {
  final Value<String> id;
  final Value<String> storeId;
  final Value<String> number;
  final Value<int> total;
  final Value<int> paid;
  final Value<int> change;
  final Value<String> method;
  final Value<String> status;
  final Value<String?> voidReason;
  final Value<int> createdAt;
  final Value<int?> updatedAt;
  final Value<int?> voidedAt;
  final Value<int> dirty;
  final Value<int> rowid;
  const SalesCompanion({
    this.id = const Value.absent(),
    this.storeId = const Value.absent(),
    this.number = const Value.absent(),
    this.total = const Value.absent(),
    this.paid = const Value.absent(),
    this.change = const Value.absent(),
    this.method = const Value.absent(),
    this.status = const Value.absent(),
    this.voidReason = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.voidedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SalesCompanion.insert({
    required String id,
    required String storeId,
    required String number,
    required int total,
    required int paid,
    this.change = const Value.absent(),
    required String method,
    this.status = const Value.absent(),
    this.voidReason = const Value.absent(),
    required int createdAt,
    this.updatedAt = const Value.absent(),
    this.voidedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       storeId = Value(storeId),
       number = Value(number),
       total = Value(total),
       paid = Value(paid),
       method = Value(method),
       createdAt = Value(createdAt);
  static Insertable<Sale> custom({
    Expression<String>? id,
    Expression<String>? storeId,
    Expression<String>? number,
    Expression<int>? total,
    Expression<int>? paid,
    Expression<int>? change,
    Expression<String>? method,
    Expression<String>? status,
    Expression<String>? voidReason,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? voidedAt,
    Expression<int>? dirty,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (storeId != null) 'store_id': storeId,
      if (number != null) 'number': number,
      if (total != null) 'total': total,
      if (paid != null) 'paid': paid,
      if (change != null) 'change': change,
      if (method != null) 'method': method,
      if (status != null) 'status': status,
      if (voidReason != null) 'void_reason': voidReason,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (voidedAt != null) 'voided_at': voidedAt,
      if (dirty != null) 'dirty': dirty,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SalesCompanion copyWith({
    Value<String>? id,
    Value<String>? storeId,
    Value<String>? number,
    Value<int>? total,
    Value<int>? paid,
    Value<int>? change,
    Value<String>? method,
    Value<String>? status,
    Value<String?>? voidReason,
    Value<int>? createdAt,
    Value<int?>? updatedAt,
    Value<int?>? voidedAt,
    Value<int>? dirty,
    Value<int>? rowid,
  }) {
    return SalesCompanion(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      number: number ?? this.number,
      total: total ?? this.total,
      paid: paid ?? this.paid,
      change: change ?? this.change,
      method: method ?? this.method,
      status: status ?? this.status,
      voidReason: voidReason ?? this.voidReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      voidedAt: voidedAt ?? this.voidedAt,
      dirty: dirty ?? this.dirty,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (storeId.present) {
      map['store_id'] = Variable<String>(storeId.value);
    }
    if (number.present) {
      map['number'] = Variable<String>(number.value);
    }
    if (total.present) {
      map['total'] = Variable<int>(total.value);
    }
    if (paid.present) {
      map['paid'] = Variable<int>(paid.value);
    }
    if (change.present) {
      map['change'] = Variable<int>(change.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(method.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (voidReason.present) {
      map['void_reason'] = Variable<String>(voidReason.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (voidedAt.present) {
      map['voided_at'] = Variable<int>(voidedAt.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<int>(dirty.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SalesCompanion(')
          ..write('id: $id, ')
          ..write('storeId: $storeId, ')
          ..write('number: $number, ')
          ..write('total: $total, ')
          ..write('paid: $paid, ')
          ..write('change: $change, ')
          ..write('method: $method, ')
          ..write('status: $status, ')
          ..write('voidReason: $voidReason, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('voidedAt: $voidedAt, ')
          ..write('dirty: $dirty, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SaleItemsTable extends SaleItems
    with TableInfo<$SaleItemsTable, SaleItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SaleItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _saleIdMeta = const VerificationMeta('saleId');
  @override
  late final GeneratedColumn<String> saleId = GeneratedColumn<String>(
    'sale_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<int> price = GeneratedColumn<int>(
    'price',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _qtyMeta = const VerificationMeta('qty');
  @override
  late final GeneratedColumn<int> qty = GeneratedColumn<int>(
    'qty',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subtotalMeta = const VerificationMeta(
    'subtotal',
  );
  @override
  late final GeneratedColumn<int> subtotal = GeneratedColumn<int>(
    'subtotal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    saleId,
    productId,
    name,
    price,
    qty,
    subtotal,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sale_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<SaleItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('sale_id')) {
      context.handle(
        _saleIdMeta,
        saleId.isAcceptableOrUnknown(data['sale_id']!, _saleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_saleIdMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('price')) {
      context.handle(
        _priceMeta,
        price.isAcceptableOrUnknown(data['price']!, _priceMeta),
      );
    } else if (isInserting) {
      context.missing(_priceMeta);
    }
    if (data.containsKey('qty')) {
      context.handle(
        _qtyMeta,
        qty.isAcceptableOrUnknown(data['qty']!, _qtyMeta),
      );
    } else if (isInserting) {
      context.missing(_qtyMeta);
    }
    if (data.containsKey('subtotal')) {
      context.handle(
        _subtotalMeta,
        subtotal.isAcceptableOrUnknown(data['subtotal']!, _subtotalMeta),
      );
    } else if (isInserting) {
      context.missing(_subtotalMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SaleItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SaleItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      saleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sale_id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      price: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}price'],
      )!,
      qty: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}qty'],
      )!,
      subtotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subtotal'],
      )!,
    );
  }

  @override
  $SaleItemsTable createAlias(String alias) {
    return $SaleItemsTable(attachedDatabase, alias);
  }
}

class SaleItem extends DataClass implements Insertable<SaleItem> {
  final String id;
  final String saleId;
  final String? productId;
  final String name;
  final int price;
  final int qty;
  final int subtotal;
  const SaleItem({
    required this.id,
    required this.saleId,
    this.productId,
    required this.name,
    required this.price,
    required this.qty,
    required this.subtotal,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['sale_id'] = Variable<String>(saleId);
    if (!nullToAbsent || productId != null) {
      map['product_id'] = Variable<String>(productId);
    }
    map['name'] = Variable<String>(name);
    map['price'] = Variable<int>(price);
    map['qty'] = Variable<int>(qty);
    map['subtotal'] = Variable<int>(subtotal);
    return map;
  }

  SaleItemsCompanion toCompanion(bool nullToAbsent) {
    return SaleItemsCompanion(
      id: Value(id),
      saleId: Value(saleId),
      productId: productId == null && nullToAbsent
          ? const Value.absent()
          : Value(productId),
      name: Value(name),
      price: Value(price),
      qty: Value(qty),
      subtotal: Value(subtotal),
    );
  }

  factory SaleItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SaleItem(
      id: serializer.fromJson<String>(json['id']),
      saleId: serializer.fromJson<String>(json['saleId']),
      productId: serializer.fromJson<String?>(json['productId']),
      name: serializer.fromJson<String>(json['name']),
      price: serializer.fromJson<int>(json['price']),
      qty: serializer.fromJson<int>(json['qty']),
      subtotal: serializer.fromJson<int>(json['subtotal']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'saleId': serializer.toJson<String>(saleId),
      'productId': serializer.toJson<String?>(productId),
      'name': serializer.toJson<String>(name),
      'price': serializer.toJson<int>(price),
      'qty': serializer.toJson<int>(qty),
      'subtotal': serializer.toJson<int>(subtotal),
    };
  }

  SaleItem copyWith({
    String? id,
    String? saleId,
    Value<String?> productId = const Value.absent(),
    String? name,
    int? price,
    int? qty,
    int? subtotal,
  }) => SaleItem(
    id: id ?? this.id,
    saleId: saleId ?? this.saleId,
    productId: productId.present ? productId.value : this.productId,
    name: name ?? this.name,
    price: price ?? this.price,
    qty: qty ?? this.qty,
    subtotal: subtotal ?? this.subtotal,
  );
  SaleItem copyWithCompanion(SaleItemsCompanion data) {
    return SaleItem(
      id: data.id.present ? data.id.value : this.id,
      saleId: data.saleId.present ? data.saleId.value : this.saleId,
      productId: data.productId.present ? data.productId.value : this.productId,
      name: data.name.present ? data.name.value : this.name,
      price: data.price.present ? data.price.value : this.price,
      qty: data.qty.present ? data.qty.value : this.qty,
      subtotal: data.subtotal.present ? data.subtotal.value : this.subtotal,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SaleItem(')
          ..write('id: $id, ')
          ..write('saleId: $saleId, ')
          ..write('productId: $productId, ')
          ..write('name: $name, ')
          ..write('price: $price, ')
          ..write('qty: $qty, ')
          ..write('subtotal: $subtotal')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, saleId, productId, name, price, qty, subtotal);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SaleItem &&
          other.id == this.id &&
          other.saleId == this.saleId &&
          other.productId == this.productId &&
          other.name == this.name &&
          other.price == this.price &&
          other.qty == this.qty &&
          other.subtotal == this.subtotal);
}

class SaleItemsCompanion extends UpdateCompanion<SaleItem> {
  final Value<String> id;
  final Value<String> saleId;
  final Value<String?> productId;
  final Value<String> name;
  final Value<int> price;
  final Value<int> qty;
  final Value<int> subtotal;
  final Value<int> rowid;
  const SaleItemsCompanion({
    this.id = const Value.absent(),
    this.saleId = const Value.absent(),
    this.productId = const Value.absent(),
    this.name = const Value.absent(),
    this.price = const Value.absent(),
    this.qty = const Value.absent(),
    this.subtotal = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SaleItemsCompanion.insert({
    required String id,
    required String saleId,
    this.productId = const Value.absent(),
    required String name,
    required int price,
    required int qty,
    required int subtotal,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       saleId = Value(saleId),
       name = Value(name),
       price = Value(price),
       qty = Value(qty),
       subtotal = Value(subtotal);
  static Insertable<SaleItem> custom({
    Expression<String>? id,
    Expression<String>? saleId,
    Expression<String>? productId,
    Expression<String>? name,
    Expression<int>? price,
    Expression<int>? qty,
    Expression<int>? subtotal,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (saleId != null) 'sale_id': saleId,
      if (productId != null) 'product_id': productId,
      if (name != null) 'name': name,
      if (price != null) 'price': price,
      if (qty != null) 'qty': qty,
      if (subtotal != null) 'subtotal': subtotal,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SaleItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? saleId,
    Value<String?>? productId,
    Value<String>? name,
    Value<int>? price,
    Value<int>? qty,
    Value<int>? subtotal,
    Value<int>? rowid,
  }) {
    return SaleItemsCompanion(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      productId: productId ?? this.productId,
      name: name ?? this.name,
      price: price ?? this.price,
      qty: qty ?? this.qty,
      subtotal: subtotal ?? this.subtotal,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (saleId.present) {
      map['sale_id'] = Variable<String>(saleId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (price.present) {
      map['price'] = Variable<int>(price.value);
    }
    if (qty.present) {
      map['qty'] = Variable<int>(qty.value);
    }
    if (subtotal.present) {
      map['subtotal'] = Variable<int>(subtotal.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SaleItemsCompanion(')
          ..write('id: $id, ')
          ..write('saleId: $saleId, ')
          ..write('productId: $productId, ')
          ..write('name: $name, ')
          ..write('price: $price, ')
          ..write('qty: $qty, ')
          ..write('subtotal: $subtotal, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CartLinesTable extends CartLines
    with TableInfo<$CartLinesTable, CartLine> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CartLinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _storeIdMeta = const VerificationMeta(
    'storeId',
  );
  @override
  late final GeneratedColumn<String> storeId = GeneratedColumn<String>(
    'store_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _qtyMeta = const VerificationMeta('qty');
  @override
  late final GeneratedColumn<int> qty = GeneratedColumn<int>(
    'qty',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [storeId, productId, qty];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cart_lines';
  @override
  VerificationContext validateIntegrity(
    Insertable<CartLine> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('store_id')) {
      context.handle(
        _storeIdMeta,
        storeId.isAcceptableOrUnknown(data['store_id']!, _storeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_storeIdMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('qty')) {
      context.handle(
        _qtyMeta,
        qty.isAcceptableOrUnknown(data['qty']!, _qtyMeta),
      );
    } else if (isInserting) {
      context.missing(_qtyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {storeId, productId};
  @override
  CartLine map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CartLine(
      storeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}store_id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      qty: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}qty'],
      )!,
    );
  }

  @override
  $CartLinesTable createAlias(String alias) {
    return $CartLinesTable(attachedDatabase, alias);
  }
}

class CartLine extends DataClass implements Insertable<CartLine> {
  final String storeId;
  final String productId;
  final int qty;
  const CartLine({
    required this.storeId,
    required this.productId,
    required this.qty,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['store_id'] = Variable<String>(storeId);
    map['product_id'] = Variable<String>(productId);
    map['qty'] = Variable<int>(qty);
    return map;
  }

  CartLinesCompanion toCompanion(bool nullToAbsent) {
    return CartLinesCompanion(
      storeId: Value(storeId),
      productId: Value(productId),
      qty: Value(qty),
    );
  }

  factory CartLine.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CartLine(
      storeId: serializer.fromJson<String>(json['storeId']),
      productId: serializer.fromJson<String>(json['productId']),
      qty: serializer.fromJson<int>(json['qty']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'storeId': serializer.toJson<String>(storeId),
      'productId': serializer.toJson<String>(productId),
      'qty': serializer.toJson<int>(qty),
    };
  }

  CartLine copyWith({String? storeId, String? productId, int? qty}) => CartLine(
    storeId: storeId ?? this.storeId,
    productId: productId ?? this.productId,
    qty: qty ?? this.qty,
  );
  CartLine copyWithCompanion(CartLinesCompanion data) {
    return CartLine(
      storeId: data.storeId.present ? data.storeId.value : this.storeId,
      productId: data.productId.present ? data.productId.value : this.productId,
      qty: data.qty.present ? data.qty.value : this.qty,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CartLine(')
          ..write('storeId: $storeId, ')
          ..write('productId: $productId, ')
          ..write('qty: $qty')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(storeId, productId, qty);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CartLine &&
          other.storeId == this.storeId &&
          other.productId == this.productId &&
          other.qty == this.qty);
}

class CartLinesCompanion extends UpdateCompanion<CartLine> {
  final Value<String> storeId;
  final Value<String> productId;
  final Value<int> qty;
  final Value<int> rowid;
  const CartLinesCompanion({
    this.storeId = const Value.absent(),
    this.productId = const Value.absent(),
    this.qty = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CartLinesCompanion.insert({
    required String storeId,
    required String productId,
    required int qty,
    this.rowid = const Value.absent(),
  }) : storeId = Value(storeId),
       productId = Value(productId),
       qty = Value(qty);
  static Insertable<CartLine> custom({
    Expression<String>? storeId,
    Expression<String>? productId,
    Expression<int>? qty,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (storeId != null) 'store_id': storeId,
      if (productId != null) 'product_id': productId,
      if (qty != null) 'qty': qty,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CartLinesCompanion copyWith({
    Value<String>? storeId,
    Value<String>? productId,
    Value<int>? qty,
    Value<int>? rowid,
  }) {
    return CartLinesCompanion(
      storeId: storeId ?? this.storeId,
      productId: productId ?? this.productId,
      qty: qty ?? this.qty,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (storeId.present) {
      map['store_id'] = Variable<String>(storeId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (qty.present) {
      map['qty'] = Variable<int>(qty.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CartLinesCompanion(')
          ..write('storeId: $storeId, ')
          ..write('productId: $productId, ')
          ..write('qty: $qty, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RestocksTable extends Restocks with TableInfo<$RestocksTable, Restock> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RestocksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storeIdMeta = const VerificationMeta(
    'storeId',
  );
  @override
  late final GeneratedColumn<String> storeId = GeneratedColumn<String>(
    'store_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<int> total = GeneratedColumn<int>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('ok'),
  );
  static const VerificationMeta _voidReasonMeta = const VerificationMeta(
    'voidReason',
  );
  @override
  late final GeneratedColumn<String> voidReason = GeneratedColumn<String>(
    'void_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _voidedAtMeta = const VerificationMeta(
    'voidedAt',
  );
  @override
  late final GeneratedColumn<int> voidedAt = GeneratedColumn<int>(
    'voided_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<int> dirty = GeneratedColumn<int>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    storeId,
    total,
    status,
    voidReason,
    createdAt,
    updatedAt,
    voidedAt,
    dirty,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'restocks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Restock> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('store_id')) {
      context.handle(
        _storeIdMeta,
        storeId.isAcceptableOrUnknown(data['store_id']!, _storeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_storeIdMeta);
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    } else if (isInserting) {
      context.missing(_totalMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('void_reason')) {
      context.handle(
        _voidReasonMeta,
        voidReason.isAcceptableOrUnknown(data['void_reason']!, _voidReasonMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('voided_at')) {
      context.handle(
        _voidedAtMeta,
        voidedAt.isAcceptableOrUnknown(data['voided_at']!, _voidedAtMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Restock map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Restock(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      storeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}store_id'],
      )!,
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      voidReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}void_reason'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      ),
      voidedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}voided_at'],
      ),
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dirty'],
      )!,
    );
  }

  @override
  $RestocksTable createAlias(String alias) {
    return $RestocksTable(attachedDatabase, alias);
  }
}

class Restock extends DataClass implements Insertable<Restock> {
  final String id;
  final String storeId;
  final int total;
  final String status;
  final String? voidReason;
  final int createdAt;
  final int? updatedAt;
  final int? voidedAt;
  final int dirty;
  const Restock({
    required this.id,
    required this.storeId,
    required this.total,
    required this.status,
    this.voidReason,
    required this.createdAt,
    this.updatedAt,
    this.voidedAt,
    required this.dirty,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['store_id'] = Variable<String>(storeId);
    map['total'] = Variable<int>(total);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || voidReason != null) {
      map['void_reason'] = Variable<String>(voidReason);
    }
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<int>(updatedAt);
    }
    if (!nullToAbsent || voidedAt != null) {
      map['voided_at'] = Variable<int>(voidedAt);
    }
    map['dirty'] = Variable<int>(dirty);
    return map;
  }

  RestocksCompanion toCompanion(bool nullToAbsent) {
    return RestocksCompanion(
      id: Value(id),
      storeId: Value(storeId),
      total: Value(total),
      status: Value(status),
      voidReason: voidReason == null && nullToAbsent
          ? const Value.absent()
          : Value(voidReason),
      createdAt: Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      voidedAt: voidedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(voidedAt),
      dirty: Value(dirty),
    );
  }

  factory Restock.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Restock(
      id: serializer.fromJson<String>(json['id']),
      storeId: serializer.fromJson<String>(json['storeId']),
      total: serializer.fromJson<int>(json['total']),
      status: serializer.fromJson<String>(json['status']),
      voidReason: serializer.fromJson<String?>(json['voidReason']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int?>(json['updatedAt']),
      voidedAt: serializer.fromJson<int?>(json['voidedAt']),
      dirty: serializer.fromJson<int>(json['dirty']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'storeId': serializer.toJson<String>(storeId),
      'total': serializer.toJson<int>(total),
      'status': serializer.toJson<String>(status),
      'voidReason': serializer.toJson<String?>(voidReason),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int?>(updatedAt),
      'voidedAt': serializer.toJson<int?>(voidedAt),
      'dirty': serializer.toJson<int>(dirty),
    };
  }

  Restock copyWith({
    String? id,
    String? storeId,
    int? total,
    String? status,
    Value<String?> voidReason = const Value.absent(),
    int? createdAt,
    Value<int?> updatedAt = const Value.absent(),
    Value<int?> voidedAt = const Value.absent(),
    int? dirty,
  }) => Restock(
    id: id ?? this.id,
    storeId: storeId ?? this.storeId,
    total: total ?? this.total,
    status: status ?? this.status,
    voidReason: voidReason.present ? voidReason.value : this.voidReason,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    voidedAt: voidedAt.present ? voidedAt.value : this.voidedAt,
    dirty: dirty ?? this.dirty,
  );
  Restock copyWithCompanion(RestocksCompanion data) {
    return Restock(
      id: data.id.present ? data.id.value : this.id,
      storeId: data.storeId.present ? data.storeId.value : this.storeId,
      total: data.total.present ? data.total.value : this.total,
      status: data.status.present ? data.status.value : this.status,
      voidReason: data.voidReason.present
          ? data.voidReason.value
          : this.voidReason,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      voidedAt: data.voidedAt.present ? data.voidedAt.value : this.voidedAt,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Restock(')
          ..write('id: $id, ')
          ..write('storeId: $storeId, ')
          ..write('total: $total, ')
          ..write('status: $status, ')
          ..write('voidReason: $voidReason, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('voidedAt: $voidedAt, ')
          ..write('dirty: $dirty')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    storeId,
    total,
    status,
    voidReason,
    createdAt,
    updatedAt,
    voidedAt,
    dirty,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Restock &&
          other.id == this.id &&
          other.storeId == this.storeId &&
          other.total == this.total &&
          other.status == this.status &&
          other.voidReason == this.voidReason &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.voidedAt == this.voidedAt &&
          other.dirty == this.dirty);
}

class RestocksCompanion extends UpdateCompanion<Restock> {
  final Value<String> id;
  final Value<String> storeId;
  final Value<int> total;
  final Value<String> status;
  final Value<String?> voidReason;
  final Value<int> createdAt;
  final Value<int?> updatedAt;
  final Value<int?> voidedAt;
  final Value<int> dirty;
  final Value<int> rowid;
  const RestocksCompanion({
    this.id = const Value.absent(),
    this.storeId = const Value.absent(),
    this.total = const Value.absent(),
    this.status = const Value.absent(),
    this.voidReason = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.voidedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RestocksCompanion.insert({
    required String id,
    required String storeId,
    required int total,
    this.status = const Value.absent(),
    this.voidReason = const Value.absent(),
    required int createdAt,
    this.updatedAt = const Value.absent(),
    this.voidedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       storeId = Value(storeId),
       total = Value(total),
       createdAt = Value(createdAt);
  static Insertable<Restock> custom({
    Expression<String>? id,
    Expression<String>? storeId,
    Expression<int>? total,
    Expression<String>? status,
    Expression<String>? voidReason,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? voidedAt,
    Expression<int>? dirty,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (storeId != null) 'store_id': storeId,
      if (total != null) 'total': total,
      if (status != null) 'status': status,
      if (voidReason != null) 'void_reason': voidReason,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (voidedAt != null) 'voided_at': voidedAt,
      if (dirty != null) 'dirty': dirty,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RestocksCompanion copyWith({
    Value<String>? id,
    Value<String>? storeId,
    Value<int>? total,
    Value<String>? status,
    Value<String?>? voidReason,
    Value<int>? createdAt,
    Value<int?>? updatedAt,
    Value<int?>? voidedAt,
    Value<int>? dirty,
    Value<int>? rowid,
  }) {
    return RestocksCompanion(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      total: total ?? this.total,
      status: status ?? this.status,
      voidReason: voidReason ?? this.voidReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      voidedAt: voidedAt ?? this.voidedAt,
      dirty: dirty ?? this.dirty,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (storeId.present) {
      map['store_id'] = Variable<String>(storeId.value);
    }
    if (total.present) {
      map['total'] = Variable<int>(total.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (voidReason.present) {
      map['void_reason'] = Variable<String>(voidReason.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (voidedAt.present) {
      map['voided_at'] = Variable<int>(voidedAt.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<int>(dirty.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RestocksCompanion(')
          ..write('id: $id, ')
          ..write('storeId: $storeId, ')
          ..write('total: $total, ')
          ..write('status: $status, ')
          ..write('voidReason: $voidReason, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('voidedAt: $voidedAt, ')
          ..write('dirty: $dirty, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RestockItemsTable extends RestockItems
    with TableInfo<$RestockItemsTable, RestockItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RestockItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _restockIdMeta = const VerificationMeta(
    'restockId',
  );
  @override
  late final GeneratedColumn<String> restockId = GeneratedColumn<String>(
    'restock_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _qtyMeta = const VerificationMeta('qty');
  @override
  late final GeneratedColumn<int> qty = GeneratedColumn<int>(
    'qty',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _costPriceMeta = const VerificationMeta(
    'costPrice',
  );
  @override
  late final GeneratedColumn<int> costPrice = GeneratedColumn<int>(
    'cost_price',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sellPriceMeta = const VerificationMeta(
    'sellPrice',
  );
  @override
  late final GeneratedColumn<int> sellPrice = GeneratedColumn<int>(
    'sell_price',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subtotalMeta = const VerificationMeta(
    'subtotal',
  );
  @override
  late final GeneratedColumn<int> subtotal = GeneratedColumn<int>(
    'subtotal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    restockId,
    productId,
    name,
    qty,
    costPrice,
    sellPrice,
    subtotal,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'restock_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<RestockItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('restock_id')) {
      context.handle(
        _restockIdMeta,
        restockId.isAcceptableOrUnknown(data['restock_id']!, _restockIdMeta),
      );
    } else if (isInserting) {
      context.missing(_restockIdMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('qty')) {
      context.handle(
        _qtyMeta,
        qty.isAcceptableOrUnknown(data['qty']!, _qtyMeta),
      );
    } else if (isInserting) {
      context.missing(_qtyMeta);
    }
    if (data.containsKey('cost_price')) {
      context.handle(
        _costPriceMeta,
        costPrice.isAcceptableOrUnknown(data['cost_price']!, _costPriceMeta),
      );
    } else if (isInserting) {
      context.missing(_costPriceMeta);
    }
    if (data.containsKey('sell_price')) {
      context.handle(
        _sellPriceMeta,
        sellPrice.isAcceptableOrUnknown(data['sell_price']!, _sellPriceMeta),
      );
    }
    if (data.containsKey('subtotal')) {
      context.handle(
        _subtotalMeta,
        subtotal.isAcceptableOrUnknown(data['subtotal']!, _subtotalMeta),
      );
    } else if (isInserting) {
      context.missing(_subtotalMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RestockItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RestockItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      restockId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}restock_id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      qty: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}qty'],
      )!,
      costPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cost_price'],
      )!,
      sellPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sell_price'],
      ),
      subtotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subtotal'],
      )!,
    );
  }

  @override
  $RestockItemsTable createAlias(String alias) {
    return $RestockItemsTable(attachedDatabase, alias);
  }
}

class RestockItem extends DataClass implements Insertable<RestockItem> {
  final String id;
  final String restockId;
  final String? productId;
  final String name;
  final int qty;
  final int costPrice;
  final int? sellPrice;
  final int subtotal;
  const RestockItem({
    required this.id,
    required this.restockId,
    this.productId,
    required this.name,
    required this.qty,
    required this.costPrice,
    this.sellPrice,
    required this.subtotal,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['restock_id'] = Variable<String>(restockId);
    if (!nullToAbsent || productId != null) {
      map['product_id'] = Variable<String>(productId);
    }
    map['name'] = Variable<String>(name);
    map['qty'] = Variable<int>(qty);
    map['cost_price'] = Variable<int>(costPrice);
    if (!nullToAbsent || sellPrice != null) {
      map['sell_price'] = Variable<int>(sellPrice);
    }
    map['subtotal'] = Variable<int>(subtotal);
    return map;
  }

  RestockItemsCompanion toCompanion(bool nullToAbsent) {
    return RestockItemsCompanion(
      id: Value(id),
      restockId: Value(restockId),
      productId: productId == null && nullToAbsent
          ? const Value.absent()
          : Value(productId),
      name: Value(name),
      qty: Value(qty),
      costPrice: Value(costPrice),
      sellPrice: sellPrice == null && nullToAbsent
          ? const Value.absent()
          : Value(sellPrice),
      subtotal: Value(subtotal),
    );
  }

  factory RestockItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RestockItem(
      id: serializer.fromJson<String>(json['id']),
      restockId: serializer.fromJson<String>(json['restockId']),
      productId: serializer.fromJson<String?>(json['productId']),
      name: serializer.fromJson<String>(json['name']),
      qty: serializer.fromJson<int>(json['qty']),
      costPrice: serializer.fromJson<int>(json['costPrice']),
      sellPrice: serializer.fromJson<int?>(json['sellPrice']),
      subtotal: serializer.fromJson<int>(json['subtotal']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'restockId': serializer.toJson<String>(restockId),
      'productId': serializer.toJson<String?>(productId),
      'name': serializer.toJson<String>(name),
      'qty': serializer.toJson<int>(qty),
      'costPrice': serializer.toJson<int>(costPrice),
      'sellPrice': serializer.toJson<int?>(sellPrice),
      'subtotal': serializer.toJson<int>(subtotal),
    };
  }

  RestockItem copyWith({
    String? id,
    String? restockId,
    Value<String?> productId = const Value.absent(),
    String? name,
    int? qty,
    int? costPrice,
    Value<int?> sellPrice = const Value.absent(),
    int? subtotal,
  }) => RestockItem(
    id: id ?? this.id,
    restockId: restockId ?? this.restockId,
    productId: productId.present ? productId.value : this.productId,
    name: name ?? this.name,
    qty: qty ?? this.qty,
    costPrice: costPrice ?? this.costPrice,
    sellPrice: sellPrice.present ? sellPrice.value : this.sellPrice,
    subtotal: subtotal ?? this.subtotal,
  );
  RestockItem copyWithCompanion(RestockItemsCompanion data) {
    return RestockItem(
      id: data.id.present ? data.id.value : this.id,
      restockId: data.restockId.present ? data.restockId.value : this.restockId,
      productId: data.productId.present ? data.productId.value : this.productId,
      name: data.name.present ? data.name.value : this.name,
      qty: data.qty.present ? data.qty.value : this.qty,
      costPrice: data.costPrice.present ? data.costPrice.value : this.costPrice,
      sellPrice: data.sellPrice.present ? data.sellPrice.value : this.sellPrice,
      subtotal: data.subtotal.present ? data.subtotal.value : this.subtotal,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RestockItem(')
          ..write('id: $id, ')
          ..write('restockId: $restockId, ')
          ..write('productId: $productId, ')
          ..write('name: $name, ')
          ..write('qty: $qty, ')
          ..write('costPrice: $costPrice, ')
          ..write('sellPrice: $sellPrice, ')
          ..write('subtotal: $subtotal')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    restockId,
    productId,
    name,
    qty,
    costPrice,
    sellPrice,
    subtotal,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RestockItem &&
          other.id == this.id &&
          other.restockId == this.restockId &&
          other.productId == this.productId &&
          other.name == this.name &&
          other.qty == this.qty &&
          other.costPrice == this.costPrice &&
          other.sellPrice == this.sellPrice &&
          other.subtotal == this.subtotal);
}

class RestockItemsCompanion extends UpdateCompanion<RestockItem> {
  final Value<String> id;
  final Value<String> restockId;
  final Value<String?> productId;
  final Value<String> name;
  final Value<int> qty;
  final Value<int> costPrice;
  final Value<int?> sellPrice;
  final Value<int> subtotal;
  final Value<int> rowid;
  const RestockItemsCompanion({
    this.id = const Value.absent(),
    this.restockId = const Value.absent(),
    this.productId = const Value.absent(),
    this.name = const Value.absent(),
    this.qty = const Value.absent(),
    this.costPrice = const Value.absent(),
    this.sellPrice = const Value.absent(),
    this.subtotal = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RestockItemsCompanion.insert({
    required String id,
    required String restockId,
    this.productId = const Value.absent(),
    required String name,
    required int qty,
    required int costPrice,
    this.sellPrice = const Value.absent(),
    required int subtotal,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       restockId = Value(restockId),
       name = Value(name),
       qty = Value(qty),
       costPrice = Value(costPrice),
       subtotal = Value(subtotal);
  static Insertable<RestockItem> custom({
    Expression<String>? id,
    Expression<String>? restockId,
    Expression<String>? productId,
    Expression<String>? name,
    Expression<int>? qty,
    Expression<int>? costPrice,
    Expression<int>? sellPrice,
    Expression<int>? subtotal,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (restockId != null) 'restock_id': restockId,
      if (productId != null) 'product_id': productId,
      if (name != null) 'name': name,
      if (qty != null) 'qty': qty,
      if (costPrice != null) 'cost_price': costPrice,
      if (sellPrice != null) 'sell_price': sellPrice,
      if (subtotal != null) 'subtotal': subtotal,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RestockItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? restockId,
    Value<String?>? productId,
    Value<String>? name,
    Value<int>? qty,
    Value<int>? costPrice,
    Value<int?>? sellPrice,
    Value<int>? subtotal,
    Value<int>? rowid,
  }) {
    return RestockItemsCompanion(
      id: id ?? this.id,
      restockId: restockId ?? this.restockId,
      productId: productId ?? this.productId,
      name: name ?? this.name,
      qty: qty ?? this.qty,
      costPrice: costPrice ?? this.costPrice,
      sellPrice: sellPrice ?? this.sellPrice,
      subtotal: subtotal ?? this.subtotal,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (restockId.present) {
      map['restock_id'] = Variable<String>(restockId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (qty.present) {
      map['qty'] = Variable<int>(qty.value);
    }
    if (costPrice.present) {
      map['cost_price'] = Variable<int>(costPrice.value);
    }
    if (sellPrice.present) {
      map['sell_price'] = Variable<int>(sellPrice.value);
    }
    if (subtotal.present) {
      map['subtotal'] = Variable<int>(subtotal.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RestockItemsCompanion(')
          ..write('id: $id, ')
          ..write('restockId: $restockId, ')
          ..write('productId: $productId, ')
          ..write('name: $name, ')
          ..write('qty: $qty, ')
          ..write('costPrice: $costPrice, ')
          ..write('sellPrice: $sellPrice, ')
          ..write('subtotal: $subtotal, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDb extends GeneratedDatabase {
  _$AppDb(QueryExecutor e) : super(e);
  $AppDbManager get managers => $AppDbManager(this);
  late final $LocalStoresTable localStores = $LocalStoresTable(this);
  late final $LocalUsersTable localUsers = $LocalUsersTable(this);
  late final $ProductsTable products = $ProductsTable(this);
  late final $SalesTable sales = $SalesTable(this);
  late final $SaleItemsTable saleItems = $SaleItemsTable(this);
  late final $CartLinesTable cartLines = $CartLinesTable(this);
  late final $RestocksTable restocks = $RestocksTable(this);
  late final $RestockItemsTable restockItems = $RestockItemsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localStores,
    localUsers,
    products,
    sales,
    saleItems,
    cartLines,
    restocks,
    restockItems,
  ];
}

typedef $$LocalStoresTableCreateCompanionBuilder =
    LocalStoresCompanion Function({
      required String serverId,
      required String name,
      Value<int> rowid,
    });
typedef $$LocalStoresTableUpdateCompanionBuilder =
    LocalStoresCompanion Function({
      Value<String> serverId,
      Value<String> name,
      Value<int> rowid,
    });

class $$LocalStoresTableFilterComposer
    extends Composer<_$AppDb, $LocalStoresTable> {
  $$LocalStoresTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalStoresTableOrderingComposer
    extends Composer<_$AppDb, $LocalStoresTable> {
  $$LocalStoresTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalStoresTableAnnotationComposer
    extends Composer<_$AppDb, $LocalStoresTable> {
  $$LocalStoresTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);
}

class $$LocalStoresTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $LocalStoresTable,
          LocalStore,
          $$LocalStoresTableFilterComposer,
          $$LocalStoresTableOrderingComposer,
          $$LocalStoresTableAnnotationComposer,
          $$LocalStoresTableCreateCompanionBuilder,
          $$LocalStoresTableUpdateCompanionBuilder,
          (LocalStore, BaseReferences<_$AppDb, $LocalStoresTable, LocalStore>),
          LocalStore,
          PrefetchHooks Function()
        > {
  $$LocalStoresTableTableManager(_$AppDb db, $LocalStoresTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalStoresTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalStoresTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalStoresTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> serverId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalStoresCompanion(
                serverId: serverId,
                name: name,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String serverId,
                required String name,
                Value<int> rowid = const Value.absent(),
              }) => LocalStoresCompanion.insert(
                serverId: serverId,
                name: name,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalStoresTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $LocalStoresTable,
      LocalStore,
      $$LocalStoresTableFilterComposer,
      $$LocalStoresTableOrderingComposer,
      $$LocalStoresTableAnnotationComposer,
      $$LocalStoresTableCreateCompanionBuilder,
      $$LocalStoresTableUpdateCompanionBuilder,
      (LocalStore, BaseReferences<_$AppDb, $LocalStoresTable, LocalStore>),
      LocalStore,
      PrefetchHooks Function()
    >;
typedef $$LocalUsersTableCreateCompanionBuilder =
    LocalUsersCompanion Function({
      required String serverId,
      required String storeId,
      required String name,
      required String email,
      Value<int> rowid,
    });
typedef $$LocalUsersTableUpdateCompanionBuilder =
    LocalUsersCompanion Function({
      Value<String> serverId,
      Value<String> storeId,
      Value<String> name,
      Value<String> email,
      Value<int> rowid,
    });

class $$LocalUsersTableFilterComposer
    extends Composer<_$AppDb, $LocalUsersTable> {
  $$LocalUsersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storeId => $composableBuilder(
    column: $table.storeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalUsersTableOrderingComposer
    extends Composer<_$AppDb, $LocalUsersTable> {
  $$LocalUsersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storeId => $composableBuilder(
    column: $table.storeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalUsersTableAnnotationComposer
    extends Composer<_$AppDb, $LocalUsersTable> {
  $$LocalUsersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get storeId =>
      $composableBuilder(column: $table.storeId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);
}

class $$LocalUsersTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $LocalUsersTable,
          LocalUser,
          $$LocalUsersTableFilterComposer,
          $$LocalUsersTableOrderingComposer,
          $$LocalUsersTableAnnotationComposer,
          $$LocalUsersTableCreateCompanionBuilder,
          $$LocalUsersTableUpdateCompanionBuilder,
          (LocalUser, BaseReferences<_$AppDb, $LocalUsersTable, LocalUser>),
          LocalUser,
          PrefetchHooks Function()
        > {
  $$LocalUsersTableTableManager(_$AppDb db, $LocalUsersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalUsersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalUsersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalUsersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> serverId = const Value.absent(),
                Value<String> storeId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalUsersCompanion(
                serverId: serverId,
                storeId: storeId,
                name: name,
                email: email,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String serverId,
                required String storeId,
                required String name,
                required String email,
                Value<int> rowid = const Value.absent(),
              }) => LocalUsersCompanion.insert(
                serverId: serverId,
                storeId: storeId,
                name: name,
                email: email,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalUsersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $LocalUsersTable,
      LocalUser,
      $$LocalUsersTableFilterComposer,
      $$LocalUsersTableOrderingComposer,
      $$LocalUsersTableAnnotationComposer,
      $$LocalUsersTableCreateCompanionBuilder,
      $$LocalUsersTableUpdateCompanionBuilder,
      (LocalUser, BaseReferences<_$AppDb, $LocalUsersTable, LocalUser>),
      LocalUser,
      PrefetchHooks Function()
    >;
typedef $$ProductsTableCreateCompanionBuilder =
    ProductsCompanion Function({
      required String id,
      required String storeId,
      required String name,
      Value<String?> barcode,
      required int costPrice,
      required int sellPrice,
      Value<int> stock,
      Value<String> category,
      Value<String> photoPath,
      Value<bool> isArchived,
      required int createdAt,
      required int updatedAt,
      Value<int?> deletedAt,
      Value<int> dirty,
      Value<int> rowid,
    });
typedef $$ProductsTableUpdateCompanionBuilder =
    ProductsCompanion Function({
      Value<String> id,
      Value<String> storeId,
      Value<String> name,
      Value<String?> barcode,
      Value<int> costPrice,
      Value<int> sellPrice,
      Value<int> stock,
      Value<String> category,
      Value<String> photoPath,
      Value<bool> isArchived,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<int> dirty,
      Value<int> rowid,
    });

class $$ProductsTableFilterComposer extends Composer<_$AppDb, $ProductsTable> {
  $$ProductsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storeId => $composableBuilder(
    column: $table.storeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get costPrice => $composableBuilder(
    column: $table.costPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sellPrice => $composableBuilder(
    column: $table.sellPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stock => $composableBuilder(
    column: $table.stock,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProductsTableOrderingComposer
    extends Composer<_$AppDb, $ProductsTable> {
  $$ProductsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storeId => $composableBuilder(
    column: $table.storeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get costPrice => $composableBuilder(
    column: $table.costPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sellPrice => $composableBuilder(
    column: $table.sellPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stock => $composableBuilder(
    column: $table.stock,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProductsTableAnnotationComposer
    extends Composer<_$AppDb, $ProductsTable> {
  $$ProductsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get storeId =>
      $composableBuilder(column: $table.storeId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get barcode =>
      $composableBuilder(column: $table.barcode, builder: (column) => column);

  GeneratedColumn<int> get costPrice =>
      $composableBuilder(column: $table.costPrice, builder: (column) => column);

  GeneratedColumn<int> get sellPrice =>
      $composableBuilder(column: $table.sellPrice, builder: (column) => column);

  GeneratedColumn<int> get stock =>
      $composableBuilder(column: $table.stock, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get photoPath =>
      $composableBuilder(column: $table.photoPath, builder: (column) => column);

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);
}

class $$ProductsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ProductsTable,
          Product,
          $$ProductsTableFilterComposer,
          $$ProductsTableOrderingComposer,
          $$ProductsTableAnnotationComposer,
          $$ProductsTableCreateCompanionBuilder,
          $$ProductsTableUpdateCompanionBuilder,
          (Product, BaseReferences<_$AppDb, $ProductsTable, Product>),
          Product,
          PrefetchHooks Function()
        > {
  $$ProductsTableTableManager(_$AppDb db, $ProductsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProductsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProductsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProductsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> storeId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> barcode = const Value.absent(),
                Value<int> costPrice = const Value.absent(),
                Value<int> sellPrice = const Value.absent(),
                Value<int> stock = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> photoPath = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> dirty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProductsCompanion(
                id: id,
                storeId: storeId,
                name: name,
                barcode: barcode,
                costPrice: costPrice,
                sellPrice: sellPrice,
                stock: stock,
                category: category,
                photoPath: photoPath,
                isArchived: isArchived,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                dirty: dirty,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String storeId,
                required String name,
                Value<String?> barcode = const Value.absent(),
                required int costPrice,
                required int sellPrice,
                Value<int> stock = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> photoPath = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> dirty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProductsCompanion.insert(
                id: id,
                storeId: storeId,
                name: name,
                barcode: barcode,
                costPrice: costPrice,
                sellPrice: sellPrice,
                stock: stock,
                category: category,
                photoPath: photoPath,
                isArchived: isArchived,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                dirty: dirty,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProductsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ProductsTable,
      Product,
      $$ProductsTableFilterComposer,
      $$ProductsTableOrderingComposer,
      $$ProductsTableAnnotationComposer,
      $$ProductsTableCreateCompanionBuilder,
      $$ProductsTableUpdateCompanionBuilder,
      (Product, BaseReferences<_$AppDb, $ProductsTable, Product>),
      Product,
      PrefetchHooks Function()
    >;
typedef $$SalesTableCreateCompanionBuilder =
    SalesCompanion Function({
      required String id,
      required String storeId,
      required String number,
      required int total,
      required int paid,
      Value<int> change,
      required String method,
      Value<String> status,
      Value<String?> voidReason,
      required int createdAt,
      Value<int?> updatedAt,
      Value<int?> voidedAt,
      Value<int> dirty,
      Value<int> rowid,
    });
typedef $$SalesTableUpdateCompanionBuilder =
    SalesCompanion Function({
      Value<String> id,
      Value<String> storeId,
      Value<String> number,
      Value<int> total,
      Value<int> paid,
      Value<int> change,
      Value<String> method,
      Value<String> status,
      Value<String?> voidReason,
      Value<int> createdAt,
      Value<int?> updatedAt,
      Value<int?> voidedAt,
      Value<int> dirty,
      Value<int> rowid,
    });

class $$SalesTableFilterComposer extends Composer<_$AppDb, $SalesTable> {
  $$SalesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storeId => $composableBuilder(
    column: $table.storeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get paid => $composableBuilder(
    column: $table.paid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get change => $composableBuilder(
    column: $table.change,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voidReason => $composableBuilder(
    column: $table.voidReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get voidedAt => $composableBuilder(
    column: $table.voidedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SalesTableOrderingComposer extends Composer<_$AppDb, $SalesTable> {
  $$SalesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storeId => $composableBuilder(
    column: $table.storeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get paid => $composableBuilder(
    column: $table.paid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get change => $composableBuilder(
    column: $table.change,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voidReason => $composableBuilder(
    column: $table.voidReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get voidedAt => $composableBuilder(
    column: $table.voidedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SalesTableAnnotationComposer extends Composer<_$AppDb, $SalesTable> {
  $$SalesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get storeId =>
      $composableBuilder(column: $table.storeId, builder: (column) => column);

  GeneratedColumn<String> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<int> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<int> get paid =>
      $composableBuilder(column: $table.paid, builder: (column) => column);

  GeneratedColumn<int> get change =>
      $composableBuilder(column: $table.change, builder: (column) => column);

  GeneratedColumn<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get voidReason => $composableBuilder(
    column: $table.voidReason,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get voidedAt =>
      $composableBuilder(column: $table.voidedAt, builder: (column) => column);

  GeneratedColumn<int> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);
}

class $$SalesTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $SalesTable,
          Sale,
          $$SalesTableFilterComposer,
          $$SalesTableOrderingComposer,
          $$SalesTableAnnotationComposer,
          $$SalesTableCreateCompanionBuilder,
          $$SalesTableUpdateCompanionBuilder,
          (Sale, BaseReferences<_$AppDb, $SalesTable, Sale>),
          Sale,
          PrefetchHooks Function()
        > {
  $$SalesTableTableManager(_$AppDb db, $SalesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SalesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SalesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SalesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> storeId = const Value.absent(),
                Value<String> number = const Value.absent(),
                Value<int> total = const Value.absent(),
                Value<int> paid = const Value.absent(),
                Value<int> change = const Value.absent(),
                Value<String> method = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> voidReason = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int?> updatedAt = const Value.absent(),
                Value<int?> voidedAt = const Value.absent(),
                Value<int> dirty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SalesCompanion(
                id: id,
                storeId: storeId,
                number: number,
                total: total,
                paid: paid,
                change: change,
                method: method,
                status: status,
                voidReason: voidReason,
                createdAt: createdAt,
                updatedAt: updatedAt,
                voidedAt: voidedAt,
                dirty: dirty,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String storeId,
                required String number,
                required int total,
                required int paid,
                Value<int> change = const Value.absent(),
                required String method,
                Value<String> status = const Value.absent(),
                Value<String?> voidReason = const Value.absent(),
                required int createdAt,
                Value<int?> updatedAt = const Value.absent(),
                Value<int?> voidedAt = const Value.absent(),
                Value<int> dirty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SalesCompanion.insert(
                id: id,
                storeId: storeId,
                number: number,
                total: total,
                paid: paid,
                change: change,
                method: method,
                status: status,
                voidReason: voidReason,
                createdAt: createdAt,
                updatedAt: updatedAt,
                voidedAt: voidedAt,
                dirty: dirty,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SalesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $SalesTable,
      Sale,
      $$SalesTableFilterComposer,
      $$SalesTableOrderingComposer,
      $$SalesTableAnnotationComposer,
      $$SalesTableCreateCompanionBuilder,
      $$SalesTableUpdateCompanionBuilder,
      (Sale, BaseReferences<_$AppDb, $SalesTable, Sale>),
      Sale,
      PrefetchHooks Function()
    >;
typedef $$SaleItemsTableCreateCompanionBuilder =
    SaleItemsCompanion Function({
      required String id,
      required String saleId,
      Value<String?> productId,
      required String name,
      required int price,
      required int qty,
      required int subtotal,
      Value<int> rowid,
    });
typedef $$SaleItemsTableUpdateCompanionBuilder =
    SaleItemsCompanion Function({
      Value<String> id,
      Value<String> saleId,
      Value<String?> productId,
      Value<String> name,
      Value<int> price,
      Value<int> qty,
      Value<int> subtotal,
      Value<int> rowid,
    });

class $$SaleItemsTableFilterComposer
    extends Composer<_$AppDb, $SaleItemsTable> {
  $$SaleItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get saleId => $composableBuilder(
    column: $table.saleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subtotal => $composableBuilder(
    column: $table.subtotal,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SaleItemsTableOrderingComposer
    extends Composer<_$AppDb, $SaleItemsTable> {
  $$SaleItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get saleId => $composableBuilder(
    column: $table.saleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subtotal => $composableBuilder(
    column: $table.subtotal,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SaleItemsTableAnnotationComposer
    extends Composer<_$AppDb, $SaleItemsTable> {
  $$SaleItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get saleId =>
      $composableBuilder(column: $table.saleId, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<int> get qty =>
      $composableBuilder(column: $table.qty, builder: (column) => column);

  GeneratedColumn<int> get subtotal =>
      $composableBuilder(column: $table.subtotal, builder: (column) => column);
}

class $$SaleItemsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $SaleItemsTable,
          SaleItem,
          $$SaleItemsTableFilterComposer,
          $$SaleItemsTableOrderingComposer,
          $$SaleItemsTableAnnotationComposer,
          $$SaleItemsTableCreateCompanionBuilder,
          $$SaleItemsTableUpdateCompanionBuilder,
          (SaleItem, BaseReferences<_$AppDb, $SaleItemsTable, SaleItem>),
          SaleItem,
          PrefetchHooks Function()
        > {
  $$SaleItemsTableTableManager(_$AppDb db, $SaleItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SaleItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SaleItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SaleItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> saleId = const Value.absent(),
                Value<String?> productId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> price = const Value.absent(),
                Value<int> qty = const Value.absent(),
                Value<int> subtotal = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SaleItemsCompanion(
                id: id,
                saleId: saleId,
                productId: productId,
                name: name,
                price: price,
                qty: qty,
                subtotal: subtotal,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String saleId,
                Value<String?> productId = const Value.absent(),
                required String name,
                required int price,
                required int qty,
                required int subtotal,
                Value<int> rowid = const Value.absent(),
              }) => SaleItemsCompanion.insert(
                id: id,
                saleId: saleId,
                productId: productId,
                name: name,
                price: price,
                qty: qty,
                subtotal: subtotal,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SaleItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $SaleItemsTable,
      SaleItem,
      $$SaleItemsTableFilterComposer,
      $$SaleItemsTableOrderingComposer,
      $$SaleItemsTableAnnotationComposer,
      $$SaleItemsTableCreateCompanionBuilder,
      $$SaleItemsTableUpdateCompanionBuilder,
      (SaleItem, BaseReferences<_$AppDb, $SaleItemsTable, SaleItem>),
      SaleItem,
      PrefetchHooks Function()
    >;
typedef $$CartLinesTableCreateCompanionBuilder =
    CartLinesCompanion Function({
      required String storeId,
      required String productId,
      required int qty,
      Value<int> rowid,
    });
typedef $$CartLinesTableUpdateCompanionBuilder =
    CartLinesCompanion Function({
      Value<String> storeId,
      Value<String> productId,
      Value<int> qty,
      Value<int> rowid,
    });

class $$CartLinesTableFilterComposer
    extends Composer<_$AppDb, $CartLinesTable> {
  $$CartLinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get storeId => $composableBuilder(
    column: $table.storeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CartLinesTableOrderingComposer
    extends Composer<_$AppDb, $CartLinesTable> {
  $$CartLinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get storeId => $composableBuilder(
    column: $table.storeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CartLinesTableAnnotationComposer
    extends Composer<_$AppDb, $CartLinesTable> {
  $$CartLinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get storeId =>
      $composableBuilder(column: $table.storeId, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<int> get qty =>
      $composableBuilder(column: $table.qty, builder: (column) => column);
}

class $$CartLinesTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $CartLinesTable,
          CartLine,
          $$CartLinesTableFilterComposer,
          $$CartLinesTableOrderingComposer,
          $$CartLinesTableAnnotationComposer,
          $$CartLinesTableCreateCompanionBuilder,
          $$CartLinesTableUpdateCompanionBuilder,
          (CartLine, BaseReferences<_$AppDb, $CartLinesTable, CartLine>),
          CartLine,
          PrefetchHooks Function()
        > {
  $$CartLinesTableTableManager(_$AppDb db, $CartLinesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CartLinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CartLinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CartLinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> storeId = const Value.absent(),
                Value<String> productId = const Value.absent(),
                Value<int> qty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CartLinesCompanion(
                storeId: storeId,
                productId: productId,
                qty: qty,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String storeId,
                required String productId,
                required int qty,
                Value<int> rowid = const Value.absent(),
              }) => CartLinesCompanion.insert(
                storeId: storeId,
                productId: productId,
                qty: qty,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CartLinesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $CartLinesTable,
      CartLine,
      $$CartLinesTableFilterComposer,
      $$CartLinesTableOrderingComposer,
      $$CartLinesTableAnnotationComposer,
      $$CartLinesTableCreateCompanionBuilder,
      $$CartLinesTableUpdateCompanionBuilder,
      (CartLine, BaseReferences<_$AppDb, $CartLinesTable, CartLine>),
      CartLine,
      PrefetchHooks Function()
    >;
typedef $$RestocksTableCreateCompanionBuilder =
    RestocksCompanion Function({
      required String id,
      required String storeId,
      required int total,
      Value<String> status,
      Value<String?> voidReason,
      required int createdAt,
      Value<int?> updatedAt,
      Value<int?> voidedAt,
      Value<int> dirty,
      Value<int> rowid,
    });
typedef $$RestocksTableUpdateCompanionBuilder =
    RestocksCompanion Function({
      Value<String> id,
      Value<String> storeId,
      Value<int> total,
      Value<String> status,
      Value<String?> voidReason,
      Value<int> createdAt,
      Value<int?> updatedAt,
      Value<int?> voidedAt,
      Value<int> dirty,
      Value<int> rowid,
    });

class $$RestocksTableFilterComposer extends Composer<_$AppDb, $RestocksTable> {
  $$RestocksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storeId => $composableBuilder(
    column: $table.storeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voidReason => $composableBuilder(
    column: $table.voidReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get voidedAt => $composableBuilder(
    column: $table.voidedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RestocksTableOrderingComposer
    extends Composer<_$AppDb, $RestocksTable> {
  $$RestocksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storeId => $composableBuilder(
    column: $table.storeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voidReason => $composableBuilder(
    column: $table.voidReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get voidedAt => $composableBuilder(
    column: $table.voidedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RestocksTableAnnotationComposer
    extends Composer<_$AppDb, $RestocksTable> {
  $$RestocksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get storeId =>
      $composableBuilder(column: $table.storeId, builder: (column) => column);

  GeneratedColumn<int> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get voidReason => $composableBuilder(
    column: $table.voidReason,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get voidedAt =>
      $composableBuilder(column: $table.voidedAt, builder: (column) => column);

  GeneratedColumn<int> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);
}

class $$RestocksTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $RestocksTable,
          Restock,
          $$RestocksTableFilterComposer,
          $$RestocksTableOrderingComposer,
          $$RestocksTableAnnotationComposer,
          $$RestocksTableCreateCompanionBuilder,
          $$RestocksTableUpdateCompanionBuilder,
          (Restock, BaseReferences<_$AppDb, $RestocksTable, Restock>),
          Restock,
          PrefetchHooks Function()
        > {
  $$RestocksTableTableManager(_$AppDb db, $RestocksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RestocksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RestocksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RestocksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> storeId = const Value.absent(),
                Value<int> total = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> voidReason = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int?> updatedAt = const Value.absent(),
                Value<int?> voidedAt = const Value.absent(),
                Value<int> dirty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RestocksCompanion(
                id: id,
                storeId: storeId,
                total: total,
                status: status,
                voidReason: voidReason,
                createdAt: createdAt,
                updatedAt: updatedAt,
                voidedAt: voidedAt,
                dirty: dirty,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String storeId,
                required int total,
                Value<String> status = const Value.absent(),
                Value<String?> voidReason = const Value.absent(),
                required int createdAt,
                Value<int?> updatedAt = const Value.absent(),
                Value<int?> voidedAt = const Value.absent(),
                Value<int> dirty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RestocksCompanion.insert(
                id: id,
                storeId: storeId,
                total: total,
                status: status,
                voidReason: voidReason,
                createdAt: createdAt,
                updatedAt: updatedAt,
                voidedAt: voidedAt,
                dirty: dirty,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RestocksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $RestocksTable,
      Restock,
      $$RestocksTableFilterComposer,
      $$RestocksTableOrderingComposer,
      $$RestocksTableAnnotationComposer,
      $$RestocksTableCreateCompanionBuilder,
      $$RestocksTableUpdateCompanionBuilder,
      (Restock, BaseReferences<_$AppDb, $RestocksTable, Restock>),
      Restock,
      PrefetchHooks Function()
    >;
typedef $$RestockItemsTableCreateCompanionBuilder =
    RestockItemsCompanion Function({
      required String id,
      required String restockId,
      Value<String?> productId,
      required String name,
      required int qty,
      required int costPrice,
      Value<int?> sellPrice,
      required int subtotal,
      Value<int> rowid,
    });
typedef $$RestockItemsTableUpdateCompanionBuilder =
    RestockItemsCompanion Function({
      Value<String> id,
      Value<String> restockId,
      Value<String?> productId,
      Value<String> name,
      Value<int> qty,
      Value<int> costPrice,
      Value<int?> sellPrice,
      Value<int> subtotal,
      Value<int> rowid,
    });

class $$RestockItemsTableFilterComposer
    extends Composer<_$AppDb, $RestockItemsTable> {
  $$RestockItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get restockId => $composableBuilder(
    column: $table.restockId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get costPrice => $composableBuilder(
    column: $table.costPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sellPrice => $composableBuilder(
    column: $table.sellPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subtotal => $composableBuilder(
    column: $table.subtotal,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RestockItemsTableOrderingComposer
    extends Composer<_$AppDb, $RestockItemsTable> {
  $$RestockItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get restockId => $composableBuilder(
    column: $table.restockId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get costPrice => $composableBuilder(
    column: $table.costPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sellPrice => $composableBuilder(
    column: $table.sellPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subtotal => $composableBuilder(
    column: $table.subtotal,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RestockItemsTableAnnotationComposer
    extends Composer<_$AppDb, $RestockItemsTable> {
  $$RestockItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get restockId =>
      $composableBuilder(column: $table.restockId, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get qty =>
      $composableBuilder(column: $table.qty, builder: (column) => column);

  GeneratedColumn<int> get costPrice =>
      $composableBuilder(column: $table.costPrice, builder: (column) => column);

  GeneratedColumn<int> get sellPrice =>
      $composableBuilder(column: $table.sellPrice, builder: (column) => column);

  GeneratedColumn<int> get subtotal =>
      $composableBuilder(column: $table.subtotal, builder: (column) => column);
}

class $$RestockItemsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $RestockItemsTable,
          RestockItem,
          $$RestockItemsTableFilterComposer,
          $$RestockItemsTableOrderingComposer,
          $$RestockItemsTableAnnotationComposer,
          $$RestockItemsTableCreateCompanionBuilder,
          $$RestockItemsTableUpdateCompanionBuilder,
          (
            RestockItem,
            BaseReferences<_$AppDb, $RestockItemsTable, RestockItem>,
          ),
          RestockItem,
          PrefetchHooks Function()
        > {
  $$RestockItemsTableTableManager(_$AppDb db, $RestockItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RestockItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RestockItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RestockItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> restockId = const Value.absent(),
                Value<String?> productId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> qty = const Value.absent(),
                Value<int> costPrice = const Value.absent(),
                Value<int?> sellPrice = const Value.absent(),
                Value<int> subtotal = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RestockItemsCompanion(
                id: id,
                restockId: restockId,
                productId: productId,
                name: name,
                qty: qty,
                costPrice: costPrice,
                sellPrice: sellPrice,
                subtotal: subtotal,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String restockId,
                Value<String?> productId = const Value.absent(),
                required String name,
                required int qty,
                required int costPrice,
                Value<int?> sellPrice = const Value.absent(),
                required int subtotal,
                Value<int> rowid = const Value.absent(),
              }) => RestockItemsCompanion.insert(
                id: id,
                restockId: restockId,
                productId: productId,
                name: name,
                qty: qty,
                costPrice: costPrice,
                sellPrice: sellPrice,
                subtotal: subtotal,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RestockItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $RestockItemsTable,
      RestockItem,
      $$RestockItemsTableFilterComposer,
      $$RestockItemsTableOrderingComposer,
      $$RestockItemsTableAnnotationComposer,
      $$RestockItemsTableCreateCompanionBuilder,
      $$RestockItemsTableUpdateCompanionBuilder,
      (RestockItem, BaseReferences<_$AppDb, $RestockItemsTable, RestockItem>),
      RestockItem,
      PrefetchHooks Function()
    >;

class $AppDbManager {
  final _$AppDb _db;
  $AppDbManager(this._db);
  $$LocalStoresTableTableManager get localStores =>
      $$LocalStoresTableTableManager(_db, _db.localStores);
  $$LocalUsersTableTableManager get localUsers =>
      $$LocalUsersTableTableManager(_db, _db.localUsers);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db, _db.products);
  $$SalesTableTableManager get sales =>
      $$SalesTableTableManager(_db, _db.sales);
  $$SaleItemsTableTableManager get saleItems =>
      $$SaleItemsTableTableManager(_db, _db.saleItems);
  $$CartLinesTableTableManager get cartLines =>
      $$CartLinesTableTableManager(_db, _db.cartLines);
  $$RestocksTableTableManager get restocks =>
      $$RestocksTableTableManager(_db, _db.restocks);
  $$RestockItemsTableTableManager get restockItems =>
      $$RestockItemsTableTableManager(_db, _db.restockItems);
}
