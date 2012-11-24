module Ki

  class BuildVersionMetadataFile
    attr_chain :input, -> { Dir.pwd }
    attr_chain :metadata, -> { VersionMetadataFile.new("ki-metadata.json") }
    attr_chain :source, -> { Hash.new }
    attr_chain :default_parameters, -> { {"hashes" => ["sha1"], "tags" => []} }
    attr_chain :previous_dep, :require => "Define a dependency before -o or --operation"

    def execute(args)
      files = opts.parse(args)
      if source.size > 0
        metadata.source(source)
      end
      metadata.add_files(input, files, default_parameters)
      metadata.save
    end

    def help
      "Test #{opts}"
    end

    def summary
      "Creates version metadata file. Possible to set source info, dependencies, files and operations."
    end

    def opts
      OptionParser.new do |opts|
        opts.on("-f", "--file FILE", "Version file target") do |v|
          if @input.nil?
            input(File.dirname(v))
          end
          metadata.init_from_path(v)
        end
        opts.on("-i", "--input-directory INPUT-DIR", "Input directory") do |v|
          input(v)
        end
        opts.on("-v", "--version-id VERSION-ID", "Version's id") do |v|
          metadata.version_id=v
        end
        ["url", "tag-url", "author", "repotype"].each do |source_param|
          opts.on("--source-#{source_param} #{source_param.upcase}", "Build source parameter #{source_param}") do |v|
            source[source_param]=v
          end
        end
        ["hashes", "tags"].each do |file_param|
          opts.on("--file-#{file_param} #{file_param.upcase}", "File parameter #{file_param}") do |v|
            default_parameters[file_param]= v.split(",").sort
          end
        end
        opts.on("-d", "--dependency DEPENDENCY", "Dependency definition my/component/123[,name=AA][,path=aa][,internal]") do |v|
          previous_dep(metadata.add_dependency(v))
        end
        opts.on("-o", "--operation OP", "Add operation to previous dependency") do |v|
          previous_dep.add_operation(v.split(" "))
        end
        opts.on("-O", "--version-operation OP", "Add operation to version") do |v|
          metadata.add_operation(v.split(" "))
        end
      end
    end
  end

  class TestVersion
    attr_chain :tester, -> { VersionTester.new.recursive(false).print(true) }
    attr_chain :input, -> { Dir.pwd }
    attr_chain :file, :require

    def execute(args)
      opts.parse(args)
      if @root_version
        tester_args = [@root_version]
      else
        tester_args = [file, input]
      end
      all_ok = tester.test_version(*tester_args)
      if all_ok
        puts "All files ok."
      end
    end

    def help
      "Test #{opts}"
    end

    def summary
      "Tests version's files if they are intact."
    end

    def opts
      OptionParser.new do |opts|
        opts.on("-f", "--file FILE", "Version source file. By default uses file's directory as source for binary files.'") do |v|
          if @input.nil?
            input(File.dirname(v))
          end
          file(v)
        end
        opts.on("-i", "--input-directory INPUT-DIR", "Input directory") do |v|
          input(v)
        end
        opts.on("-v", "--version-id VERSION-ID", "Version's id. Tests version from package directory.") do |v|
          @root_version = v
        end
        opts.on("-r", "--recursive", "Tests version's dependencies also.'") do |v|
          tester.recursive = true
        end
        opts.on("-h", "--home HOME-PATH", "Path to Ki root directory") do |v|
          tester.ki_home(KiHome.new(v))
        end
      end
    end
  end

  class ImportVersion
    attr_chain :input, -> { Dir.pwd }
    attr_chain :file, :require
    attr_chain :importer, -> { VersionImporter.new }

    def help
      "Test #{opts}"
    end

    def summary
      "Imports version to local package directories"
    end

    def execute(args)
      opts.parse(args)
      importer.import(file, input)
    end

    def opts
      OptionParser.new do |opts|
        opts.on("-f", "--file FILE", "Version source file. By default uses file's directory as source for binary files.'") do |v|
          if @input.nil?
            input(File.dirname(v))
          end
          file(v)
        end
        opts.on("-i", "--input-directory INPUT-DIR", "Input directory") do |v|
          input(v)
        end
        opts.on("-h", "--home HOME-PATH", "Path to Ki root directory") do |v|
          importer.ki_home(KiHome.new(v))
        end
        opts.on("-t", "--test-recursive", "Tests version's dependencies before importing.'") do |v|
          importer.tester.recursive = true
        end
      end
    end
  end

  class ExportVersion
    attr_chain :out, -> { Dir.pwd }
    attr_chain :exporter, -> { VersionExporter.new }

    def help
      "Test #{opts}"
    end

    def summary
      "Export version to current directory or selected output directory"
    end

    def execute(args)
      version = opts.parse(args).size!(1).first
      exporter.export(version, out)
    end

    def opts
      OptionParser.new do |opts|
        opts.on("-o", "--output-directory INPUT-DIR", "Input directory") do |v|
          out(v)
        end
        opts.on("-h", "--home HOME-PATH", "Path to Ki root directory") do |v|
          exporter.ki_home(KiHome.new(v))
        end
        opts.on("-t", "--test", "Test version before export") do |v|
          exporter.test_dependencies=true
        end
      end
    end
  end

  class VersionStatus
    attr_chain :package_info, -> { "site" }
    attr_chain :ki_home, :require => "Use -h to set package info location"

    def help
      "Test #{opts}"
    end

    def summary
      "Add status to version to specified package info location"
    end

    def execute(args)
      command = args.delete_at(0)
      case command
        when "add"
          version, key, value, *args = opts.parse(args)
          flags = args.to_h("=")
          pi = ki_home.package_info(package_info)
          pi.version(version).statuses.add_status(key, value, flags)
        else
          raise "Not supported '#{command}'"
      end
    end

    def opts
      OptionParser.new do |opts|
        opts.on("-h", "--home HOME-PATH", "Path to Ki root directory") do |v|
          ki_home(KiHome.new(v))
        end
        opts.on("-i", "--package-info", "Info directory") do |v|
          out(v)
        end
      end
    end
  end

  KiCommand.register_cmd("build-version", BuildVersionMetadataFile)
  KiCommand.register_cmd("test-version", TestVersion)
  KiCommand.register_cmd("import-version", ImportVersion)
  KiCommand.register_cmd("export-version", ExportVersion)
  KiCommand.register_cmd("version-status", VersionStatus)
  KiCommand.register("/hashing/sha1", SHA1)
  KiCommand.register("/hashing/sha2", SHA2)
  KiCommand.register("/hashing/md5", MD5)

end