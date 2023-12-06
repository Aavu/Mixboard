import os
import redis
from rq import Worker, Queue, Connection
from generator.config.config import REDIS_PORT

listen = ['high', 'default', 'low']

redis_url = os.getenv('REDISTOGO_URL', f'redis://localhost:{REDIS_PORT}')
conn = redis.from_url(redis_url)

if __name__ == '__main__':
    with Connection(conn):
        worker = Worker(map(Queue, listen))
        worker.work()
