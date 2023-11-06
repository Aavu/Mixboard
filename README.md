# Mixboard
***
## Project Setup
* Create new conda env using environment.yml
* Install PyTorch from their website (since the installation depends on your machine’s cuda)
* Install redis stack server from https://redis.io/docs/install/install-stack
* Install tmux

## Getting started
* Make sure port 6379/tcp is not busy
* Follow the README.md from the main branch for spotify dev setup.
    - In song.py, replace the client ID and scret in line 349 and 350 with your spotify app client ID and secret respectively
* Run ./run_server to start the mixboard server. It creates a new tmux session and 3 windows for gunicorn, redis-stack-server and celery
