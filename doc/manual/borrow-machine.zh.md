# 前提条件

请确认您已按照 [apply-account.md](https://gitee.com/wu_fengguang/compass-ci/blob/master/doc/manual/apply-account.md)完成如下操作：
- send apply account email.
- receive email from compass-ci@qq.com.
- local environment configuration.


# 申请测试机（虚拟机）

1. 生成本地RSA公私钥对

    ```shell
    hi684@account-vm ~% ssh-keygen -t rsa
    Generating public/private rsa key pair.
    Enter file in which to save the key (/home/hi684/.ssh/id_rsa):
    Created directory '/home/hi684/.ssh'.
    Enter passphrase (empty for no passphrase):
    Enter same passphrase again:
    Your identification has been saved in /home/hi684/.ssh/id_rsa.
    Your public key has been saved in /home/hi684/.ssh/id_rsa.pub.
    The key fingerprint is:
    SHA256:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx hi684@account-vm
    The key's randomart image is:
    +---[RSA 2048]----+
    |xxxxxxxxxxxxxxxxx|
    |xxxxxxxxxxxxxxxxx|
    |xxxxxxxxxxxxxxxxx|
    |xxxxxxxxxxxxxxxxx|
    |xxxxxxxxxxxxxxxxx|
    |xxxxxxxxxxxxxxxxx|
    |xxxxxxxxxxxxxxxxx|
    |xxxxxxxxxxxxxxxxx|
    |xxxxxxxxxxxxxxxxx|
    +----[SHA256]-----+
    hi684@account-vm ~% ls -hla .ssh
    total 16K
    drwx------. 2 hi684 hi684 4.0K Nov 26 16:37 .
    drwx------. 7 hi684 hi684 4.0K Nov 26 16:37 ..
    -rw-------. 1 hi684 hi684 1.8K Nov 26 16:37 id_rsa
    -rw-r--r--. 1 hi684 hi684  398 Nov 26 16:37 id_rsa.pub
    ```

2. 根据需求选择yaml

    每位用户`/home/${USER}`目录下面都存放了一个 lkp-tests 的文件夹。

    ```shell
    hi684@account-vm ~% cd lkp-tests/jobs
    hi684@account-vm ~/lkp-tests/jobs% ls -hl borrow-*
    -rw-r--r--. 1 root root  53 Nov  2 14:54 borrow-10d.yaml
    -rw-r--r--. 1 root root  64 Nov  2 14:54 borrow-1d.yaml
    -rw-r--r--. 1 root root 235 Nov 19 15:27 borrow-1h.yaml
    ```

3. 提交yaml并连接测试机（虚拟机）

    ```shell
    hi684@account-vm ~/lkp-tests/jobs% submit -c -m testbox=vm-2p8g borrow-1h.yaml
    submit borrow-1h.yaml, got job_id=z9.170593
    query=>{"job_id":["z9.170593"]}
    connect to ws://172.168.131.2:11310/filter
    {"job_id":"z9.170593","message":"","job_state":"submit","result_root":"/srv/result/borrow/2020-11-26/vm-2p8g/openeuler-20.03-aarch64/3600/z9.170593"}
    {"job_id": "z9.170593", "result_root": "/srv/result/borrow/2020-11-26/vm-2p8g/openeuler-20.03-aarch64/3600/z9.170593", "job_state": "set result root"}
    {"job_id": "z9.170593", "job_state": "boot"}
    {"job_id": "z9.170593", "job_state": "download"}
    {"time":"2020-11-26 14:45:06","mac":"0a-1f-0d-3c-91-5c","ip":"172.18.156.13","job_id":"z9.170593","state":"running","testbox":"vm-2p8g.taishan200-2280-2s64p-256g--a38-12"}
    {"job_state":"running","job_id":"z9.170593"}
    {"job_id": "z9.170593", "state": "set ssh port", "ssh_port": "51840", "tbox_name": "vm-2p8g.taishan200-2280-2s64p-256g--a38-12"}
    Host 172.168.131.2 not found in /home/hi684/.ssh/known_hosts
    Warning: Permanently added '[172.168.131.2]:51840' (ECDSA) to the list of known hosts.
    Last login: Wed Sep 23 11:10:58 2020


    Welcome to 4.19.90-2003.4.0.0036.oe1.aarch64

    System information as of time:  Thu Nov 26 06:44:18 CST 2020

    System load:    0.83
    Processes:      107
    Memory used:    6.1%
    Swap used:      0.0%
    Usage On:       89%
    IP address:     172.18.156.13
    Users online:   1



    root@vm-2p8g ~#
    ```

    更多关于`submit命令如何使用`、`testbox都有什么可选项`、`如何borrow指定的操作系统`，请参见文章末尾FAQ。

4. 使用完毕退还测试机（虚拟机）

    ```shell
    root@vm-2p8g ~# reboot
    Connection to 172.168.131.2 closed by remote host.
    Connection to 172.168.131.2 closed.
    hi684@account-vm ~/lkp-tests/jobs%
    ```


# 申请测试机（物理机）


1. 生成本地RSA公私钥对

    ```shell
    hi684@account-vm ~% ssh-keygen -t rsa
    Generating public/private rsa key pair.
    Enter file in which to save the key (/home/hi684/.ssh/id_rsa):
    Created directory '/home/hi684/.ssh'.
    Enter passphrase (empty for no passphrase):
    Enter same passphrase again:
    Your identification has been saved in /home/hi684/.ssh/id_rsa.
    Your public key has been saved in /home/hi684/.ssh/id_rsa.pub.
    The key fingerprint is:
    SHA256:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx hi684@account-vm
    The key's randomart image is:
    +---[RSA 2048]----+
    |xxxxxxxxxxxxxxxxx|
    |xxxxxxxxxxxxxxxxx|
    |xxxxxxxxxxxxxxxxx|
    |xxxxxxxxxxxxxxxxx|
    |xxxxxxxxxxxxxxxxx|
    |xxxxxxxxxxxxxxxxx|
    |xxxxxxxxxxxxxxxxx|
    |xxxxxxxxxxxxxxxxx|
    |xxxxxxxxxxxxxxxxx|
    +----[SHA256]-----+
    hi684@account-vm ~% ls -hla .ssh
    total 16K
    drwx------. 2 hi684 hi684 4.0K Nov 26 16:37 .
    drwx------. 7 hi684 hi684 4.0K Nov 26 16:37 ..
    -rw-------. 1 hi684 hi684 1.8K Nov 26 16:37 id_rsa
    -rw-r--r--. 1 hi684 hi684  398 Nov 26 16:37 id_rsa.pub
    ```

2. 根据需求选择yaml

    每位用户`/home/${USER}`目录下面都存放了一个 lkp-tests 的文件夹。

    ```shell
    hi684@account-vm ~% cd lkp-tests/jobs
    hi684@account-vm ~/lkp-tests/jobs% ls -hl borrow-*
    -rw-r--r--. 1 root root  53 Nov  2 14:54 borrow-10d.yaml
    -rw-r--r--. 1 root root  64 Nov  2 14:54 borrow-1d.yaml
    -rw-r--r--. 1 root root 235 Nov 19 15:27 borrow-1h.yaml
    ```

3. 提交yaml并连接测试机（物理机）

    ```shell
    hi684@account-vm ~/lkp-tests/jobs% submit -c -m testbox=taishan200-2280-2s64p-256g borrow-1h.yaml
    submit borrow-1h.yaml, got job_id=z9.170594
    query=>{"job_id":["z9.170594"]}
    connect to ws://172.168.131.2:11310/filter
    {"job_id":"z9.170594","message":"","job_state":"submit","result_root":"/srv/result/borrow/2020-11-26/taishan200-2280-2s64p-256g/openeuler-20.03-aarch64/3600/z9.170594"}
    {"job_id": "z9.170594", "result_root": "/srv/result/borrow/2020-11-26/taishan200-2280-2s64p-256g/openeuler-20.03-aarch64/3600/z9.170594", "job_state": "set result root"}
    {"job_id": "z9.170594", "job_state": "boot"}
    {"job_id": "z9.170594", "job_state": "download"}
    {"time":"2020-11-26 14:51:56","mac":"84-46-fe-26-d3-47","ip":"172.168.178.48","job_id":"z9.170594","state":"running","testbox":"taishan200-2280-2s64p-256g--a5"}
    {"job_state":"running","job_id":"z9.170594"}
    {"job_id": "z9.170594", "state": "set ssh port", "ssh_port": "50420", "tbox_name": "taishan200-2280-2s64p-256g--a5"}
    Host 172.168.131.2 not found in /home/hi684/.ssh/known_hosts
    Warning: Permanently added '[172.168.131.2]:50420' (ECDSA) to the list of known hosts.
    Last login: Wed Sep 23 11:10:58 2020


    Welcome to 4.19.90-2003.4.0.0036.oe1.aarch64

    System information as of time:  Thu Nov 26 14:51:59 CST 2020

    System load:    1.31
    Processes:      1020
    Memory used:    5.1%
    Swap used:      0.0%
    Usage On:       3%
    IP address:     172.168.178.48
    Users online:   1



    root@taishan200-2280-2s64p-256g--a5 ~#
    ```

    更多关于`submit命令如何使用`、`testbox都有什么可选项`、`如何borrow指定的操作系统`，请参见文章末尾FAQ。

4. 使用完毕退还测试机（物理机）

    ```shell
    root@taishan200-2280-2s64p-256g--a5 ~# reboot
    Connection to 172.168.131.2 closed by remote host.
    Connection to 172.168.131.2 closed.
    hi684@account-vm ~/lkp-tests/jobs%
    ```


# FAQ


* 如何自行修改申请时长

    ```shell
    hi684@account-vm ~/lkp-tests/jobs% cat borrow-1h.yaml
    suite: borrow
    testcase: borrow

    ssh_pub_key: <%=
             begin
               File.read("#{ENV['HOME']}/.ssh/id_rsa.pub").chomp
             rescue
               nil
             end
             %>
    sshd:
    # sleep at the bottom
    sleep: 1h
    hi684@account-vm ~/lkp-tests/jobs% grep sleep: borrow-1h.yaml
    sleep: 1h
    # 使用vim来修改你的sleep字段的值
    hi684@account-vm ~/lkp-tests/jobs% vim borrow-1h.yaml
    # 修改完毕后重新submit即可
    hi684@account-vm ~/lkp-tests/jobs% submit -c -m testbox=vm-2p8g borrow-1h.yaml
    ```

* Submit命令指导

    参考文档：[submit命令详解](https://gitee.com/wu_fengguang/compass-ci/blob/master/doc/manual/submit-job.zh.md)

* testbox有什么可选项

    testbox可选项请参考：https://gitee.com/wu_fengguang/lab-z9/tree/master/hosts

    >![](./../public_sys-resources/icon-note.gif) **说明：**
    >
    > 虚拟机的testbox : vm-xxx
    > 物理机的testbox : taishan200-2280-xxx



    >![](./../public_sys-resources/icon-notice.gif) **注意：**
    > - 物理机的testbox若选择以`--axx`结尾的，则表示指定到了具体的某一个物理机。若此物理机任务队列中已经有任务在排队，则需要等待队列中前面的任务执行完毕后，才会轮到你提交的borrow任务。
    > - 物理机的testbox若不选择以`-axx`结尾的，表示不指定具体的某一个物理机。则此时集群中的空闲物理机会即时被分配执行你的borrow任务。

* 如何 borrow 指定的操作系统

    关于支持的`os`, `os_arch`, `os_version`，参见：[os-os_verison-os_arch.md](https://gitee.com/wu_fengguang/compass-ci/blob/master/doc/job/os-os_verison-os_arch.md)