FROM debian:bookworm-slim

LABEL maintainer="support@ip2location.com"

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get -qy install ca-certificates gnupg curl wget unzip \
	&& rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | gpg -o /usr/share/keyrings/mongodb-server-8.0.gpg --dearmor
RUN echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg] http://repo.mongodb.org/apt/debian bookworm/mongodb-org/8.0 main" | tee /etc/apt/sources.list.d/mongodb-org-8.0.list
RUN apt-get update \
	&& apt-get install -y mongodb-org \
	&& rm -rf /var/lib/apt/lists/*

ADD app/main.sh /main.sh
ADD app/update.sh /update.sh
ADD app/entrypoint.sh /entrypoint.sh
RUN chmod 755 /*.sh

VOLUME ["/data/db"]

EXPOSE 27017

ENTRYPOINT ["/entrypoint.sh"]
