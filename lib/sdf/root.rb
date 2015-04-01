module SDF
    # A representation of a SDF document root
    class Root < Element
        # The XML document underlying this SDF document
        #
        # @return [REXML::Document]
        attr_reader :xml

        def initialize(xml)
            super
        end

        # Loads a SDF file
        #
        # @param [String] sdf_file the path to the SDF file or a model:// URI
        # @param [Integer,nil] expected_sdf_version if the SDF file is a
        #   model:// URI, this is the maximum expected SDF version (as version *
        #   100, i.e. version 1.5 is represented by 150). Leave to nil to always
        #   read the latest.
        # @raise [Errno::ENOENT] if the files does not exist
        # @raise [XML::NotSDF] if the file is not a SDF file
        # @raise [XML::InvalidXML] if the file is not a valid XML file
        # @return [Root]
        def self.load(sdf_file, expected_sdf_version = nil)
            if sdf_file =~ /^model:\/\/(.*)/
                return load_from_model_name($1, expected_sdf_version)
            else
                new(XML.load_sdf(sdf_file))
            end
        end

        # Load a model from its name
        #
        # See {XML.find_and_load_gazebo_model}. This method raises if the model
        # cannot be found
        #
        # @param [String] model_name the model name
        # @param [Integer,nil] sdf_version the maximum expected SDF version
        #   (as version * 100, i.e. version 1.5 is represented by 150). Leave to
        #   nil to always read the latest.
        # @return [Root]
        def self.load_from_model_name(model_name, sdf_version = nil)
            new(XML.model_from_name(model_name, sdf_version))
        end

        # The SDF version
        #
        # @return [Integer] the advertised SDF version (as version * 100, i.e.
        #   version 1.5 is represented by 150).
        def version
            (Float(xml.attributes['version']) * 100).round
        end

        # Enumerates the toplevel models
        #
        # @yieldparam [Model] model
        def each_model
            return enum_for(__method__) if !block_given?
            xml.elements.each('sdf/model') do |element|
                yield(Model.new(element, self))
            end
        end

        # Enumerates the toplevel worlds
        #
        # @yieldparam [World] world
        def each_world
            return enum_for(__method__) if !block_given?
            xml.elements.each('sdf/world') do |element|
                yield(World.new(element, self))
            end
        end
    end
end
