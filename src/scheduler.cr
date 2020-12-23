# SPDX-License-Identifier: MulanPSL-2.0+
# Copyright (c) 2020 Huawei Technologies Co., Ltd. All rights reserved.

require "scheduler/scheduler"
require "./scheduler/constants.cr"
require "./lib/json_logger"

module Scheduler
  log = JSONLogger.new

  begin
    Kemal.run(SCHED_PORT)
  rescue e
    log.error(e)
  end
end
