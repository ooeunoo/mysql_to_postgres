# mysql_to_postgres

https://pgloader.readthedocs.io/en/latest/ref/mysql.html


/opt/homebrew/opt/mysql/bin/mysqldump


brew install pgloader

docker-compose run --rm pgloader bash -c "pgloader --verbose /pgloader_config/pgloader.load"




uniquify index names, preserve index names

MySQL index names are unique per-table whereas in PostgreSQL index names have to be unique per-schema. The default for pgloader is to change the index name by prefixing it with idx_OID where OID is the internal numeric identifier of the table the index is built against.

In somes cases like when the DDL are entirely left to a framework it might be sensible for pgloader to refrain from handling index unique names, that is achieved by using the preserve index names option.

The default is to uniquify index names.

Even when using the option preserve index names, MySQL primary key indexes named “PRIMARY” will get their names uniquified. Failing to do so would prevent the primary keys to be created again in PostgreSQL where the index names must be unique per schema.
uniquify index names,