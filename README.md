# mysql_to_postgres

https://pgloader.readthedocs.io/en/latest/ref/mysql.html


/opt/homebrew/opt/mysql/bin/mysqldump


brew install pgloader

docker-compose run --rm pgloader bash -c "pgloader --verbose /pgloader_config/pgloader.load"