


# Backend

### Development Dependencies

Nginx
uWSGI
Python 3.12
Flask 3.0.3


To run in development mode:     
```commandline
cd server/secure-file-server
python server.py
```

To run in production:
```commandline
cd server/secure-file-server
sudo /usr/local/bin/uwsgi  --lazy --ini wsgi.ini
```

Build container:
```commandline
cd build
docker build Dockerfile
```