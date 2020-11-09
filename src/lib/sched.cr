# SPDX-License-Identifier: MulanPSL-2.0+
# Copyright (c) 2020 Huawei Technologies Co., Ltd. All rights reserved.

require "kemal"
require "yaml"

require "./job"
require "./block_helper"
require "./taskqueue_api"
require "./remote_git_client"
require "../scheduler/constants"
require "../scheduler/jobfile_operate"
require "../scheduler/redis_client"
require "../scheduler/elasticsearch_client"

class Sched
  property es
  property redis
  property block_helper

  def initialize
    @es = Elasticsearch::Client.new
    @redis = Redis::Client.new
    @task_queue = TaskQueueAPI.new
    @block_helper = BlockHelper.new
    @rgc = RemoteGitClient.new
  end

  def normalize_mac(mac : String)
    mac.gsub(":", "-")
  end

  def set_host_mac(mac : String, hostname : String)
    @redis.hash_set("sched/mac2host", normalize_mac(mac), hostname)
  end

  def del_host_mac(mac : String)
    @redis.hash_del("sched/mac2host", normalize_mac(mac))
  end

  def set_host2queues(hostname : String, queues : String)
    @redis.hash_set("sched/host2queues", hostname, queues)
  end

  def del_host2queues(hostname : String)
    @redis.hash_del("sched/host2queues", hostname)
  end

  # return:
  #     Hash(String, Hash(String, String))
  def get_cluster_state(cluster_id)
    cluster_state = @redis.hash_get("sched/cluster_state", cluster_id)
    if cluster_state
      cluster_state = Hash(String, Hash(String, String)).from_json(cluster_state)
    else
      cluster_state = Hash(String, Hash(String, String)).new
    end
    return cluster_state
  end

  # Update job info according to cluster id.
  def update_cluster_state(cluster_id, job_id, job_info : Hash(String, String))
    cluster_state = get_cluster_state(cluster_id)
    if cluster_state[job_id]?
      cluster_state[job_id].merge!(job_info)
      @redis.hash_set("sched/cluster_state", cluster_id, cluster_state.to_json)
    end
  end

  # Return response according to different request states.
  # all request states:
  #     wait_ready | abort | failed | finished | wait_finish |
  #     write_state | roles_ip
  def request_cluster_state(env)
    request_state = env.params.query["state"]
    job_id = env.params.query["job_id"]
    cluster_id = @redis.hash_get("sched/id2cluster", job_id).not_nil!
    cluster_state = ""

    states = {"abort"       => "abort",
              "finished"    => "finish",
              "failed"      => "abort",
              "wait_ready"  => "ready",
              "wait_finish" => "finish"}

    case request_state
    when "abort", "finished", "failed"
      # update node state only
      update_cluster_state(cluster_id, job_id, {"state" => states[request_state]})
    when "wait_ready"
      update_cluster_state(cluster_id, job_id, {"state" => states[request_state]})
      @block_helper.block_until_finished(cluster_id) {
        cluster_state = sync_cluster_state(cluster_id, job_id, states[request_state])
        cluster_state == "ready" || cluster_state == "abort"
      }

      return cluster_state
    when "wait_finish"
      update_cluster_state(cluster_id, job_id, {"state" => states[request_state]})
      while 1
        sleep(10)
        cluster_state = sync_cluster_state(cluster_id, job_id, states[request_state])
        break if (cluster_state == "finish" || cluster_state == "abort")
      end

      return cluster_state
    when "write_state"
      node_roles = env.params.query["node_roles"]
      node_ip = env.params.query["ip"]
      direct_ips = env.params.query["direct_ips"]
      direct_macs = env.params.query["direct_macs"]

      job_info = {"roles"       => node_roles,
                  "ip"          => node_ip,
                  "direct_ips"  => direct_ips,
                  "direct_macs" => direct_macs}
      update_cluster_state(cluster_id, job_id, job_info)
    when "roles_ip"
      role = "server"
      role_state = get_role_state(cluster_id, role)
      raise "Missing #{role} state in cluster state" unless role_state
      return "server=#{role_state["ip"]}\n" \
             "direct_server_ips=#{role_state["direct_ips"]}"
    end

    # show cluster state
    return @redis.hash_get("sched/cluster_state", cluster_id)
  end

  # get the node state of role from cluster_state
  private def get_role_state(cluster_id, role)
    cluster_state = get_cluster_state(cluster_id)
    cluster_state.each_value do |role_state|
      return role_state if role_state["roles"] == role
    end
  end

  # node_state: "finish" | "ready"
  def sync_cluster_state(cluster_id, job_id, node_state)
    cluster_state = get_cluster_state(cluster_id)
    cluster_state.each_value do |host_state|
      state = host_state["state"]
      return "abort" if state == "abort"
    end

    cluster_state.each_value do |host_state|
      state = host_state["state"]
      next if "#{state}" == "#{node_state}"
      return "retry"
    end

    # cluster state is node state when all nodes are normal
    return node_state
  end

  # get cluster config using own lkp_src cluster file,
  # a hash type will be returned
  def get_cluster_config(cluster_file, lkp_initrd_user, os_arch)
    lkp_src = Jobfile::Operate.prepare_lkp_tests(lkp_initrd_user, os_arch)
    cluster_file_path = Path.new(lkp_src, "cluster", cluster_file)
    return YAML.parse(File.read(cluster_file_path))
  end

  def get_commit_date(job)
    if (job["upstream_repo"] != "") && (job["upstream_commit"] != "")
      data = JSON.parse(%({"git_repo": "#{job["upstream_repo"]}.git",
                   "git_command": ["git-log", "--pretty=format:%cd", "--date=unix",
                   "#{job["upstream_commit"]}", "-1"]}))
      response = @rgc.git_command(data)
      return response.body if response.status_code == 200
    end

    return nil
  end

  def submit_job(env : HTTP::Server::Context)
    body = env.request.body.not_nil!.gets_to_end

    job_content = JSON.parse(body)
    job = Job.new(job_content, job_content["id"]?)
    job["commit_date"] = get_commit_date(job)

    # it is not a cluster job if cluster field is empty or
    # field's prefix is 'cs-localhost'
    cluster_file = job["cluster"]
    if cluster_file.empty? || cluster_file.starts_with?("cs-localhost")
      return submit_single_job(job)
    else
      cluster_config = get_cluster_config(cluster_file,
        job.lkp_initrd_user,
        job.os_arch)
      return submit_cluster_job(job, cluster_config)
    end
  rescue ex
    puts ex.inspect_with_backtrace
    return [{
      "job_id"    => "0",
      "message"   => ex.to_s,
      "job_state" => "submit",
    }]
  end

  # return:
  #   success: [{"job_id" => job_id1, "message => "", "job_state" => "submit"}, ...]
  #   failure: [..., {"job_id" => 0, "message" => err_msg, "job_state" => "submit"}]
  def submit_cluster_job(job, cluster_config)
    job_messages = Array(Hash(String, String)).new
    lab = job.lab

    # collect all job ids
    job_ids = [] of String

    net_id = "192.168.222"
    ip0 = cluster_config["ip0"]?
    if ip0
      ip0 = ip0.as_i
    else
      ip0 = 1
    end

    # steps for each host
    cluster_config["nodes"].as_h.each do |host, config|
      tbox_group = host.to_s
      job_id = add_task(tbox_group, lab)

      # return when job_id is '0'
      # 2 Questions:
      #   - how to deal with the jobs added to DB prior to this loop
      #   - may consume job before all jobs done
      return job_messages << {
        "job_id"    => "0",
        "message"   => "add task queue sched/#{tbox_group} failed",
        "job_state" => "submit",
      } unless job_id

      job_ids << job_id

      # add to job content when multi-test
      job["testbox"] = tbox_group
      job.update_tbox_group(tbox_group)
      job["node_roles"] = config["roles"].as_a.join(" ")
      direct_macs = config["macs"].as_a
      direct_ips = [] of String
      direct_macs.size.times do
        raise "Host id is greater than 254, host_id: #{ip0}" if ip0 > 254
        direct_ips << "#{net_id}.#{ip0}"
        ip0 += 1
      end
      job["direct_macs"] = direct_macs.join(" ")
      job["direct_ips"] = direct_ips.join(" ")

      response = add_job(job, job_id)
      message = (response["error"]? ? response["error"]["root_cause"] : "")
      job_messages << {
        "job_id"      => job_id,
        "message"     => message.to_s,
        "job_state"   => "submit",
        "result_root" => "/srv#{job.result_root}",
      }
      return job_messages if response["error"]?
    end

    cluster_id = job_ids[0]

    # collect all host states
    cluster_state = Hash(String, Hash(String, String)).new
    job_ids.each do |job_id|
      cluster_state[job_id] = {"state" => ""}
      # will get cluster id according to job id
      @redis.hash_set("sched/id2cluster", job_id, cluster_id)
    end

    @redis.hash_set("sched/cluster_state", cluster_id, cluster_state.to_json)

    return job_messages
  end

  # return:
  #   success: [{"job_id" => job_id, "message" => "", job_state => "submit"}]
  #   failure: [{"job_id" => "0", "message" => err_msg, job_state => "submit"}]
  def submit_single_job(job)
    queue = job.queue
    return [{
      "job_id"    => "0",
      "message"   => "get queue failed",
      "job_state" => "submit",
    }] unless queue

    # only single job will has "idle job" and "execute rate limiter"
    if job["idle_job"].empty?
      queue += "#{job.get_uuid_tag}"
    else
      queue = "#{queue}/idle"
    end

    job_id = add_task(queue, job.lab)
    return [{
      "job_id"    => "0",
      "message"   => "add task queue sched/#{queue} failed",
      "job_state" => "submit",
    }] unless job_id

    response = add_job(job, job_id)
    message = (response["error"]? ? response["error"]["root_cause"] : "")

    return [{
      "job_id"      => job_id,
      "message"     => message.to_s,
      "job_state"   => "submit",
      "result_root" => "/srv#{job.result_root}",
    }]
  end

  # return job_id
  def add_task(queue, lab)
    task_desc = JSON.parse(%({"domain": "compass-ci", "lab": "#{lab}"}))
    response = @task_queue.add_task("sched/#{queue}", task_desc)
    JSON.parse(response[1].to_json)["id"].to_s if response[0] == 200
  end

  # add job content to es and return a response
  def add_job(job, job_id)
    job.update_id(job_id)
    @es.set_job_content(job)
  end

  private def ipxe_msg(msg)
    "#!ipxe
        echo ...
        echo #{msg}
        echo ...
        reboot"
  end

  private def grub_msg(msg)
    "#!grub
        echo ...
        echo #{msg}
        echo ...
        reboot"
  end

  private def get_boot_container(job : Job)
    response = Hash(String, String).new
    response["docker_image"] = "#{job.docker_image}"
    response["lkp"] = "http://#{INITRD_HTTP_HOST}:#{INITRD_HTTP_PORT}" +
                      JobHelper.service_path("#{SRV_INITRD}/lkp/#{job.lkp_initrd_user}/lkp-#{job.arch}.cgz")
    response["job"] = "http://#{SCHED_HOST}:#{SCHED_PORT}/job_initrd_tmpfs/#{job.id}/job.cgz"

    return response.to_json
  end

  private def get_boot_grub(job : Job)
    initrd_lkp_cgz = "lkp-#{job.os_arch}.cgz"

    response = "#!grub\n\n"
    response += "linux (http,#{OS_HTTP_HOST}:#{OS_HTTP_PORT})"
    response += "#{JobHelper.service_path("#{SRV_OS}/#{job.os_dir}/vmlinuz")} user=lkp"
    response += " job=/lkp/scheduled/job.yaml RESULT_ROOT=/result/job"
    response += " rootovl ip=dhcp ro root=#{job.kernel_append_root}\n"

    response += "initrd (http,#{OS_HTTP_HOST}:#{OS_HTTP_PORT})"
    response += JobHelper.service_path("#{SRV_OS}/#{job.os_dir}/initrd.lkp")
    response += " (http,#{INITRD_HTTP_HOST}:#{INITRD_HTTP_PORT})"
    response += JobHelper.service_path("#{SRV_INITRD}/lkp/#{job.lkp_initrd_user}/#{initrd_lkp_cgz}")
    response += " (http,#{SCHED_HOST}:#{SCHED_PORT})/job_initrd_tmpfs/"
    response += "#{job.id}/job.cgz\n"

    response += "boot\n"

    return response
  end

  def touch_access_key_file(job : Job)
    FileUtils.touch(job.access_key_file)
  end

  def boot_content(job : Job | Nil, boot_type : String)
    touch_access_key_file(job) if job

    case boot_type
    when "ipxe"
      return job ? get_boot_ipxe(job) : ipxe_msg("No job now")
    when "grub"
      return job ? get_boot_grub(job) : grub_msg("No job now")
    when "container"
      return job ? get_boot_container(job) : Hash(String, String).new.to_json
    else
      raise "Not defined boot type #{boot_type}"
    end
  end

  def rand_queues(queues)
    return queues if queues.empty?

    queues_size = queues.size
    base = Random.rand(queues_size)
    temp_queues = [] of String

    (0..queues_size - 1).each do |index|
      temp_queues << queues[(index + base) % queues_size]
    end

    return temp_queues
  end

  def get_queues(host)
    queues = [] of String

    queues_str = @redis.hash_get("sched/host2queues", host)
    return queues unless queues_str

    queues_str.split(',', remove_empty: true) do |item|
      queues << item.strip
    end

    return rand_queues(queues)
  end

  def get_job_from_queues(queues, testbox)
    job = nil

    queues.each do |queue|
      job = prepare_job("sched/#{queue}", testbox)
      return job if job
    end

    return job
  end

  def get_job_boot(host, boot_type)
    queues = get_queues(host)
    job = get_job_from_queues(queues, host)

    if job
      Jobfile::Operate.create_job_cpio(job.dump_to_json_any, Kemal.config.public_folder)
    end

    return boot_content(job, boot_type)
  end

  # auto submit a job to collect the host information
  # grub hostname is link with ":", like "00:01:02:03:04:05"
  # remind: if like with "-", last "-05" is treated as host number
  #   then hostname will be "sut-00-01-02-03-04" !!!
  def submit_host_info_job(mac)
    host = "sut-#{mac}"
    set_host_mac(mac, host)

    Jobfile::Operate.auto_submit_job(
      "#{ENV["LKP_SRC"]}/jobs/host-info.yaml",
      "testbox: #{host}")
  end

  def find_job_boot(env : HTTP::Server::Context)
    value = env.params.url["value"]
    boot_type = env.params.url["boot_type"]

    case boot_type
    when "ipxe"
      host = @redis.hash_get("sched/mac2host", normalize_mac(value))
    when "grub"
      host = @redis.hash_get("sched/mac2host", normalize_mac(value))
      submit_host_info_job(value) unless host
    when "container"
      host = value
    end

    get_job_boot(host, boot_type)
  end

  def find_next_job_boot(env)
    hostname = env.params.query["hostname"]?
    mac = env.params.query["mac"]?
    if !hostname && mac
      hostname = @redis.hash_get("sched/mac2host", normalize_mac(mac))
    end

    get_job_boot(hostname, "ipxe")
  end

  def get_testbox_boot_content(testbox, boot_type)
    job = find_job(testbox) if testbox
    Jobfile::Operate.create_job_cpio(job.dump_to_json_any,
      Kemal.config.public_folder) if job

    return boot_content(job, boot_type)
  end

  private def find_job(testbox : String, count = 1)
    tbox_group = JobHelper.match_tbox_group(testbox)
    tbox = tbox_group.partition("--")[0]

    queue_list = query_consumable_keys(tbox)

    boxes = ["sched/" + testbox,
             "sched/" + tbox_group,
             "sched/" + tbox,
             "sched/" + tbox_group + "/idle"]
    boxes.each do |box|
      next if queue_list.select(box).size == 0
      count.times do
        job = prepare_job(box, testbox)
        return job if job

        sleep(1) unless count == 1
      end
    end

    # when find no job, auto submit idle job at background
    spawn { auto_submit_idle_job(tbox_group) }

    return nil
  end

  private def prepare_job(queue_name, testbox)
    response = @task_queue.consume_task(queue_name)
    job_id = JSON.parse(response[1].to_json)["id"] if response[0] == 200
    job = nil

    if job_id
      begin
        job = @es.get_job(job_id.to_s)
      rescue ex
        puts "Invalid job (id=#{job_id}) in es. Info: #{ex}"
        puts ex.inspect_with_backtrace
      end
    end

    if job
      job.update({"testbox" => testbox})
      job.set_result_root
      puts %({"job_id": "#{job_id}", "result_root": "/srv#{job.result_root}", "job_state": "set result root"})
      @redis.set_job(job)
    end
    return job
  end

  private def get_idle_job(tbox_group, testbox)
    job = prepare_job("sched/#{tbox_group}/idle", testbox)

    # if there has no idle job, auto submit and get 1
    if job.nil?
      auto_submit_idle_job(tbox_group)
      job = prepare_job("sched/#{tbox_group}/idle", testbox)
    end

    return job
  end

  def auto_submit_idle_job(tbox_group)
    full_path_patterns = "#{ENV["CCI_REPOS"]}/lab-#{ENV["lab"]}/allot/idle/#{tbox_group}/*.yaml"
    extra_job_fields = [
      "idle_job=true",
      "MASTER_FLUENTD_HOST=#{ENV["MASTER_FLUENTD_HOST"]}",
      "MASTER_FLUENTD_PORT=#{ENV["MASTER_FLUENTD_PORT"]}",
    ]

    Jobfile::Operate.auto_submit_job(
      full_path_patterns,
      "testbox: #{tbox_group}",
      extra_job_fields) if Dir.glob(full_path_patterns).size > 0
  end

  private def get_boot_ipxe(job : Job)
    response = "#!ipxe\n\n"
    response += job.initrds_uri
    response += job.kernel_uri
    response += job.kernel_params
    response += "\nboot\n"

    return response
  end

  def update_job_parameter(env : HTTP::Server::Context)
    job_id = env.params.query["job_id"]?
    if !job_id
      return false
    end

    # try to get report value and then update it
    job_content = {} of String => String
    job_content["id"] = job_id

    (%w(start_time end_time loadavg job_state)).each do |parameter|
      value = env.params.query[parameter]?
      if !value || value == ""
        next
      end
      if parameter == "start_time" || parameter == "end_time"
        value = Time.unix(value.to_i).to_local.to_s("%Y-%m-%d %H:%M:%S")
      end

      job_content[parameter] = value
    end

    @redis.update_job(job_content)

    # json log
    log = job_content.dup
    log["job_id"] = log.delete("id").not_nil!
    return log.to_json
  end

  def update_tbox_wtmp(env : HTTP::Server::Context)
    testbox = ""
    hash = Hash(String, String).new

    time = Time.local.to_s("%Y-%m-%d %H:%M:%S")
    hash["time"] = time

    %w(mac ip job_id tbox_name tbox_state).each do |parameter|
      if (value = env.params.query[parameter]?)
        case parameter
        when "tbox_name"
          testbox = value
        when "tbox_state"
          hash["state"] = value
        when "mac"
          hash["mac"] = normalize_mac(value)
        else
          hash[parameter] = value
        end
      end
    end

    @redis.update_wtmp(testbox, hash)

    # json log
    hash["testbox"] = testbox
    return hash.to_json
  end

  def report_ssh_port(testbox : String, ssh_port : String)
    @redis.hash_set("sched/tbox2ssh_port", testbox, ssh_port)
  end

  def delete_access_key_file(job : Job)
    File.delete(job.access_key_file) if File.exists?(job.access_key_file)
  end

  def close_job(job_id : String)
    job = @redis.get_job(job_id)

    delete_access_key_file(job) if job

    response = @es.set_job_content(job)
    if response["_id"] == nil
      # es update fail, raise exception
      raise "es set job content fail!"
    end

    response = @task_queue.hand_over_task(
      "sched/#{job.queue}", "extract_stats", job_id
    )
    if response[0] != 201
      raise "#{response}"
    end

    @redis.remove_finished_job(job_id)

    return %({"job_id": "#{job_id}", "job_state": "complete"})
  end

  private def query_consumable_keys(shortest_queue_name)
    keys = [] of String
    search = "sched/" + shortest_queue_name + "*"
    response = @task_queue.query_keys(search)

    return keys unless response[0] == 200

    key_list = JSON.parse(response[1].to_json).as_a

    # add consumable keys
    key_list.each do |key|
      queue_name = consumable_key?("#{key}")
      keys << queue_name if queue_name
    end

    return keys
  end

  private def consumable_key?(key_name)
    if key_name =~ /(.*)\/(.*)$/
      case $2
      when "in_process"
        return nil
      when "ready"
        return $1
      when "idle"
        return key_name
      else
        return key_name
      end
    end

    return nil
  end
end
