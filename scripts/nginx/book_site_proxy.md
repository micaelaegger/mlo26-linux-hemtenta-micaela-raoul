
# The nginx book-api script:

One idea is to maybe have even this in a small runnable script?

### This is the script named "book-api" that we used inside the /etc/nginx/sites-available/ folder:

server {
    listen 80;
    server_name 13.51.232.9;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    access_log /var/log/nginx/fastapi_access.log;
    error_log /var/log/nginx/fastapi_error.log;
}


# NGINX and symlinks

It is added into the sites-available folder and then sym-linked into the sites-enabled folder using:

sudo ln -s  /etc/nginx/sites-available/<filename></filename> /etc/nginx/sites-enabled

### extended symlink

sudo ln -sfn /etc/nginx/sites-available/book-api /etc/nginx/sites-enabled/book-api

    -s — Creates a **symbolic** link.

    -f — Replaces an existing destination **file** or link.

    -n — Treats an existing destination symlink to a directory as a link rather than following it.

Replacing the <filename></filename> with what we want to call the book-api related file. we'll probably just stick with book-api.

# Removing links

If we want to remove the default link, which we can easily ensure to do in the setup.sh script:

sudo rm /etc/nginx/sites-enabled/default<filename></filename>

It is functionally the same as if removing the website/API/service tied to this service, without having to move/delete any files!
