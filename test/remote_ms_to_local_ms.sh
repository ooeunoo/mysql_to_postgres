#!/bin/bash

# Docker Compose로 MySQL 컨테이너 실행
docker-compose up -d

# MySQL 컨테이너가 완전히 시작될 때까지 대기
echo "Waiting for MySQL to start..."
sleep 30

# MySQL 컨테이너 상태 확인
if ! docker ps | grep -q mysql; then
    echo "Error: MySQL container is not running"
    exit 1
fi

# dump.sql 파일이 있는지 확인
if [ ! -f "dump.sql" ]; then
    echo "Error: dump.sql file not found"
    exit 1
fi

echo "MySQL container is running. Data should be imported automatically."
echo "Checking imported data..."

# 데이터베이스의 테이블 목록 확인
docker exec -i mysql mysql -uroot -prootpassword user -e "SHOW TABLES;"

echo "Migration process completed."