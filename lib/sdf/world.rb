module SDF
    class World < Element
        # Return an empty world
        def self.empty(name: 'world', version: nil)
            if version && !version.respond_to?(:to_str)
                version = SDF.numeric_version_to_string(version)
            end

            xml = REXML::Document.new
            root = xml.add_element 'sdf'
            if version
                root.attributes['version'] = version
            end
            world = root.add_element 'world'
            world.attributes['name'] = name
            Root.new(xml.root).each_world.first
        end

        xml_tag_name 'world'

        # Enumerates the models from this world
        #
        # @yieldparam [Model] model
        def each_model
            return enum_for(__method__) if !block_given?
            xml.elements.each do |element|
                if element.name == 'model'
                    yield(Model.new(element, self))
                end
            end
        end
    end
end

