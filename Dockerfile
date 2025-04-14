# Build frontend
FROM node:16-alpine AS node-builder

WORKDIR /app

RUN apk add --no-cache apache-ant git && \
    git clone https://github.com/wanglin2/lx-doc.git lx-doc && \
    # Build workbench
    cd lx-doc/workbench && \
    npm ci --no-audit --no-fund && \
    # Create a symbolic link from error to Error to handle case sensitivity issues
    mkdir -p src/pages/error && \
    ln -sf ../Error/Index.vue src/pages/error/Index.vue && \
    npm run build && \
    mv dist /app/dist && \
    \
    # Build mind-map
    cd /app/lx-doc/mind-map && \
    npm ci --no-audit --no-fund && \
    npm run build && \
    mv dist /app/dist/mind-map && \
    \
    # Build whiteboard
    cd /app/lx-doc/whiteboard && \
    npm ci --no-audit --no-fund && \
    npm run build && \
    mv dist /app/dist/whiteboard && \
    \
    # Build flowchart
    cd /app/lx-doc/flowchart && \
    npm ci --no-audit --no-fund && \
    mkdir -p /app/lx-doc/flowchart/etc/integrate && \
    echo "// Empty file to satisfy build process" > /app/lx-doc/flowchart/etc/integrate/Integrate.js && \
    npm run build && \
    mv src/main/webapp /app/dist/flowchart

# Build backend
FROM maven:3.8-openjdk-8-slim AS maven-builder

WORKDIR /app

ARG BRANCH
COPY ${BRANCH} ./${BRANCH}
RUN cd ${BRANCH} && \
    mvn -DskipTests -U clean package

# Final image
FROM openjdk:8-jdk-alpine

ARG BRANCH
ENV SERVICE=lx-doc \
    MYSQL_DATABASE=lx_doc \
    MYSQL_ROOT_PASSWORD=lx_doc_test

USER root

EXPOSE 9222 80 3306

# Install required packages and setup directories in a single layer
RUN apk add --no-cache tzdata nginx mysql mysql-client && \
    cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone && \
    apk del tzdata && \
    mkdir -p /var/log/nginx/ \
             /usr/web/html/ \
             /usr/nginx/config/ \
             /usr/config/${SERVICE}/ \
             /usr/app/${SERVICE}/ \
             /usr/logs/${SERVICE}/ \
             /usr/attachment/${SERVICE}/ && \
    rm -rf /var/cache/apk/*

# Copy configuration files
COPY ${BRANCH}/nginx.conf /usr/nginx/config/
COPY ${BRANCH}/my.cnf /etc/mysql/my.cnf
COPY ${BRANCH}/mysql_init_start.sh \
     ${BRANCH}/doc.sql \
     ${BRANCH}/run_in_docker_whole.sh \
     /usr/app/${SERVICE}/
COPY ${BRANCH}/application-prod.yml /usr/config/${SERVICE}/
COPY --from=maven-builder /app/${BRANCH}/lx-core/target/lx-doc.jar /usr/app/${SERVICE}/
COPY --from=node-builder /app/dist /usr/web/html/lx-doc

VOLUME /usr/app/mysql

WORKDIR /usr/app/${SERVICE}/

ENTRYPOINT ["sh", "run_in_docker_whole.sh", "initStart"]
