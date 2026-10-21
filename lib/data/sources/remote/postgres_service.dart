import 'package:postgres/postgres.dart';

class PostgresService {
  static final PostgresService _instance = PostgresService._internal();

  factory PostgresService() => _instance;

  PostgresService._internal();

  Connection? _connection;

  Future<Connection> get connection async {
    if (_connection != null) return _connection!;

    _connection = await Connection.open(
      Endpoint(
        host: '10.249.121.205', 
        port: 5433,
        database: 'kavkaz_restourant',
        username: 'postgres',
        password: '12345',
      ),
      settings: const ConnectionSettings(
        sslMode: SslMode.disable,
      ),
    );

    return _connection!;
  }

  Future<void> close() async {
    await _connection?.close();
    _connection = null;
  }
}