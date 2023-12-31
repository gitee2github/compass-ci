# SPDX-License-Identifier: MulanPSL-2.0+
# Copyright (c) 2020 Huawei Technologies Co., Ltd. All rights reserved.
# frozen_string_literal: true

require 'yaml'

require_relative "#{ENV['CCI_SRC']}/lib/es_query"

def get_job_yaml(job_id)
  content = ESQuery.new.query_by_id(job_id)
  result_root = content['result_root']
  return YAML.load_file(File.join('/srv', result_root.to_s, 'job.yaml'))
end
