require 'kube_deploy_tools/formatted_logger'

# frozen_string_literal: true
module KubeDeployTools
  module FileFilter

    def self.filter_files(filters:, files_path:)
      all_files = Dir[File.join(files_path, '**', '*')].to_set
      filtered_files = if filters.any? { |k, _| k =~ /include_/ }
        Set.new
      else
        Set.new(all_files)
      end

      filters.each do |action, globpath|
        if action =~ /_dir$/
          # ensure globpath correctly selects an entire dir recursively
          # always starts with files_path
          # always ends with /**/* (to recusively select entire dir)
          globpath = File.join(files_path, globpath.gsub(/^[\/*]+|[\/*]+$/, ""), '**', '*')
        end

        case action
        when /^include_(files|dir)$/
          filtered_files.merge( all_files.select{ |f| File.fnmatch?(globpath, f, File::FNM_PATHNAME) } )
        when /^exclude_(files|dir)$/
          filtered_files.reject!{ |f| File.fnmatch?(globpath, f, File::FNM_PATHNAME) }
        else
          raise "you want to #{action}: wat do"
        end
      end
      Logger.debug("\nYour filter generates following paths: \n#{filtered_files.to_a.join("\n")}")
      filtered_files
    end
  end
end
