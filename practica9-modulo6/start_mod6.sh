#!/usr/bin/env bash
set -e

echo "========================================"
echo " Laboratorio Redis HA - Modulo 6"
echo "========================================"
echo

# 1) Limpiar stack previo (si existe)
echo "[INFO] Limpiando stack previo (si existe) ..."
docker compose -f docker-compose.ha.yml down -v 2>/dev/null || true
docker rm -f redis-sentinel-1 redis-sentinel-2 redis-sentinel-3 2>/dev/null || true
echo

# 2) Levantar master / replica / extra / redisinsight
echo "[INFO] Levantando servicios base (master, replica, extra, RedisInsight) ..."
docker compose -f docker-compose.ha.yml up -d
echo

# 3) Obtener IP interna del master
MASTER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' redis-master)
if [ -z "$MASTER_IP" ]; then
  echo "[ERROR] No pude obtener la IP de redis-master. Revisa que el contenedor exista."
  exit 1
fi
echo "[INFO] IP interna de redis-master: $MASTER_IP"

# 4) Obtener nombre de la red creada por docker compose
NET_NAME=$(docker network ls --format '{{.Name}}' | grep 'practica9-modulo6_redis-net' | head -n 1)
if [ -z "$NET_NAME" ]; then
  # Fallback: usa el nombre por defecto si cambia el prefijo del proyecto
  NET_NAME="practica9-modulo6_redis-net"
fi
echo "[INFO] Usando red de Docker: $NET_NAME"
echo

# 5) Generar archivos sentinel-*.conf con la IP real del master
echo "[INFO] Generando archivos de configuracion de Sentinel ..."

cat > sentinel-1.conf <<EOF
port 26379
dir /tmp
sentinel monitor mymaster $MASTER_IP 6379 2
sentinel down-after-milliseconds mymaster 5000
sentinel failover-timeout mymaster 60000
sentinel parallel-syncs mymaster 1
EOF

cat > sentinel-2.conf <<EOF
port 26379
dir /tmp
sentinel monitor mymaster $MASTER_IP 6379 2
sentinel down-after-milliseconds mymaster 5000
sentinel failover-timeout mymaster 60000
sentinel parallel-syncs mymaster 1
EOF

cat > sentinel-3.conf <<EOF
port 26379
dir /tmp
sentinel monitor mymaster $MASTER_IP 6379 2
sentinel down-after-milliseconds mymaster 5000
sentinel failover-timeout mymaster 60000
sentinel parallel-syncs mymaster 1
EOF

echo "[INFO] Archivos sentinel-*.conf generados."
echo

# 6) Levantar los 3 sentinels con docker run en la misma red
echo "[INFO] Levantando contenedores Sentinel ..."

docker run -d \
  --name redis-sentinel-1 \
  --network "$NET_NAME" \
  -p 26379:26379 \
  -v "$(pwd)/sentinel-1.conf:/etc/redis/sentinel.conf" \
  redis:7-alpine \
  redis-sentinel /etc/redis/sentinel.conf

docker run -d \
  --name redis-sentinel-2 \
  --network "$NET_NAME" \
  -p 26380:26379 \
  -v "$(pwd)/sentinel-2.conf:/etc/redis/sentinel.conf" \
  redis:7-alpine \
  redis-sentinel /etc/redis/sentinel.conf

docker run -d \
  --name redis-sentinel-3 \
  --network "$NET_NAME" \
  -p 26381:26379 \
  -v "$(pwd)/sentinel-3.conf:/etc/redis/sentinel.conf" \
  redis:7-alpine \
  redis-sentinel /etc/redis/sentinel.conf

echo
echo "[INFO] Contenedores en ejecucion:"
docker ps --format 'table {{.Names}}	{{.Image}}	{{.Status}}	{{.Ports}}'

echo
echo "[OK] Laboratorio de alta disponibilidad listo."
echo "    - Master        : redis-master (puerto host 6379)"
echo "    - Replica       : redis-replica-1 (puerto host 6380)"
echo "    - Extra (shard) : redis-extra (puerto host 6381)"
echo "    - Sentinels     : 26379, 26380, 26381"
echo "    - RedisInsight  : http://localhost:5540"
