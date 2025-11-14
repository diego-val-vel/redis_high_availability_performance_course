#!/usr/bin/env bash
set -e

echo "1) Levantando todos los servicios excepto los sentinels..."
docker compose up -d \
  redis \
  redisinsight \
  redis-app-a \
  redis-app-b \
  redis-master \
  redis-replica1 \
  redis-replica2 \
  cluster-node-1 \
  cluster-node-2 \
  cluster-node-3 \
  cluster-node-4 \
  cluster-node-5 \
  cluster-node-6

echo "2) Esperando unos segundos a que arranquen master y replicas..."
sleep 8

echo "3) Obteniendo IP interna del master (redis-m5-master)..."
MASTER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' redis-m5-master)
echo "MASTER_IP = $MASTER_IP"

echo "4) Generando archivos sentinel1.conf, sentinel2.conf, sentinel3.conf..."

cat > sentinel1.conf <<EOF
port 26379
dir /tmp
sentinel monitor mymaster $MASTER_IP 6379 2
sentinel down-after-milliseconds mymaster 5000
sentinel failover-timeout mymaster 60000
sentinel parallel-syncs mymaster 1
EOF

cat > sentinel2.conf <<EOF
port 26379
dir /tmp
sentinel monitor mymaster $MASTER_IP 6379 2
sentinel down-after-milliseconds mymaster 5000
sentinel failover-timeout mymaster 60000
sentinel parallel-syncs mymaster 1
EOF

cat > sentinel3.conf <<EOF
port 26379
dir /tmp
sentinel monitor mymaster $MASTER_IP 6379 2
sentinel down-after-milliseconds mymaster 5000
sentinel failover-timeout mymaster 60000
sentinel parallel-syncs mymaster 1
EOF

echo "5) Levantando los 3 sentinels desde docker compose..."
docker compose up -d sentinel1 sentinel2 sentinel3

echo "6) Estado final de los contenedores:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
