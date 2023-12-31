# frozen_string_literal: true

module Services
  SERVICE = %w[
    assign-account
    assistant
    assist-result
    auto-submit
    conserver
    debian
    delimiter
    dnsmasq
    docker2rootfs
    dracut-initrd
    es
    etcd
    extract-stats
    fetch-mail
    fluentd-base
    git-daemon
    git-mirror
    initrd-cifs
    initrd-http
    kibana
    kibana-logging
    lifecycle
    lkp-initrd
    logging-es
    mail-robot
    manjaro
    master-fluentd
    minio
    monitoring
    netdata
    netdata-slave
    ntp-server
    openresty-proxy-cache
    os-cifs
    os-http
    osimage
    os-nfs
    qcow2rootfs
    qemu-efi
    rabbitmq
    redis
    register-accounts
    registry
    remote-git
    result-cifs
    result-webdav
    rpm-repo
    rsync-server
    scheduler-3000
    scheduler-https
    scheduler-nginx
    send-internet-mail
    send-mail
    shellcheck
    srv-http
    ssh-r
    sub-fluentd
    submit
    update-os-docker
    updaterepo
    upload-libvirt-xml
    web-backend
    web-backend-nginx
    webhook
  ].freeze
end
