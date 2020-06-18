require  "./resources"
require "../redis_client"
require "../elasticsearch_client"

module Scheduler
    module Monitor
        def self.update_job_parameter(job_content, env : HTTP::Server::Context, resources : Scheduler::Resources)
            resources.@redis_client.not_nil!.add_job_content(job_content)
        end

        def self.update_job_when_finished(job_id : String, resources : Scheduler::Resources)
            es = resources.@es_client.not_nil!
            redis = resources.@redis_client.not_nil!
            job_result = redis.@client.hget("sched/id2job", job_id)
            if job_result != nil
                job_result = JSON.parse(job_result.not_nil!)
                respon = es.set_job_content(job_result)
                if respon["_id"] == nil
                    # es update fail, raise exception
                    raise "es set job content fail! "
                end
            end
            redis.remove_finished_job(job_id)
        end
    end
end
