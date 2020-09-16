# SPDX-License-Identifier: MulanPSL-2.0+ or GPL-2.0
# frozen_string_literal: true

require 'elasticsearch'
require_relative 'constants.rb'

# build multiple query request body
class ESQuery
  HOST = (ENV.key?('ES_HOST') ? ENV['ES_HOST'] : ES_HOST)
  PORT = (ENV.key?('ES_PORT') ? ENV['ES_PORT'] : ES_PORT).to_i
  def initialize(host = HOST, port = PORT)
    @client = Elasticsearch::Client.new url: "http://#{host}:#{port}"
    raise 'Connect Elasticsearch  error!' unless @client.ping
  end

  # Example @items: { key1 => value1, key2 => [value2, value3, ..], ...}
  # means to query: key1 == value1 && (key2 in [value2, value3, ..])
  def multi_field_query(items, size: 10_000, range: {})
    query_fields = build_mutli_field_subquery_body items
    query_fields << { range: range } if range && !range.empty?
    query = {
      query: {
        bool: {
          must: query_fields
        }
      }, size: size
    }
    @client.search index: 'jobs*', body: query
  end

  def query_by_id(id)
    @client.get_source({ index: 'jobs', type: '_doc', id: id })
  rescue Elasticsearch::Transport::Transport::Errors::NotFound
    nil
  end
end

def build_mutli_field_subquery_body(items)
  query_fields = []
  items.each do |key, value|
    if value.is_a?(Array)
      inner_query = build_multi_field_or_query_body(key, value)
      query_fields.push({ bool: { should: inner_query } })
    else
      query_fields.push({ term: { key => value } })
    end
  end
  query_fields
end

def build_multi_field_or_query_body(field, value_list)
  inner_query = []
  value_list.each do |inner_value|
    inner_query.push({ term: { field => inner_value } })
  end
  inner_query
end

def parse_conditions(items)
  items_hash = {}
  items.each do |i|
    key, value = i.split('=')
    if key && value
      value_list = value.split(',')
      items_hash[key] = value_list.length > 1 ? value_list : value
    else
      warn "error: condition \"#{key}\" missing", "tips: should give the input like \"#{key}=value\" "
      exit
    end
  end
  items_hash
end
