require 'guard'
require 'guard/plugin'
require 'scss_lint'
require 'rainbow'
require 'rainbow/ext/string'

module Guard
  class ScssLint < Plugin
    require 'guard/scss-lint/version'

    def self.non_namespaced_name
      'scss-lint'
    end
    
    attr_reader :config

    def initialize(options = {})
      super
      @options = {
        all_on_start: true,
        keep_failed: false
      }.merge(options)

      config_file = @options[:config] || '.scss-lint.yml'
      if File.exist?(config_file)
        @config     = SCSSLint::Config.load config_file
        @config_yml = YAML.load_file config_file
        @config_yml['exclude'].each { |e| @config.exclude_file e } if @config_yml['exclude']
      else
        @config = SCSSLint::Config.default
      end
      @scss_lint_runner = SCSSLint::Runner.new @config
      @failed_paths     = []
    end

    def start
      UI.info 'Guard::ScssLint is running'
      run_all if @options[:all_on_start]
    end

    def reload
      @failed_paths = []
    end

    def run_all
      UI.info 'Running ScssLint for all .scss files'
      pattern = File.join '**', '*.scss'
      paths   = Watcher.match_files(self, Dir.glob(pattern))
      run_on_changes paths
    end

    def run_on_changes(paths)
      paths << @failed_paths if @options[:keep_failed]
      run paths.uniq
    end

    private
    
    def run(paths = [])
      scss_lint_runner = SCSSLint::Runner.new config
      paths = paths.reject { |p| config.excluded_file?(p) }.map { |path| { path: path } }
      scss_lint_runner.run paths

      report_lints(scss_lint_runner.lints, paths)

      UI.info "Guard::ScssLint inspected #{paths.size} files, found #{scss_lint_runner.lints.count} errors."
    end

    def report_lints(lints, files)
      sorted_lints = lints.sort_by { |l| [l.filename, l.location] }
      results = SCSSLint::Reporter::DefaultReporter.new(sorted_lints, files, scss_lint_logger).report_lints

      return unless results

      UI.info results
    end

    def scss_lint_logger
      return @scss_lint_logger if @scss_lint_logger

      @scss_lint_logger = SCSSLint::Logger.new(STDOUT)
      @scss_lint_logger.color_enabled = true
      @scss_lint_logger
    end
  end
end
