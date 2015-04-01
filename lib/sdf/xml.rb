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

        # Load a model by its name
        #
        # See {find_and_load_gazebo_model}. This method raises if the model
        #   cannot be found
        #
        # @param [String] model_name the model name
        # @!macro sdf_version
        # @raise (see load_gazebo_model)
        # @raise [NoSuchModel] if the provided model name does not resolve to a
        #   model in {model_path}
        # @return [REXML::Element]
        def self.model_from_name(model_name, sdf_version = nil)
            @gazebo_models[sdf_version] ||= Hash.new
            if model = @gazebo_models[sdf_version][model_name]
                return model
            end

            @model_path.each do |p|
                model_path = File.join(p, model_name)
                if File.file?(File.join(model_path, "model.config"))
                    sdf = load_gazebo_model(model_path, sdf_version)
                    return (@gazebo_models[sdf_version][model_name] = sdf)
                end
            end
            raise NoSuchModel, "cannot find model #{model_name} in path #{model_path.join(":")}. You probably want to update the GAZEBO_MODEL_PATH environment variable, or set SDF.model_path explicitely"
        end

        # Resolves the include tags children of an element
        #
        # This method modifies the XML tree by replacing the include tags found
        # as direct children of the provided element by the included content.
        #
        # @param [REXML::Element] root element to find include tags
        # @!macro sdf_version
        # @return [void]
        def self.add_include_tags(elem, sdf_version = nil)            
            replacements = []
            elem.elements.each("include") do |inc|
                inc.elements.each("uri") do |uri|
                    if uri.text =~ /^model:\/\/(.*)$/
                        model_name = $1
                    else
                        raise ArgumentError, "cannot interpret include URI #{uri}"
                    end
                                       
                    included_sdf = model_from_name(model_name, sdf_version)
                    replacements << [inc, included_sdf.root.elements]
                end
            end
                            
            replacements.each do |inc, models|
                parent = inc.parent
                inc.remove
                models.each do |m|
                    parent << m.dup 
                end
            end
        end

        # Open a SDF file and returns the XML representation
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
                    raise InvalidXML, e.message
                end
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
        # This resolves the include tags in the XML representation
        #
        # @param [String] sdf_file the path to the SDF file
        # @raise [Errno::ENOENT] if the files does not exist
        # @raise [NotSDF] if the file is not a SDF file
        # @raise [InvalidXML] if the file is not a valid XML file
        # @return [REXML::Element]
        def self.load_sdf(sdf_file)
            
            sdf = load_sdf_raw(sdf_file)
            
            sdf_version = sdf_version_of(sdf)
            
            add_include_tags(sdf.root, sdf_version)
            
            sdf.root.elements.each('world') do |e|
                add_include_tags(e, sdf_version)
            end
            
            sdf.root.elements.each('model') do |e|
                add_include_tags(e, sdf_version)
            end
                        
            sdf
        end
    end
end