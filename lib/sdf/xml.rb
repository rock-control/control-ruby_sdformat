require 'rexml/document'

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
        class NoSuchModel < ArgumentError; end

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
        
        #load model_path with default parameters
        def self.initialize
            @model_path = (ENV['GAZEBO_MODEL_PATH'] || '').split(':')
            @model_path << File.join(Dir.home, '.gazebo', 'models')
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
        def self.load_gazebo_model(dir, sdf_version = nil)
            return load_sdf(model_path_of(dir, sdf_version))
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
                begin
                    REXML::Document.new(io)
                rescue REXML::ParseException => e
                    raise InvalidXML, "in #{model_config_path}, #{e.message}"
                end
            end

            sdf = config.elements.enum_for(:each, 'model/sdf').map do |sdf_element|
                version = Float(sdf_element.attributes['version'] || 0)
                version = (version * 100).round
                [version, File.join(dir, sdf_element.text)]
            end
            if sdf_version
                sdf = sdf.find_all { |v, _| v <= sdf_version }
            end
            if sdf.empty?
                raise UnavailableSDFVersionInModel, "gazebo model in #{dir} does not offer a SDF file matching version #{sdf_version}"
            else
                return sdf.max_by { |v, _| v }.last
            end
        end

        @gazebo_models = Hash.new

        # Returns all models available within {model_path} that match the
        # provided version requirement
        #
        # @!macro sdf_version
        # @return [Hash<String,REXML::Element>]
        def self.gazebo_models(sdf_version = nil)
            @gazebo_models[sdf_version] ||= Hash.new
            @model_path.each do |p|
                Dir.glob(File.join(p, "*")) do |subdir|
                    model_name = File.basename(subdir)
                    next if @gazebo_models[sdf_version][model_name]

                    model_config_path = File.join(subdir, "model.config")
                    if File.file?(model_config_path)
                        begin
                            sdf = load_gazebo_model(subdir, sdf_version)
                            @gazebo_models[sdf_version][File.basename(subdir)] = sdf
                        rescue UnavailableSDFVersionInModel
                        end
                    end
                end
            end
            @gazebo_models[sdf_version]
        end

        ModelCacheEntry = Struct.new :path, :model

        # Finds the path to the SDF for a gazebo model and SDF version
        #
        # @param [String] model_name the model name
        # @!macro sdf_version
        # @raise (see model_path_of)
        # @raise [NoSuchModel] if the provided model name does not resolve to a
        #   model in {model_path}
        # @return [REXML::Element]
        def self.model_path_from_name(model_name, model_path: @model_path, sdf_version: nil)
            @gazebo_models[sdf_version] ||= Hash.new
            cache = (@gazebo_models[sdf_version][model_name] ||= ModelCacheEntry.new)
            if cache.path
                return cache.path
            end

            model_path.each do |p|
                model_dir = File.join(p, model_name)
                if File.file?(File.join(model_dir, "model.config"))
                    cache.path = model_path_of(model_dir, sdf_version)
                    return cache.path
                end
            end
            raise NoSuchModel, "cannot find model #{model_name} in path #{model_path.join(":")}. You probably want to update the GAZEBO_MODEL_PATH environment variable, or set SDF.model_path explicitely"
        end

        # Load a model by its name
        #
        # See {find_and_load_gazebo_model}. This method raises if the model
        #   cannot be found
        #
        # @param [String] model_name the model name
        # @!macro sdf_version
        # @raise (see load_sdf)
        # @raise [NoSuchModel] if the provided model name does not resolve to a
        #   model in {model_path}
        # @return [REXML::Element]
        def self.model_from_name(model_name, sdf_version = nil)
            path = model_path_from_name(model_name, sdf_version: sdf_version)
            cache = @gazebo_models[sdf_version][model_name]
            cache.model ||= load_sdf(path)
            return cache.model
        end

        def self.resolve_relative_uris(node, sdf_version, base_path)
            nodes = [node]
            while !nodes.empty?
                n = nodes.shift
                next if n.name == 'include' # includes are handled differently
                if n.name == 'uri'
                    if n.text =~ /^model:\/\/(\w+)(?:\/(.*))?/
                        model_name, file_name = $1, $2
                        sdf_path = model_path_from_name(model_name, sdf_version: sdf_version)
                        if file_name
                            n.text = File.join(File.dirname(sdf_path), file_name)
                        else
                            n.text = File.dirname(sdf_path)
                        end
                    elsif n.text[0,1] != '/' # Relative path
                        n.text = File.expand_path(n.text, base_path)
                    end
                end
                nodes.concat(n.elements.to_a)
            end
        end

        INCLUDE_CHILDREN_ELEMENTS = %w{static pose}

        # @api private
        #
        # Deep copy of a REXML tree, needed when including models in models
        def self.deep_copy_xml(node)
            result = node.clone
            queue = [node, result]
            while !queue.empty?
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

        # Resolves the include tags children of an element
        #
        # This method modifies the XML tree by replacing the include tags found
        # as direct children of the provided element by the included content.
        #
        # @param [REXML::Element] root element to find include tags
        # @!macro sdf_version
        # @return [void]
        def self.add_include_tags(elem, sdf_version, base_path)
            replacements = []
            elem.elements.each do |inc|
                if inc.name == 'model' # model-within-model
                    add_include_tags(inc, sdf_version, base_path)
                    next
                elsif inc.name != 'include'
                    next
                end

                uri, name = nil
                overrides = Hash.new
                inc.elements.each do |element|
                    if element.name == 'uri'
                        uri = element.text
                    elsif element.name == 'name'
                        name = element.text
                    elsif INCLUDE_CHILDREN_ELEMENTS.include?(element.name)
                        overrides[element.name] = element
                    else
                        raise InvalidXML, "unexpected element '#{element.name}' found as child of an include"
                    end
                end

                if !uri
                    raise InvalidXML, "no uri element in include"
                elsif uri =~ /^model:\/\/(\w+)(?:\/(.*))?/
                    model_name, file_name = $1, $2
                    included_sdf = model_from_name(model_name, sdf_version)
                elsif File.directory?(uri_path = File.expand_path(uri, base_path))
                    included_sdf = load_gazebo_model(uri_path, sdf_version)
                else
                    raise ArgumentError, "URI #{uri} is neither a model:// URI nor an existing directory"
                end

                included_elements = included_sdf.root.elements.to_a
                if included_elements.size != 1
                    raise InvalidXML, "expected included resource #{uri} to have exactly one model"
                end

                replacements << [inc, included_elements.first, name, overrides]
            end
                            
            replacements.each do |inc, model, name, overrides|
                parent = inc.parent
                inc.remove

                model = deep_copy_xml(model)
                parent << model
                if name
                    model.attributes['name'] = name
                end
                if !overrides.empty?
                    to_delete = model.elements.find_all { |model_child| overrides.has_key?(model_child.name) }
                    to_delete.each { |model_child| model.elements.delete(model_child) }
                    overrides.each_value { |new_child| model << new_child }
                end
            end
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
                begin
                    REXML::Document.new(io)
                rescue REXML::ParseException => e
                    raise InvalidXML, "cannot load #{sdf_file}: #{e.message}"
                end
            end

            if !sdf.root
                raise NotSDF, "#{sdf_file} can be parsed as an XML file, but it does not have a root"
            end

            if sdf.root.name != 'sdf' && sdf.root.name != 'gazebo'
                raise NotSDF, "#{sdf_file} is not a SDF file"
            end
            sdf
        end
        
        # Get sdf_version
        #
        # @param [REXML::Element] sdf element
        # @return [Float]
        def self.sdf_version_of(sdf)
            if sdf_version = sdf.root.attributes['version']
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
        def self.load_sdf(sdf_file)
            sdf = load_sdf_raw(sdf_file)
            sdf_version = sdf_version_of(sdf)
            
            sdf.root.elements.each do |element|
                if element.name == 'world' || element.name == 'model'
                    add_include_tags(element, sdf_version, File.dirname(sdf_file))
                end
            end
            resolve_relative_uris(sdf.root, sdf_version, File.dirname(sdf_file))
            sdf
        rescue Exception => e
            raise e, "while loading #{sdf_file}: #{e.message}", e.backtrace
        end
    end
end
