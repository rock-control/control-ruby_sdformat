module SDF
    # A representation of a SDF document root
    class Root < Element
        xml_tag_name 'sdf'

        # The XML document underlying this SDF document
        #
        # @return [REXML::Document]
        attr_reader :xml

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
                new(XML.load_sdf(sdf_file).root)
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
            new(XML.model_from_name(model_name, sdf_version).root)
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
        def each_model(recursive: false)
            return enum_for(__method__, recursive: recursive) if !block_given?
            xpath_query =
                if recursive then './/model'
                else 'model'
                end
            xml.elements.each(xpath_query) do |element|
                model = Model.new(element, self)
                model.make_parents(self)
                yield(model)
            end
        end

        # Enumerates the toplevel worlds
        #
        # @yieldparam [World] world
        def each_world(recursive: false)
            return enum_for(__method__, recursive: recursive) if !block_given?
            xpath_query =
                if recursive then './/world'
                else 'world'
                end
            xml.elements.each(xpath_query) do |element|
                world = World.new(element, self)
                world.make_parents(self)
                yield(world)
            end
        end

        # Make a XML element into a proper SDF document by adding a root node,
        # and return the corresponding Root object
        #
        # @param [REXML::Element] element
        # @return [Root]
        def self.make(element, version = nil)
            if version && !version.respond_to?(:to_str)
                version = SDF.numeric_version_to_string(version)
            end

            root = REXML::Document.new
            root = root.add_element 'sdf'
            root.add_element element
            if version
                root.attributes['version'] = version
            end
            new(root)
        end
    end
end
