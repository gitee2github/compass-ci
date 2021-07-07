# SPDX-License-Identifier: MulanPSL-2.0+
# Copyright (c) 2020 Huawei Technologies Co., Ltd. All rights reserved.

class Sched
  def update_job_parameter
    job_id = @env.params.query["job_id"]?
    return false unless job_id

    job = @es.get_job(job_id)
    return false unless job

    @env.set "job_id", job_id
    @env.set "time", get_time

    # try to get report value and then update it
    job_content = {} of String => String

    (%w(start_time end_time loadavg job_state)).each do |parameter|
      value = @env.params.query[parameter]?
      next if value.nil? || value == ""

      if parameter == "start_time" || parameter == "end_time"
        value = Time.unix(value.to_i).to_local.to_s("%Y-%m-%d %H:%M:%S")
      end

      job_content[parameter] = value
      next unless parameter == "job_state"

      if JOB_STAGES.includes?(value)
        job_content["job_stage"] = value
        job["last_success_stage"] = value
        @env.set "job_stage", value
        @env.set "deadline", job.set_deadline(value).to_s
      else
        value = "success" if value == "finished"
        job_content["job_health"] = value
      end
    end

    job.update(job_content)
    job_content["id"] = job_id

    update_id2job(job_content)

    # json log
    log = job_content.dup
    log["job_id"] = log.delete("id").not_nil!

    @env.set "log", log.to_json

    @es.set_job_content(job)
    update_testbox_info(job)
  rescue e
    @env.response.status_code = 500
    @log.warn({
      "message" => e.to_s,
      "error_message" => e.inspect_with_backtrace.to_s
    }.to_json)
  ensure
    send_mq_msg
  end

  def update_testbox_info(job)
    testbox = job["testbox"]
    deadline = @env.get?("deadline")

    hash = {"time" => @env.get?("time").to_s}
    hash["deadline"] = deadline.to_s if deadline

    @es.update_tbox(testbox, hash)
  end
end
