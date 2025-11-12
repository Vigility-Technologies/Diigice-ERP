
redis_cache: redis-server config/redis_cache.conf
redis_queue: redis-server config/redis_queue.conf


web: bench serve  --port 8001


socketio: /usr/bin/node apps/frappe/socketio.js


# watch: bench watch
# DISABLED: watch process causes asset hash mismatches (rebuilds with new hashes while assets.json is locked)

schedule: bench schedule

worker:  bench worker 1>> logs/worker.log 2>> logs/worker.error.log

