# SPDX-License-Identifier: MulanPSL-2.0+
# Copyright (c) 2020 Huawei Technologies Co., Ltd. All rights reserved.

FROM nginx:1.20.0-alpine

MAINTAINER Lu Weitao <luweitaobe@163.com>

ADD root /

#RUN sed -ri.origin 's|^https?://dl-cdn.alpinelinux.org|http://mirrors.huaweicloud.com|g' /etc/apk/repositories

#RUN chown -R nginx:nginx /srv/_h5ai

# Disable access logs without affecting the printing of error logs
RUN sed -i '/server {/a \ \ \ \ access_log off;' /etc/nginx/conf.d/default.conf

ENTRYPOINT ["/sbin/entrypoint.sh"]
