# frozen_string_literal: true

require 'json'
require 'yaml'
require 'set'

CCI_SRC = ENV['CCI_SRC'] || '/c/compass-ci'

require "#{CCI_SRC}/lib/compare.rb"
require "#{CCI_SRC}/lib/constants.rb"
require "#{CCI_SRC}/lib/es_query.rb"
require "#{CCI_SRC}/lib/matrix2.rb"

UPSTREAM_REPOS_PATH = ENV['UPSTREAM_REPOS_PATH'] || '/c/upstream-repos'

FIELDS = %w[
  upstream_repo
  os
  os_version
  os_arch
  start_time
  suite
  category
  testbox
  job_state
  id
  error_ids
].freeze
NOT_SHOW_FIELDS = %w[result_root].freeze
ALL_FIELDS = FIELDS + NOT_SHOW_FIELDS
NOT_NEED_EXIST_FIELDS = %w[error_ids upstream_repo].freeze
PREFIX_SEARCH_FIELDS = ['tbox_group'].freeze
ES_CLIENT = Elasticsearch::Client.new(url: "http://#{ES_HOST}:#{ES_PORT}")
COMPARE_RECORDS_NUMBER = 50

def es_query(query)
  ES_CLIENT.search index: 'jobs*', body: query
end

def es_count(query)
  ES_CLIENT.count(index: 'jobs*', body: query)['count']
end

# "vm-2p8g--212" remove "--212"
# "vm-2p8g--zzz" remove "--zzz"
# "vm-git-bisect" don't remove "-bisect"
def filter_tbox_group(es_result)
  result = Set.new
  es_result.each do |r|
    if r =~ /(^.+--.+$)|(^vm-.*-\d\w*-([a-zA-Z]+)|(\d+)$)/
      index = r.index('--') || r.rindex('-')
      r = r[0, index]
    end
    result.add r
  end
  result.to_a
end

def all_suite
  query = {
    aggs: {
      all_suite: {
        terms: { field: 'suite', size: 1000 }
      }
    },
    size: 0
  }
  es_result = es_query(query)['aggregations']['all_suite']['buckets']
  es_result.sort_by! { |h| h['doc_count'] }
  es_result.reverse!.map! { |x|	x['key'] }

  es_result
end

def all_tbox_group
  query = {
    aggs: {
      all_tbox_group: {
        terms: { field: 'tbox_group', size: 1000 }
      }
    },
    size: 0
  }
  es_result = es_query(query)['aggregations']['all_tbox_group']['buckets']
  es_result.sort_by! { |h| h['doc_count'] }
  es_result.reverse!.map! { |x|	x['key'] }

  filter_tbox_group(es_result)
end

def compare_candidates_body
  body = {
    query_conditions: {
      suite: all_suite,
      OS: [
        { os: 'openeuler', os_version: ['1.0', '20.03'] },
        { os: 'centos', os_version: ['7.6', '7.8', '8.1', 'sid'] },
        { os: 'debian', os_version: %w[10 sid] },
        { os: 'archlinux', os_version: ['5.5.0-1'] }
      ],
      os_arch: %w[aarch64 x86_64],
      tbox_group: all_tbox_group
    },
    dimension: %w[os os_version os_arch suite tbox_group]
  }
  JSON.dump body
end

def compare_candidates
  begin
    body = compare_candidates_body
  rescue StandardError => e
    warn e.message
    return [500, headers.merge('Access-Control-Allow-Origin' => '*'), 'get compare candidates error']
  end
  [200, headers.merge('Access-Control-Allow-Origin' => '*'), body]
end

def get_dimension_conditions(params)
  dimension = params.key?(:dimension) ? [params.delete(:dimension)] : []
  conditions = {}
  FIELDS.each do |f|
    v = params[f]
    next if !v || v.empty?

    conditions[f] = v
  end
  return dimension, conditions
end

def get_es_prefix(params)
  prefix = {}
  PREFIX_SEARCH_FIELDS.each do |f|
    v = params[f]
    prefix[f] = v if v
  end
  prefix
end

def get_es_must(params)
  must = []
  prefix = get_es_prefix(params)
  must << { prefix: prefix } unless prefix.empty?
  must << { terms: { job_state: %w[finished failed] } }
  must
end

def get_groups_matrices(conditions, dimension, must, size, from)
  must += build_mutli_field_subquery_body(conditions)
  count_query = { query: { bool: { must: must } } }
  total = es_count(count_query)
  return {} if total < 1

  query = {
    query: {
      bool: {
        must: must
      }
    },
    size: size,
    from: from,
    sort: [{
      start_time: { order: 'desc' }
    }]
  }

  result = es_query(query)
  matrices = combine_group_query_data(result, dimension)
  while matrices.empty?
    from += size
    break if from > total

    query[:from] = from
    result = es_query(query)
    matrices = combine_group_query_data(result, dimension)
  end
  matrices
end

def get_compare_body(params)
  dimension, conditions = get_dimension_conditions(params)
  must = get_es_must(params)
  groups_matrices = get_groups_matrices(conditions, dimension, must, COMPARE_RECORDS_NUMBER, 0)
  if !groups_matrices || groups_matrices.empty?
    body = 'No Data.'
  else
    body = compare_group_matrices(groups_matrices, { no_print: true })
    body = 'No Difference.' if !body || body.empty?
  end
  return body
end

def compare(params)
  begin
    body = get_compare_body(params)
  rescue StandardError => e
    warn e.message
    return [500, headers.merge('Access-Control-Allow-Origin' => '*'), 'compare error']
  end
  [200, headers.merge('Access-Control-Allow-Origin' => '*'), body]
end

def space_to_nil(str)
  return unless str

  str&.strip!
  str.empty? ? nil : str
end

def get_positive_number(num, default_num)
  num = num.to_i
  return default_num unless num.positive?

  return num
rescue StandardError
  return default_num
end

def wrong_size?(size, from)
  return true if from.negative? || size.negative?
  return true if from > 1000000 || size > 1000000
  return true if size + from > 1000000
end

def es_search(must, size, from)
  FIELDS.each do |f|
    next if NOT_NEED_EXIST_FIELDS.include? f

    must << { exists: { field: f } }
  end
  count_query = { query: { bool: { must: must } } }
  total = es_count(count_query)
  unless size
    size = total
    from = 0
  end
  query = {
    query: { bool: { must: must } },
    size: size,
    from: from,
    sort: [{
      start_time: { order: 'desc' },
      id: { order: 'desc' }
    }]
  }
  return {}, total if wrong_size?(size, from)

  return es_query(query)['hits']['hits'], total
end

def get_job(result)
  job = {}
  ALL_FIELDS.each do |f|
    job[f] = result[f]
  end
  job
end

def search_job(git_repo, page_size, page_num)
  must = []
  must << { regexp: { upstream_repo: ".*#{git_repo}.*" } } if git_repo
  jobs = []
  result, total = es_search(must, page_size, page_num * page_size)
  result.each do |r|
    jobs << get_job(r['_source'])
  end
  return jobs, total
end

def get_banner(git_repo, branches)
  {
    repo: git_repo,
    git_url: get_repo(git_repo)[:git_url],
    upstream_branch: branches
  }
end

def get_optimize_jobs_braches(jobs)
  branch_set = Set.new
  jobs.size.times do |i|
    branch = jobs[i]['upstream_branch'].to_s
    if branch.empty?
      jobs[i]['upstream_branch'] = 'master'
      branch_set.add 'master'
    else
      jobs[i]['upstream_branch'] = branch
      branch_set.add branch
    end
  end
  return jobs, branch_set.to_a
end

def get_jobs_body(params)
  git_repo = space_to_nil(params[:upstream_repo])
  page_size = get_positive_number(params[:page_size], 20)
  page_num = get_positive_number(params[:page_num], 1) - 1
  jobs, total = search_job(git_repo, page_size, page_num)
  jobs, branches = get_optimize_jobs_braches(jobs)
  {
    total: total,
    filter: {
      upstream_repo: git_repo
    },
    banner: get_banner(git_repo, branches),
    jobs: jobs,
    fields: FIELDS
  }.to_json
end

def get_jobs(params)
  begin
    body = get_jobs_body(params)
  rescue StandardError => e
    warn e.message
    return [500, headers.merge('Access-Control-Allow-Origin' => '*'), 'get jobs error']
  end
  [200, headers.merge('Access-Control-Allow-Origin' => '*'), body]
end

def get_repo_url(urls)
  return unless urls.is_a?(Array)

  urls.each do |url|
    return url if url[0, 4] == 'http'
  end
  urls[0]
end

def get_repo(git_repo)
  repo = nil
  if git_repo
    must = [{ regexp: { git_repo: ".*#{git_repo}.*" } }]
    repo = query_repos(must, from: 0, size: 1)[0]
  end
  repo || {}
end

def query_repos(must, from: 0, size: 1)
  query = {
    query: { bool: { must: must } },
    size: size,
    from: from,
    sort: [{
      git_repo: { order: 'asc' }
    }]
  }
  result = ES_CLIENT.search index: 'repo', body: query
  repos = []
  result['hits']['hits'].each do |r|
    r = r['_source']
    repos << {
      git_url: get_repo_url(r['url']),
      git_repo: r['git_repo']
    }
  end
  repos
end

def search_repos(git_repo, page_size, page_num)
  size = page_size
  from = size * page_num
  must = git_repo ? [{ regexp: { git_repo: ".*#{git_repo}.*" } }] : []
  count_query = { query: { bool: { must: must } } }
  total = ES_CLIENT.count(index: 'repo', body: count_query)['count']
  return [], total if wrong_size?(size, from)

  return query_repos(must, from: from, size: size), total
end

def get_repos_body(params)
  page_size = get_positive_number(params[:page_size], 20)
  page_num = get_positive_number(params[:page_num], 1) - 1
  git_repo = params[:git_repo]

  repos, total = search_repos(git_repo, page_size, page_num)

  {
    total: total,
    repos: repos
  }.to_json
end

def get_repos(params)
  begin
   body = get_repos_body(params)
  rescue StandardError => e
    warn e.message
    return [500, headers.merge('Access-Control-Allow-Origin' => '*'), 'get repos error']
 end
  [200, headers.merge('Access-Control-Allow-Origin' => '*'), body]
end
