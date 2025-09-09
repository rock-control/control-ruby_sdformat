require "rexml/document"

module SDF
    module XML
        # @!macro [new] sdf_version
        #   @param [Integer,nil] sdf_version the maximum expected SDF version
        #     (as version * 100, i.e. version 1.5 is represented by 150). Leave to
        #     nil to always read the latest.

        # Exception raised when trying to load a model URI, but the model does
        # not contain a SDF entry for the required SDF version
        class UnavailableSDFVersionInModel < ArgumentError; end
        # Exception raised when trying to load a file that is not a SDF file
        class NotSDF < ArgumentError; end
        # Exception raised when trying to load a malformed XML file
        class InvalidXML < ArgumentError; end

        # Exception raised when trying to resolve a model that cannot be found
        # in {model_path}
        class NoSuchModel < ArgumentError
            attr_reader :model_name

            def initialize(model_name)
                @model_name = model_name
            end
        end

        # The search path for models
        #
        # It defaults to GAZEBO_MODEL_PATH
        #
        # @return [Array<String>]
        def self.model_path
            @model_path
        end

        # Overrides the default for {model_path}
        #
        # @param [Array<String>] path list of directories in which we should
        #   search for models
        def self.model_path=(path)
            @model_path = Array(path)
            clear_cache
        end

        # load model_path with default parameters
        def self.initialize
            @model_path = (ENV["GAZEBO_MODEL_PATH"] || "").split(":")
            @model_path << File.join(Dir.home, ".gazebo", "models")
        end

        initialize

        # Clears the model cache
        #
        # @return [void]
        def self.clear_cache
            @gazebo_models.clear
        end

        # Load the SDF from a gazebo model
        #
        # @param [String] dir the path to the model directory
        # @!macro sdf_version
        # @raise [Errno::ENOENT] if the files does not exist
        # @raise [NotSDF] if the file is not a SDF file
        # @raise [InvalidXML] if the file is not a valid XML file
        # @raise [UnavailableSDFVersionInModel] if the model does not contain a
        #   SDF file for the required SDF version
        #
        # @return [REXML::Element]
        def self.load_gazebo_model(dir, sdf_version = nil, metadata: false, flatten: true)
            load_sdf(model_path_of(dir, sdf_version), metadata: metadata,
                                                      flatten: flatten)
        end

        # Find model string into model.config path
        #
        # @param [String] dir the path to the model directory
        # @!macro sdf_version
        # @raise [Errno::ENOENT] if the files does not exist
        # @raise [NotSDF] if the file is not a SDF file
        # @raise [InvalidXML] if the file is not a valid XML file
        # @raise [UnavailableSDFVersionInModel] if the model does not contain a
        #   SDF file for the required SDF version
        #
        # @return [String]
        def self.model_path_of(dir, sdf_version = nil)
            model_config_path = File.join(dir, "model.config")
            config = File.open(model_config_path) do |io|
                REXML::Document.new(io)
            rescue REXML::ParseException => e
                raise InvalidXML, "in #{model_config_path}, #{e.message}"
            end

            sdf = config.elements.enum_for(:each, "model/sdf").map do |sdf_element|
                version = Float(sdf_element.attributes["version"] || 0)
                version = (version * 100).round
                [version, File.join(dir, sdf_element.text)]
            end
            sdf = sdf.find_all { |v, _| v <= sdf_version } if sdf_version
            if sdf.empty?
                raise UnavailableSDFVersionInModel,
                      "gazebo model in #{dir} does not offer a SDF file matching version #{sdf_version}"
            else
                sdf.max_by { |v, _| v }.last
            end
        end

        @gazebo_models = {}

        # Returns all models available within {model_path} that match the
        # provided version requirement
        #
        # @!macro sdf_version
        # @return [Hash<String,REXML::Element>]
        def self.gazebo_models(sdf_version = nil)
            @gazebo_models[sdf_version] ||= {}
            @model_path.each do |p|
                Dir.glob(File.join(p, "*")) do |subdir|
                    model_name = File.basename(subdir)
                    next if @gazebo_models[sdf_version][model_name]

                    model_config_path = File.join(subdir, "model.config")
                    if File.file?(model_config_path)
                        begin
                            sdf_file_path = model_path_of(subdir, sdf_version)
                            sdf, metadata = load_sdf(sdf_file_path, metadata: true,
                                                                    flatten: false)
                            @gazebo_models[sdf_version][File.basename(subdir)] =
                                ModelCacheEntry.new(sdf_file_path, sdf, metadata)
                        rescue UnavailableSDFVersionInModel
                        end
                    end
                end
            end

            result = {}
            @gazebo_models[sdf_version].each do |name, cache_entry|
                result[name] = cache_entry.xml
            end
            result
        end

        ModelCacheEntry = Struct.new :path, :xml, :metadata

        # Finds the path to the SDF for a gazebo model and SDF version
        #
        # @param [String] model_name the model name
        # @!macro sdf_version
        # @raise (see model_path_of)
        # @raise [NoSuchModel] if the provided model name does not resolve to a
        #   model in {model_path}
        # @return [REXML::Element]
        def self.model_path_from_name(model_name, model_path: @model_path, sdf_version: nil)
            @gazebo_models[sdf_version] ||= {}
            cache = (@gazebo_models[sdf_version][model_name] ||= ModelCacheEntry.new)
            return cache.path if cache.path

            model_path.each do |p|
                model_dir = File.join(p, model_name)
                if File.file?(File.join(model_dir, "model.config"))
                    cache.path = model_path_of(model_dir, sdf_version)
                    return cache.path
                end
            end
            raise NoSuchModel.new(model_name),
                  "cannot find model #{model_name} in path #{model_path.join(':')}. You probably want to update the GAZEBO_MODEL_PATH environment variable, or set SDF.model_path explicitely"
        end

        # Load a model by its name
        #
        # This method raises if the model cannot be found
        #
        # @param [String] model_name the model name
        # @!macro sdf_version
        # @raise (see load_sdf)
        # @raise [NoSuchModel] if the provided model name does not resolve to a
        #   model in {model_path}
        # @return [REXML::Element]
        def self.model_from_name(
            model_name, sdf_version = nil, metadata: false, flatten: true
        )
            path = model_path_from_name(model_name, sdf_version: sdf_version)
            cache = @gazebo_models[sdf_version][model_name]
            unless cache.xml
                cache.xml, cache.metadata = load_sdf(path, metadata: true, flatten: false)
            end
            xml = cache.xml
            if flatten
                xml = deep_copy_xml(xml)
                flatten_model_tree(xml.root)
            end

            if metadata
                [xml, cache.metadata]
            else
                xml
            end
        end

        def self.resolve_relative_uris(node, sdf_version, base_path)
            nodes = [node]
            until nodes.empty?
                n = nodes.shift
                next if n.name == "include" # includes are handled differently

                if n.name == "uri"
                    if n.text =~ %r{^model://(\w+)(?:/(.*))?}
                        model_name = ::Regexp.last_match(1)
                        file_name = ::Regexp.last_match(2)
                        sdf_path = model_path_from_name(model_name,
                                                        sdf_version: sdf_version)
                        n.text = if file_name
                                     File.join(File.dirname(sdf_path), file_name)
                                 else
                                     File.dirname(sdf_path)
                                 end
                    elsif n.text[0, 1] != "/" # Relative path
                        n.text = File.expand_path(n.text, base_path)
                    end
                end
                nodes.concat(n.elements.to_a)
            end
        end

        # @api private
        #
        # Deep copy of a REXML tree, needed when including models in models
        def self.deep_copy_xml(node)
            result = node.clone
            queue = [node, result]
            until queue.empty?
                old = queue.shift
                new = queue.shift
                old.elements.each do |old_child|
                    new_child = old_child.clone
                    new_child.text = old_child.text
                    new << new_child
                    queue << old_child << new_child
                end
            end
            result
        end

        INCLUDE_CHILDREN_ELEMENTS = %w[static pose]

        # Resolves the include tags children of an element
        #
        # This method modifies the XML tree by replacing the include tags found
        # as direct children of the provided element by the included content.
        #
        # @param [REXML::Element] elem element to find include tags
        # @!macro sdf_version
        # @return [void]
        def self.add_include_tags(elem, sdf_version, base_path)
            includes = {}

            replacements = []
            elem.elements.each do |inc|
                if inc.name == "world" || inc.name == "model" # model-within-model
                    added_includes = add_include_tags(inc, sdf_version, base_path)
                    includes.merge! added_includes do |_, old, new|
                        old + new
                    end
                    next
                elsif inc.name != "include"
                    next
                end

                uri, name = nil
                overrides = {}
                inc.elements.each do |element|
                    if element.name == "uri"
                        uri = element.text
                    elsif element.name == "name"
                        name = element.text
                    elsif INCLUDE_CHILDREN_ELEMENTS.include?(element.name)
                        overrides[element.name] = element
                    else
                        raise InvalidXML,
                              "unexpected element '#{element.name}' found as child of an include"
                    end
                end

                if !uri
                    raise InvalidXML, "no uri element in include"
                elsif uri =~ %r{^model://(\w+)(?:/(.*))?}
                    model_name = ::Regexp.last_match(1)
                    file_name = ::Regexp.last_match(2)
                    if file_name
                        raise ArgumentError,
                              "does not know how to resolve an explicit file in a model:// URI inside an include"
                    end

                    included_sdf, included_metadata =
                        model_from_name(model_name, sdf_version, metadata: true,
                                                                 flatten: false)
                elsif File.directory?(uri_path = File.expand_path(uri, base_path))
                    included_sdf, included_metadata =
                        load_gazebo_model(uri_path, sdf_version, metadata: true,
                                                                 flatten: false)
                else
                    raise ArgumentError,
                          "URI #{uri} is neither a model:// URI nor an existing directory"
                end

                includes[included_metadata["path"]] ||= []
                includes[included_metadata["path"]] << name

                added_includes = included_metadata["includes"]
                includes.merge!(added_includes) do |_, old, new|
                    old + new
                end

                included_elements = included_sdf.root.elements.to_a
                if included_elements.size != 1
                    raise InvalidXML,
                          "expected included resource #{uri} to have exactly one model"
                end

                replacements << [inc, included_elements.first, name, overrides]
            end

            replacements.each do |inc, model, name, overrides|
                parent = inc.parent
                inc.remove

                model = deep_copy_xml(model)
                model.attributes["name"] = name if name

                unless overrides.empty?
                    to_delete = model.elements.find_all do |model_child|
                        overrides.has_key?(model_child.name)
                    end
                    to_delete.each { |model_child| model.elements.delete(model_child) }
                    overrides.each_value { |new_child| model << new_child }
                end
                parent << model
            end

            if elem.name != "sdf"
                prefix = "#{elem.attributes['name']}::"
                includes.each do |_uri, paths|
                    paths.map! { |p| "#{prefix}#{p}" }
                end
            end
            includes
        end

        # Open a SDF file and returns the XML representation
        #
        # Unlike {.load_sdf}, this really only loads the XML information, not
        # resolving the include tags.
        #
        # @param [String] sdf_file the path to the SDF file
        # @raise [Errno::ENOENT] if the files does not exist
        # @raise [NotSDF] if the file is not a SDF file
        # @raise [InvalidXML] if the file is not a valid XML file
        # @return [REXML::Element]
        def self.load_sdf_raw(sdf_file)
            sdf = File.open(sdf_file) do |io|
                REXML::Document.new(io)
            rescue REXML::ParseException => e
                unless e.message.match?(/No root/)
                    raise InvalidXML, "cannot load #{sdf_file}: #{e.message}"
                end

                REXML::Document.new
            end

            unless sdf.root
                raise NotSDF,
                      "#{sdf_file} can be parsed as an XML file, but it does not have a root"
            end

            if sdf.root.name != "sdf" && sdf.root.name != "gazebo"
                raise NotSDF, "#{sdf_file} is not a SDF file"
            end

            sdf
        end

        # Get sdf_version
        #
        # @param [REXML::Element] sdf element
        # @return [Float]
        def self.sdf_version_of(sdf)
            if sdf_version = sdf.root.attributes["version"]
                sdf_version = (Float(sdf_version) * 100).round
                return sdf_version
            end
            nil
        end

        # Loads a SDF file and returns the XML representation
        #
        # Unlike {.load_sdf_raw}, this resolves the include tags in the XML
        # representation
        #
        # @param [String] sdf_file the path to the SDF file
        # @raise [Errno::ENOENT] if the files does not exist
        # @raise [NotSDF] if the file is not a SDF file
        # @raise [InvalidXML] if the file is not a valid XML file
        # @return [REXML::Element]
        def self.load_sdf(sdf_file, flatten: true, metadata: false)
            sdf = load_sdf_raw(sdf_file)
            sdf_version = sdf_version_of(sdf)

            sdf_metadata = Hash["includes" => {}, "path" => sdf_file]
            includes = add_include_tags(sdf.root, sdf_version, File.dirname(sdf_file))
            sdf_metadata["includes"].merge!(includes) do |_, old, new|
                old + new
            end
            resolve_relative_uris(sdf.root, sdf_version, File.dirname(sdf_file))

            sdf = deep_copy_xml(sdf)
            flatten_model_tree(sdf.root) if flatten

            if metadata
                [sdf, sdf_metadata]
            else
                sdf
            end
        rescue Exception => e
            raise e, "while loading #{sdf_file}: #{e.message}", e.backtrace
        end

        # Replace a model-in-model by a flattened structure where links are
        # namespaced and transformed
        def self.flatten_model_tree(xml)
            if xml.name != "model"
                xml.children.each do |child|
                    next unless child.kind_of?(REXML::Element)

                    flatten_model_tree(child)
                end
                return
            end

            new = []
            removed = []
            xml.children.each do |child|
                next unless child.kind_of?(REXML::Element)
                next if child.name != "model"

                # Namespace the child's links with the include's name,
                # transform them with the pose, and add them directly
                basename = child.attributes["name"]

                flatten_model_tree(child)
                new.concat(transform_submodel_nodes(child, basename))
                removed << child
            end

            removed.each do |element|
                xml.elements.delete(element)
            end
            new.each do |element|
                xml << element
            end
        end

        def self.transform_submodel_nodes(submodel, basename)
            new = []
            model_pose = nil
            submodel.children.each do |child|
                next unless child.kind_of?(REXML::Element)

                if child_name = child.attributes["name"]
                    child.attributes["name"] = "#{basename}::#{child_name}"
                end

                if child.name == "pose"
                    model_pose = Conversions.pose_to_eigen(child)
                    next
                end

                if child.name == "joint"
                    # Need to translate the parent and child links
                    if parent_link = child.elements["parent"]
                        parent_link.text = "#{basename}::#{parent_link.text.strip}"
                    end
                    if child_link = child.elements["child"]
                        child_link.text = "#{basename}::#{child_link.text.strip}"
                    end
                end
                new << child
            end

            if model_pose
                new.each do |element|
                    # Apply the included element's pose
                    #
                    # Reference: parser.cc in libsdformat
                    if element.name == "joint"
                        if axis_xml = element.elements["axis"]
                            axis = Axis.new(axis_xml)

                            xyz = model_pose.rotation * axis.xyz
                            if xyz_xml = axis_xml.elements["xyz"]
                                axis_xml.elements.delete(xyz_xml)
                            end
                            axis_xml.elements << SDF::Conversions.eigen_to_vector3(xyz)
                        end
                    elsif element.name == "link"
                        child_pose_element = element.elements["pose"]
                        child_pose = Conversions.pose_to_eigen(child_pose_element)
                        child_pose = model_pose * child_pose
                        element.elements.delete(child_pose_element) if child_pose_element
                        element << Conversions.eigen_to_pose(child_pose)
                    end
                end
            end
            new
        end
    end
end
