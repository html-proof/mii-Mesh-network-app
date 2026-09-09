import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
part 'database.g.dart';

class Profiles extends Table {
  IntColumn get id => integer()();
  TextColumn get displayName => text().withLength(min: 1, max: 40)();
  BlobColumn get publicKey => blob()();
  @override
  Set<Column> get primaryKey => {id};
}

class Conversations extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get kind => text()();
  TextColumn get draft => text().withDefault(const Constant(''))();
  @override
  Set<Column> get primaryKey => {id};
}

class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text().references(Conversations, #id)();
  TextColumn get body => text()();
  IntColumn get createdAt => integer()();
  IntColumn get expiresAt => integer()();
  TextColumn get status => text()();
  IntColumn get sequence => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

class Outbox extends Table {
  TextColumn get messageId =>
      text().references(Messages, #id, onDelete: KeyAction.cascade)();
  BlobColumn get envelope => blob()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  IntColumn get nextAttempt => integer()();
  @override
  Set<Column> get primaryKey => {messageId};
}

class Preferences extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Profiles, Conversations, Messages, Outbox, Preferences])
class MeshDatabase extends _$MeshDatabase {
  MeshDatabase(super.executor);
  factory MeshDatabase.encrypted(File file, String key) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(key)) {
      throw ArgumentError('Invalid key');
    }
    return MeshDatabase(
      NativeDatabase.createInBackground(
        file,
        setup: (raw) {
          if (raw.select('PRAGMA cipher').isEmpty) {
            throw StateError('Encrypted SQLite is required');
          }
          raw.execute("PRAGMA key = '$key'");
          raw.execute('PRAGMA foreign_keys = ON');
          raw.execute('PRAGMA secure_delete = ON');
          raw.execute('PRAGMA temp_store = MEMORY');
        },
      ),
    );
  }
  @override
  int get schemaVersion => 2;
  Future<void> createMeshTables() async {
    await customStatement(
      'CREATE TABLE IF NOT EXISTS mesh_peers (id TEXT PRIMARY KEY, name TEXT NOT NULL, box_key BLOB NOT NULL)',
    );
    await customStatement(
      'CREATE TABLE IF NOT EXISTS mesh_packets (id TEXT PRIMARY KEY, packet BLOB NOT NULL, expires INTEGER NOT NULL)',
    );
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await createMeshTables();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) await createMeshTables();
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
  Future<void> purgeExpired(int now) async {
    await (delete(
      messages,
    )..where((m) => m.expiresAt.isSmallerOrEqualValue(now))).go();
  }
}
