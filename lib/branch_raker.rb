require 'archive/tar/minitar'
require 'fileutils'
require 'grit'
require 'rake'
require 'stringio'

include Rake::DSL

module BranchRaker

  # These constants may be defined before including the module.
  IGNORE_BRANCHES ||= []
  REPO_DIR ||= '.'
  TMP_DIR ||= '/tmp'
  BUILD_DIR ||= 'builds'
  TMP_GROUP_DIR ||= "#{BUILD_DIR}/tmp"

  # Variables accessed by several tasks.
  @current = []
  @stale = []
  @ignore = []

  REPO = Grit::Repo.new REPO_DIR

  IGNORE_BRANCHES.each do |b|
    head = REPO.get_head(b)
    @ignore << head.commit unless head.nil?
  end

  class BuildError < RuntimeError
  end

  task :default => 'build:all'

  namespace :built do

    task :current do |t|
      Dir.glob "#{BUILD_DIR}/*/build_info" do |f|
        File.read(f).scan(/^  id: ([0-9abcdef]+)/) do |id|
          @current << REPO.commit(id[0]) unless @current.map{ |c| c.id }.include?(id[0])
        end
      end

      if t.application.top_level_tasks.include? 'built:current'
        heads = REPO.heads.keep_if{ |h| ( @current.map{ |c| c.id } + @ignore.map{ |c| c.id } ).include? h.commit.id }.sort_by{ |h| h.name }
        if heads.empty?
          print "No branches with current builds.\n"
        else
          print "Listing branches with current builds:\n"
          heads.each { |h| print "  #{h.name}\n" }
        end
      end
    end

    task :stale => :current do |t|
      @stale = REPO.heads.delete_if { |h| ( @current.map{ |c| c.id } + @ignore.map{ |c| c.id } ).include? h.commit.id }.sort_by{ |h| h.name }

      if t.application.top_level_tasks.include? 'built:stale'
        heads = REPO.heads.keep_if{ |h| ( @stale.map{ |h| h.commit.id } ).include? h.commit.id }.sort_by{ |h| h.name }
        if heads.empty?
          print "No branches with stale builds.\n"
        else
          print "Listing branches with stale builds:\n"
          heads.each { |h| print "  #{h.name}\n" }
        end
      end
    end
  end

  namespace :build do

    def extract_repo commit, dir
      input = Archive::Tar::Minitar::Input.new StringIO.new(REPO.archive_tar commit.id)
      input.each { |entry| input.extract_entry dir, entry }
    end

    def build_group heads
      built = []
      begin
        FileUtils.mkdir_p TMP_GROUP_DIR
        heads.each do |h|
          status = build(TMP_GROUP_DIR, h.commit, h.name)
          built << h.name unless status.nil?
        end
        FileUtils.mv TMP_GROUP_DIR, "#{BUILD_DIR}/#{Time.now.to_i} (#{built.join(' ,')})" unless built.empty?
      ensure
        FileUtils.rm_rf TMP_GROUP_DIR
      end
    end

    def build build_dir, commit, branch = nil

      build_name = branch.nil? ? commit.id : branch

      src = "#{TMP_DIR}/branch_raker_#{commit.id}"
      out_dir = "#{build_dir}/#{build_name}"

      begin
        FileUtils.mkdir src
        FileUtils.mkdir out_dir
        extract_repo commit, src
        make src, out_dir

        log = branch.nil? ? '' : "Branch: #{branch}\n"
        commit.to_hash.each do |k, v|
          if v.is_a? Hash
            log << "  #{k}:\n"
            v.each { |k, v| log << "    #{k}: #{v}\n" }
          elsif v.is_a? Array
            log << "  #{k}:\n"
            v.each { |v| v.each { |k, v| log << "    #{k}: #{v}\n" } }
          else
            log << "  #{k}: #{v}\n"
          end
        end
        File.open("#{build_dir}/build_info", 'a') { |f| f.write log + "\n" }

        print "Built #{build_name}."

        return true

      rescue BuildError => e
        FileUtils.rm_rf out_dir
        print "Failed to build #{branch} with error:\n#{e.message}"
        return nil
      ensure
        FileUtils.rm_rf src
      end
    end

    task :all => 'built:stale' do
      build_group @stale unless @stale.empty?
    end

    task :branch, [:branch] => ['built:update'] do |t, args|
      args.with_defaults :branch => nil
      head = args[:branch].nil? ? Grit::Head.current(REPO) : REPO.get_head(args[:branch])
      unless @current.map{ |c| c.id }.include?(head.commit.id)
        build head.commit, head.name, "#{Time.now.to_i} (#{head.name})"
      end
    end
  end
end