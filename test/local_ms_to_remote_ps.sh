#!/bin/bash

# 환경 변수 설정
MYSQL_CONTAINER_NAME="mysql"
MYSQL_PORT="3306"
MYSQL_USER="custody"
MYSQL_PASSWORD="password"
MYSQL_DATABASE="user"

PG_HOST="remote_postgres_host"  # 원격 PostgreSQL 서버 주소
PG_PORT="5432"
PG_USER="custody"
PG_PASSWORD="password"
PG_DATABASE="user"

CONFIG_FILE="pgloader_config.load"

# 로그 함수
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# 오류 처리 함수
error_exit() {
    log "ERROR: $1" >&2
    exit 1
}

# MySQL 컨테이너 IP 주소 가져오기
get_mysql_ip() {
    MYSQL_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $MYSQL_CONTAINER_NAME)
    if [ -z "$MYSQL_IP" ]; then
        error_exit "Failed to get MySQL container IP address"
    fi
    log "MySQL container IP: $MYSQL_IP"
}

# pgloader 설정 파일 생성 함수
create_pgloader_config() {
    log "Creating pgloader configuration file..."
    
    cat << EOF > "$CONFIG_FILE"
LOAD DATABASE
    FROM mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@${MYSQL_IP}:${MYSQL_PORT}/${MYSQL_DATABASE}
    INTO postgresql://${PG_USER}:${PG_PASSWORD}@${PG_HOST}:${PG_PORT}/${PG_DATABASE}

WITH include no drop, create tables, create indexes, reset sequences, foreign keys

SET work_mem to '128MB', maintenance_work_mem to '512 MB'

CAST type datetime to timestamp using zero-dates-to-null,
     type date to date using zero-dates-to-null,
     type tinyint to smallint

EXCLUDING TABLE NAMES MATCHING 'foo', 'bar'

BEFORE LOAD DO
    \$\$ CREATE SCHEMA IF NOT EXISTS "user"; \$\$;
EOF
    
    if [ ! -f "$CONFIG_FILE" ]; then
        error_exit "Failed to create pgloader configuration file"
    fi
    
    log "pgloader configuration file created successfully"
    ls -l "$CONFIG_FILE"
}

# 마이그레이션 실행 함수
run_migration() {
    log "Starting migration with pgloader..."
    if [ ! -f "$CONFIG_FILE" ]; then
        error_exit "pgloader configuration file not found"
    fi
    docker run --rm --network host -v $(pwd)/$CONFIG_FILE:/tmp/$CONFIG_FILE dimitri/pgloader:latest pgloader /tmp/$CONFIG_FILE || error_exit "Migration failed"
}

# 데이터 확인 함수
check_migrated_data() {
    log "Checking migrated data in PostgreSQL..."
    if ! command -v psql &> /dev/null; then
        log "psql command not found. Skipping data check."
        return
    fi
    PGPASSWORD=$PG_PASSWORD psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d $PG_DATABASE -c "SELECT table_name, (xpath('/row/c/text()', query_to_xml('SELECT count(*) AS c FROM '||quote_ident(table_name), FALSE, TRUE, '')))[1]::text::int AS row_count FROM information_schema.tables WHERE table_schema='public' ORDER BY table_name;" || error_exit "Failed to check migrated data"
}

# 정리 함수
cleanup() {
    log "Cleaning up..."
    if [ -e "$CONFIG_FILE" ]; then
        rm -f "$CONFIG_FILE"
    fi
}

# 메인 실행 함수
main() {
    log "Starting migration process..."
    
    get_mysql_ip
    create_pgloader_config
    run_migration
    check_migrated_data
    
    log "Migration process completed successfully."
}

# 스크립트 실행
main

# 종료 트랩 설정
trap cleanup EXIT