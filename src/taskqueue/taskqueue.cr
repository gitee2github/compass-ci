require "kemal"

require "./constants"
require "./queue"

class TaskQueue
  VERSION = "0.0.1"

  def debug_message(env, response)
    puts ">> #{env.request.remote_address}"
    puts "<< #{response}"
    puts ""
  end

  def run()

    # -------------------
    # request: curl http://localhost:3060
    #
    # response: TaskQueue@v0.0.1 is alive.
    get "/" do |env|
      response = "TaskQueue@v#{VERSION} is alive."
      debug_message(env, response)

      "#{response.to_json}\n"
    end

    # -------------------
    # request: curl -X POST http://localhost:3060/add?queue=scheduler/$tbox_group
    #               -H "Content-Type: application/json"
    #               --data '{"suite":"test01", "tbox_group":"host"}'
    #          |    --data '{"suite":"test01", "id":$id, "tbox_group":"host"}'
    #
    # response: 200 {id: 1}.to_json
    #           409 "Queue <scheduler/host> already has id <$id>"
    #           409 "Add with error id <65536>"
    #           400 "Missing parameter <queue>"
    #           400 "Missing http body"
    post "/add" do |env|
      response = queue_respond_add(env)
      debug_message(env, response)
      if env.response.status_code == 200
        response
      end
    end

    # -------------------
    # request: curl -X PUT http://localhost:3060/consume?queue=scheduler/$tbox_group
    #
    # response: 200 {"suite":"test01", "tbox_group":"host", "id":1}.to_json
    #           201 ## when there has no task in queue (scheduler/$tbox_group)
    #           400 "Missing parameter <queue>"
    put "/consume" do |env|
      response = queue_respond_consume(env)
      debug_message(env, response)
      if env.response.status_code == 200
        response
      end
    end

    # -------------------
    # request: curl -X PUT http://localhost:3060/hand_over?
    #          from=scheduler/$tbox_group&to=extract_stats&id=$id
    #
    # response: 201 ## when succeed hand over
    #           400 "Missing parameter <from|to|id>"
    #           409 "Can not find id <$id> in queue <scheduler/$tbox_group>"
    put "/hand_over" do |env|
      response = queue_respond_hand_over(env)
      debug_message(env, response)
    end

    # -------------------
    # request: curl -X PUT http://localhost:3060/delete?
    #          from=scheduler/$tbox_group&id=$id
    #
    # response: 201 ## when succeed delete
    #           400 "Missing parameter <queue|id>"
    #           409 "Can not find id <$id> in queue <scheduler/$tbox_group>"
    put "/delete" do |env|
      response = queue_respond_delete(env)
      debug_message(env, response)
    end

    @port = (ENV.has_key?("TASKQUEUE_PORT") ? ENV["TASKQUEUE_PORT"].to_i32 : TASKQUEUE_PORT)
    Kemal.run(@port)
  end
end
