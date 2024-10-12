# Build frontend
FROM node:16 AS node-builder

WORKDIR /app

ADD lx-doc ./lx-doc

RUN cd lx-doc/workbench && \
    npm i && \
    echo ls -la /app/lx-doc/workbench/src/pages/error && \
    npm run build && \
    mv dist /app/dist

RUN cd lx-doc/mind-map && \
    npm i && \
    npm run build && \
    mv dist /app/dist/mind-map

RUN cd lx-doc/whiteboard && \
    npm i && \
    npm run build && \
    mv dist /app/dist/whiteboard

RUN apt update && \
    apt install -y ant

RUN cd lx-doc/flowchart && \
    npm i && \
    npm run build && \
    mv src/main/webapp /app/dist/flowchart
    
RUN rm -rf /app/lx-doc

# Build backend
FROM maven:3.8.6-jdk-11 AS maven-builder

WORKDIR /app

ADD personal ./personal

RUN cd personal && \
    mvn -DskipTests -U clean package && \
    mv lx-core/target/lx-doc.jar ../ && \
    cd .. && \
    rm -rf personal

# Build docker image
FROM openjdk:8-jdk-alpine

ENV SERVICE=lx-doc
ENV MYSQL_DATABASE=lx_doc
ENV MYSQL_ROOT_PASSWORD=lx_doc_test

USER root

EXPOSE 9222
EXPOSE 80
EXPOSE 3306

# 处理时区
RUN apk add tzdata  \
    && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone \
    && apk del tzdata

# 安装 nginx
RUN apk add --no-cache nginx

# nginx 日志目录
RUN mkdir -p /var/log/nginx/ \
# web 静态资源存放目录，这个目录最好映射到宿主机
    && mkdir -p /usr/web/html/ \
    && mkdir -p /usr/nginx/config/ \
    && mkdir -p /usr/config/${SERVICE}/ \
    && mkdir -p /usr/app/${SERVICE}/ \
    && mkdir -p /usr/logs/${SERVICE}/ \
    && mkdir -p /usr/attament/${SERVICE}/

# 安装 mysql
RUN apk add --update mysql mysql-client \
    && rm -f /var/cache/apk/*

COPY ./personal/nginx.conf /usr/nginx/config/
COPY ./personal/my.cnf /etc/mysql/my.cnf
COPY ./personal/mysql_init_start.sh /usr/app/${SERVICE}/
COPY ./personal/doc.sql /usr/app/${SERVICE}/
COPY ./personal/run_in_docker_whole.sh /usr/app/${SERVICE}/
COPY ./personal/application-prod.yml /usr/config/${SERVICE}/
COPY --from=maven-builder /app/lx-doc.jar /usr/app/${SERVICE}/
COPY --from=node-builder /app/dist /usr/web/html/lx-doc

WORKDIR /usr/app/${SERVICE}/

ENTRYPOINT ["sh", "run_in_docker_whole.sh", "initStart"]