#!/usr/bin/env bash
service nginx start
cd /app/MapTilesGenerator/server
/usr/local/bin/uwsgi --socket /tmp/wsgi.sock --lazy --ini uwsgi.ini
service nginx reload