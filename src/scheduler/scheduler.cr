# SPDX-License-Identifier: MulanPSL-2.0+
# Copyright (c) 2020 Huawei Technologies Co., Ltd. All rights reserved.

require "kemal"

require "../lib/env"
require "../lib/sched"
require "../lib/json_logger"

# -------------------------------------------------------------------------------------------
# end_user:
# - restful API [post "/submit_job"] to submit a job to scheduler
# -- json formated [job] in the request data
#
# -------------------------------------------------------------------------------------------
# runner:
# - restful API [get "/boot.ipxe/mac/52-54-00-12-34-56"] to get a job for ipxe qemu-runner
#  -- when find then return <#!ipxe and job.cgz kernal initrd>
#  -- when no job return <#!ipxe no job messages>
#
# - restful API [put "/set_host_mac?hostname=myhostname&mac=ff-ff-ff-ff-ff-ff"] to report testbox's {mac => hostname}
# - restful API [get "/job_initrd_tmpfs/11/job.cgz"] to download job(11) job.cgz file
# - restful API [get "/~lkp/cgi-bin/lkp-jobfile-append-var"] report job var that should be append
# - restful API [get "/~lkp/cgi-bin/lkp-cluster-sync"] for nodes to request cluster state
# - restful API [get "/~lkp/cgi-bin/lkp-post-run" ] to move job from redis queue "sched/jobs_running" to "sched/extract_stats" and remove job from redis queue "sched/id2job"
#
# -------------------------------------------------------------------------------------------
# scheduler:
# - use [redis incr] as job_id, a 64bit int number
# - restful API [get "/"] default echo
#
module Scheduler
  VERSION = "0.2.0"

  add_context_storage_type(Time::Span)

  before_all do |env|
    env.set "start_time", Time.monotonic
    env.response.headers["Connection"] = "close"
    env.create_log
    env.create_sched
  end

  # for debug (maybe kemal debug|logger does better)
  def self.debug_message(env, response)
    env.log.info(%({"from": "#{env.request.remote_address}", "response": #{response.to_json}}))
  end

  # echo alive
  get "/" do |env|
    debug_message(env, "Env= {\n#{`export`}}")
    "LKP Alive! The time is #{Time.local}, version = #{VERSION}"
  end

  # for XXX_runner get job
  #
  # /boot.ipxe/mac/${mac}
  # /boot.xxx/host/${hostname}
  # /boot.yyy/mac/${mac}
  get "/boot.:boot_type/:parameter/:value" do |env|
    response = env.sched.find_job_boot

    job_id = response[/tmpfs\/(.*)\/job\.cgz/, 1]?
    env.log.info(%({"job_id": "#{job_id}", "job_state": "boot"})) if job_id

    response
  end

  # /~lkp/cgi-bin/gpxelinux.cgi?hostname=:hostname&mac=:mac&last_kernel=:last_kernel
  get "/~lkp/cgi-bin/gpxelinux.cgi" do |env|
    response = env.sched.find_next_job_boot

    job_id = response[/tmpfs\/(.*)\/job\.cgz/, 1]?
    env.log.info(%({"job_id": "#{job_id}", "job_state": "boot"})) if job_id

    response
  end

  # enqueue
  #  - echo job_id to caller
  #  -- job_id = "0" ? means failed
  post "/submit_job" do |env|
    job_messages = env.sched.submit_job

    job_messages.each do |job_message|
      env.log.info(job_message.to_json)
    end

    job_messages.to_json
  end

  # file download server
  get "/job_initrd_tmpfs/:job_id/:job_package" do |env|
    job_id = env.params.url["job_id"]
    job_package = env.params.url["job_package"]
    file_path = ::File.join [Kemal.config.public_folder, job_id, job_package]

    env.log.info(%({"job_id": "#{job_id}", "job_state": "download"}))

    send_file env, file_path
  end

  # client(runner) report its hostname and mac
  #  - when a runner pull jobs with it's mac infor, scheduler find out what hostname is it
  # /set_host_mac?hostname=$hostname&mac=$mac (mac like ef-01-02-03-04-05)
  # add a <mac> => <hostname>
  #
  # curl -X PUT "http://localhost:3000/set_host_mac?hostname=wfg&mac=00-01-02-03-04-05"
  put "/set_host_mac" do |env|
    if (client_hostname = env.params.query["hostname"]?) && (client_mac = env.params.query["mac"]?)
      env.sched.set_host_mac(client_mac, client_hostname)

      "Done"
    else
      "No yet!"
    end
  end

  # curl -X PUT "http://localhost:3000/set_host2queues?queues=vm-2p8g.aarch64&host=vm-2p8g.aarch64"
  put "/set_host2queues" do |env|
    if (client_queues = env.params.query["queues"]?) && (client_host = env.params.query["host"]?)
      env.sched.set_host2queues(client_host, client_queues)

      "Done"
    else
      "No yet"
    end
  end

  # curl -X PUT "http://localhost:3000/del_host_mac?mac=00-01-02-03-04-05"
  put "/del_host_mac" do |env|
    if client_mac = env.params.query["mac"]?
      env.sched.del_host_mac(client_mac)

      "Done"
    else
      "No yet!"
    end
  end

  # curl -X PUT "http://localhost:3000/del_host2queues?host=vm-2p8g.aarch64"
  put "/del_host2queues" do |env|
    if client_host = env.params.query["host"]?
      env.sched.del_host2queues(client_host)

      "Done"
    else
      "No yet!"
    end
  end

  # client(runner) report job's status
  # /~lkp/cgi-bin/lkp-jobfile-append-var
  #  ?job_file=/lkp/scheduled/job.yaml&job_state=running&job_id=10
  #  ?job_file=/lkp/scheduled/job.yaml&job_state=post_run&job_id=10
  #  ?job_file=/lkp/scheduled/job.yaml&loadavg=0.28 0.82 0.49 1/105 3389&start_time=1587725398&end_time=1587725698&job_id=10
  get "/~lkp/cgi-bin/lkp-jobfile-append-var" do |env|
    env.log.info(env.sched.update_job_parameter)

    "Done"
  end

  # node in cluster requests cluster state
  # wget 'http://localhost:3000/~lkp/cgi-bin/lkp-cluster-sync?job_id=<job_id>&state=<state>'
  # 1) state   : "wait_ready"
  #    response: return "abort" if one node state is "abort",
  #              "ready" if all nodes are "ready", "retry" otherwise.
  # 2) state   : wait_finish
  #    response: return "abort" if one node state is "abort",
  #              "finish" if all nodes are "finish", "retry" otherwise.
  # 3) state   : abort | failed
  #    response: update the node state to "abort",
  #              return all nodes states at this moment.
  # 4) state   : write_state
  #    response: add "roles" and "ip" fields to cluster state,
  #              return all nodes states at this moment.
  # 5) state   : roles_ip
  #    response: get "server ip" from cluster state,
  #              return "server=<server ip>".
  get "/~lkp/cgi-bin/lkp-cluster-sync" do |env|
    response = env.sched.request_cluster_state

    debug_message(env, response)

    response
  end

  # client(runner) report job post_run finished
  # /~lkp/cgi-bin/lkp-post-run?job_file=/lkp/scheduled/job.yaml&job_id=40
  #  curl "http://localhost:3000/~lkp/cgi-bin/lkp-post-run?job_file=/lkp/scheduled/job.yaml&job_id=40"
  get "/~lkp/cgi-bin/lkp-post-run" do |env|
    # get job_id from request
    job_id = env.params.query["job_id"]?
    if job_id
      env.log.info(env.sched.close_job(job_id))
    end

    "Done"
  end

  get "/~lkp/cgi-bin/lkp-wtmp" do |env|
    env.log.info(env.sched.update_tbox_wtmp)

    "Done"
  end

  get "/~lkp/cgi-bin/report_ssh_port" do |env|
    testbox = env.params.query["tbox_name"]
    ssh_port = env.params.query["ssh_port"].to_s
    job_id = env.params.query["job_id"].to_s

    if testbox && ssh_port
      env.sched.report_ssh_port(testbox, ssh_port)
    end

    env.log.info(%({"job_id": "#{job_id}", "state": "set ssh port", "ssh_port": "#{ssh_port}", "tbox_name": "#{testbox}"}))

    "Done"
  end
end
