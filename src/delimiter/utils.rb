# SPDX-License-Identifier: MulanPSL-2.0+
# frozen_string_literal: true

require 'set'
require 'fileutils'

require_relative './constants'

# a utils module for delimiter service
module Utils
  class << self
    def clone_repo(repo, commit)
      repo_root = "#{TMEP_GIT_BASE}/#{File.basename(repo, '.git')}-#{`echo $$`}".chomp
      FileUtils.rm_r(repo_root) if Dir.exist?(repo_root)
      system("git clone -q #{repo} #{repo_root} && git -C #{repo_root} checkout -q #{commit}") ? repo_root : nil
    end

    def get_test_commits(work_dir, commit, day_agos)
      commits = Set.new
      day_agos.each do |day_ago|
        temp_commit = get_day_ago_commit(work_dir, commit, day_ago)
        commits << temp_commit if temp_commit
      end
      commits << get_last_commit(work_dir, commit) if commits.empty?
      return commits.to_a
    end

    def get_day_ago_commit(work_dir, commit, day_ago)
      date = `git -C #{work_dir} rev-list --first-parent --pretty=format:%cd \
      --date=short #{commit} -1 | sed -n 2p`.chomp!
      since = `date -d '-#{day_ago.to_i + 1} day #{date}' +%Y-%m-%d`.chomp!
      before = `date -d '1 day #{since}' +%Y-%m-%d`.chomp!
      day_ago_commit = `git -C #{work_dir} rev-list --since=#{since} --before=#{before} \
      --pretty=format:%H --first-parent #{commit} -1 | sed -n 2p`.chomp!
      return day_ago_commit
    end

    def get_last_commit(work_dir, commit)
      last_commit = `git -C #{work_dir} rev-list --first-parent #{commit} -2 | sed -n 2p`.chomp!
      return last_commit
    end
  end
end
