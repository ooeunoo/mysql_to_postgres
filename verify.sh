#!/bin/bash

# 환경 변수 로드
source .env

echo "마이그레이션 결과를 검증합니다..."

# MySQL 정보 추출 함수
get_mysql_info() {
    docker-compose exec -T mysql mysql --no-warnings -u root -p"${MYSQL_ROOT_PASSWORD}" -D "${MYSQL_DATABASE}" -se "$1"
}

# PostgreSQL 정보 추출 함수
get_pg_info() {
    docker-compose exec -T postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -t -c "$1" | tr -d ' '
}

# 구조적 비교
echo "구조적 비교:"
echo "---------------------------------------------------"
printf "| %-20s | %-10s | %-10s | %-5s |\n" "Metric" "MySQL" "PostgreSQL" "Match"
echo "---------------------------------------------------"

metrics=(
    "Table Count:SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${MYSQL_DATABASE}':SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'"
    "Column Count:SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='${MYSQL_DATABASE}':SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='public'"
    "Index Count:SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema='${MYSQL_DATABASE}':SELECT COUNT(*) FROM pg_indexes WHERE schemaname='public'"
    "Foreign Key Count:SELECT COUNT(*) FROM information_schema.key_column_usage WHERE referenced_table_schema='${MYSQL_DATABASE}':SELECT COUNT(*) FROM information_schema.table_constraints WHERE constraint_type='FOREIGN KEY' AND table_schema='public'"
    "Primary Key Count:SELECT COUNT(*) FROM information_schema.table_constraints WHERE constraint_type='PRIMARY KEY' AND table_schema='${MYSQL_DATABASE}':SELECT COUNT(*) FROM information_schema.table_constraints WHERE constraint_type='PRIMARY KEY' AND table_schema='public'"
)

for metric in "${metrics[@]}"; do
    IFS=':' read -r name mysql_query pg_query <<< "$metric"
    mysql_value=$(get_mysql_info "$mysql_query")
    pg_value=$(get_pg_info "$pg_query")
    if [ "$mysql_value" = "$pg_value" ]; then
        match="Yes"
    else
        match="No"
    fi
    printf "| %-20s | %-10s | %-10s | %-5s |\n" "$name" "$mysql_value" "$pg_value" "$match"
done

echo "---------------------------------------------------"

# 테이블별 레코드 수 비교
echo -e "\n테이블별 레코드 수 비교:"
echo "---------------------------------------------------"
printf "| %-20s | %-10s | %-10s | %-5s |\n" "Table Name" "MySQL" "PostgreSQL" "Match"
echo "---------------------------------------------------"

# MySQL 테이블 목록 가져오기
TABLES=$(get_mysql_info "SHOW TABLES;")

for table in $TABLES; do
    mysql_count=$(get_mysql_info "SELECT COUNT(*) FROM $table;")
    pg_count=$(get_pg_info "SELECT COUNT(*) FROM public.$table;")
    if [ "$mysql_count" = "$pg_count" ]; then
        match="Yes"
    else
        match="No"
    fi
    printf "| %-20s | %-10s | %-10s | %-5s |\n" "$table" "$mysql_count" "$pg_count" "$match"
done
echo "---------------------------------------------------"

echo -e "\n검증이 완료되었습니다. 위의 결과를 확인하여 마이그레이션이 성공적으로 이루어졌는지 확인해 주세요."