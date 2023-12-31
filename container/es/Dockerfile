# SPDX-License-Identifier: MulanPSL-2.0+
# Copyright (c) 2020 Huawei Technologies Co., Ltd. All rights reserved.

ARG BASE_IMAGE
FROM ${BASE_IMAGE}

ARG MEMORY
ARG USER
ARG PASSWORD

RUN sed -i 's:#network.host\: _site_:network.host\: 0.0.0.0:' /usr/share/elasticsearch/config/elasticsearch.yml && \
    sed -i '$a path.data: /srv/es' /usr/share/elasticsearch/config/elasticsearch.yml && \
    sed -i '$a node.name: node-1' /usr/share/elasticsearch/config/elasticsearch.yml && \
    sed -i '$a cluster.initial_master_nodes: ["node-1"]' /usr/share/elasticsearch/config/elasticsearch.yml && \
    sed -i '$a xpack.security.enabled: true' /usr/share/elasticsearch/config/elasticsearch.yml && \
    sed -i '$a xpack.license.self_generated.type: basic' /usr/share/elasticsearch/config/elasticsearch.yml && \
    sed -i '$a xpack.security.transport.ssl.enabled: true' /usr/share/elasticsearch/config/elasticsearch.yml && \
    echo "-Xms${MEMORY}m" >> /usr/share/elasticsearch/config/jvm.options && \
    echo "-Xmx${MEMORY}m" >> /usr/share/elasticsearch/config/jvm.options && \
    echo "-Dlog4j2.formatMsgNoLookups=true" >> /usr/share/elasticsearch/config/jvm.options

RUN mkdir /etc/yum.repos.d.backup && \
    mv /etc/yum.repos.d/*.repo /etc/yum.repos.d.backup && \
    curl https://mirrors.aliyun.com/repo/Centos-vault-8.5.2111.repo > /etc/yum.repos.d/CentOS-Base.repo && \
    yum makecache && \
    yum install -y -q git python38

RUN mkdir /usr/share/elasticsearch/tmp
WORKDIR /usr/share/elasticsearch

ENV PATH /usr/share/elasticsearch/bin:$PATH
ENV JAVA_HOME /usr/share/elasticsearch/jdk
ENV ES_TMPDIR /usr/share/elasticsearch/tmp

RUN ./bin/elasticsearch-users useradd ${USER} -p ${PASSWORD} -r superuser && \
    ./bin/elasticsearch-plugin install https://repo.oepkgs.net/openEuler/compass-ci/cci-deps/elasticsearch/elasticsearch-sql-7.11.1.0.zip && \
    chown -R 1090:1090 /usr/share/elasticsearch

RUN rm lib/log4j-core*.jar && \
    rm lib/log4j-api*.jar && \
    rm modules/x-pack-core/log4j-1.2-api*.jar && \
    rm modules/x-pack-identity-provider/log4j-slf4j-impl*.jar && \
    rm modules/x-pack-security/log4j-slf4j-impl*.jar

COPY ./apache-log4j-2.17.2-bin/log4j-core-2.17.2.jar /usr/share/elasticsearch/lib
COPY ./apache-log4j-2.17.2-bin/log4j-api-2.17.2.jar /usr/share/elasticsearch/lib
COPY ./apache-log4j-2.17.2-bin/log4j-1.2-api-2.17.2.jar /usr/share/elasticsearch/modules/x-pack-core
COPY ./apache-log4j-2.17.2-bin/log4j-slf4j-impl-2.17.2.jar /usr/share/elasticsearch/modules/x-pack-identity-provider
COPY ./apache-log4j-2.17.2-bin/log4j-slf4j-impl-2.17.2.jar /usr/share/elasticsearch/modules/x-pack-security

VOLUME ["/srv/es"]

EXPOSE 9200 9300

USER 1090
CMD ["elasticsearch"]
