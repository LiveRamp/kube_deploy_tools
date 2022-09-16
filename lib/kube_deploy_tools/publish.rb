require 'uri'
require 'yaml'

require 'kube_deploy_tools/built_artifacts_file'
require 'kube_deploy_tools/deploy_config_file'
require 'kube_deploy_tools/formatted_logger'
require 'kube_deploy_tools/object'

module KubeDeployTools
  class Publish
    def initialize(manifest:, artifact_registry:, output_dir:)
      @config = DeployConfigFile.new(manifest)
      @output_dir = output_dir

      @project = KubeDeployTools::PROJECT
      @build_number = KubeDeployTools::BUILD_NUMBER

      @artifact_registry = artifact_registry.driver
    end

    def publish()

      puts "@artifact_registry == "
      puts @artifact_registry.inspect

      @config.artifacts.each do |c|
        name = c.fetch('name')
        puts "@manifest config name== "
        puts name.inspect

        # Allow deploy.yaml to gate certain flavors to certain targets.
        cluster_flavors = @config.flavors.select { |key, value| c['flavors'].nil? || c['flavors'].include?(key) }
        puts "@cluster_flavors== "
        puts cluster_flavors.inspect

        cluster_flavors.each do |flavor, _|
          puts "@output_dir == "
          puts @output_dir.inspect

          puts "@name == "
          puts name.inspect

          puts "flavor== "
          puts flavor.inspect

          puts "@project== "
          puts @project.inspect

          puts "@build_number== "
          puts @build_number.inspect


          @artifact_registry.upload(
            local_dir: @output_dir,
            name: name,
            flavor: flavor,
            project: @project,
            build_number: @build_number,
          )
        end
      end
    end


    def publish_with_env_app(env, app)

      puts "artifact_registry == "
      puts @artifact_registry.inspect
      puts "output_dir == "
      puts @output_dir.inspect

      @config.artifacts.each do |c|
        name = c.fetch('name')
        puts "manifest config name== "
        puts name.inspect

        # Allow deploy.yaml to gate certain flavors to certain targets.
        cluster_flavors = @config.flavors.select { |key, value| c['flavors'].nil? || c['flavors'].include?(key) }

        cluster_flavors.each do |flavor, _|
          @artifact_registry.upload_with_env_app(
            local_dir: @output_dir,
            name: name,
            flavor: flavor,
            project: @project,
            build_number: @build_number,
            env: env,
            app: app,
          )
        end
      end
    end
  end
end
