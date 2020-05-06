require_relative 'driver_base'

require 'kube_deploy_tools/formatted_logger'
require 'kube_deploy_tools/shellrunner'
require 'kube_deploy_tools/object'

require 'fileutils'
require 'uri'
require 'find'


module KubeDeployTools
  class ArtifactRegistry::Driver::GCS < ArtifactRegistry::Driver::Base
    def initialize(config:)
      @config = config

      @bucket = @config.fetch('bucket')
      prefix = @config.fetch('prefix', '')
      if !prefix.empty?
        @bucket = "#{@bucket}/#{prefix}"
      end
    end

    def get_local_artifact_path(name:, flavor:, local_dir:)
      artifact_name = get_artifact_name(name: name, flavor: flavor)

      local_artifact_path = File.join(local_dir, artifact_name)

      local_artifact_path
    end

    def get_registry_artifact_path(name:, flavor:, project:, build_number:)
      # NOTE(joshk): If the naming format changes, it represents a breaking
      # change where all past clients will not be able to download new builds and
      # new clients will not be able to download old builds. Change with caution.
      #
      "#{@bucket}/project=#{project}/build=#{build_number}/artifact=#{get_artifact_name(name: name, flavor: flavor)}"
    end

    def get_artifact_name(name:, flavor:)
      "manifests_#{name}_#{flavor}.yaml"
    end

    def package(name:, flavor:, input_dir:, output_dir:)
      local_artifact_path = get_local_artifact_path(name: name, flavor: flavor, local_dir: output_dir)
      File.open(local_artifact_path, 'w') do |merged|
        Find.find(input_dir).
          select { |path| path =~ /.*\.yaml$/ }.
          each do |e|
            contents = File.open(e, 'r').read
            contents.each_line do |line|
              merged << line
            end
          end
      end
      local_artifact_path
    end

    def download(project:, build_number:, flavor:, name:, pre_apply_hook:, output_dir:)
      registry_artifact_path = get_registry_artifact_path(
        name: name, flavor: flavor, project: project, build_number: build_number)

      local_artifact_path = download_artifact(registry_artifact_path, output_dir)

      if pre_apply_hook
        out, err, status = Shellrunner.run_call(pre_apply_hook, local_artifact_path)
        if !status.success?
          raise "Failed to run post download hook #{pre_apply_hook}"
        end
      end

      local_artifact_path
    end

    def download_artifact(input_path, output_dir_path)
      filename = File.basename(input_path)
      output_path = File.join(output_dir_path, filename)
      out, err, status = Shellrunner.run_call('gsutil', 'cp', input_path, output_path)

      if !status.success?
        raise "Failed to download remote deploy artifact #{input_path}"
      end

      output_path
    end

    def upload(local_dir:, name:, flavor:, project:, build_number:)
      # Pack up contents of each flavor_dir to a correctly named artifact.
      flavor_dir = File.join(local_dir, "#{name}_#{flavor}")

      package(
        name: name,
        flavor: flavor,
        input_dir: flavor_dir,
        output_dir: local_dir,
      )

      local_artifact_path = get_local_artifact_path(
        local_dir: local_dir,
        name: name,
        flavor: flavor,
      )

      registry_artifact_path = get_registry_artifact_path(
        project: project,
        name: name,
        flavor: flavor,
        build_number: build_number,
      )

      Logger.info("Uploading #{local_artifact_path} to #{registry_artifact_path}")
      out, err, status = Shellrunner.run_call('gsutil',  '-m', 'cp', local_artifact_path, registry_artifact_path)
      if !status.success?
        raise "Failed to upload remote deploy artifact from #{local_artifact_path} to #{registry_artifact_path}"
      end

      registry_artifact_path
    end
  end
end
