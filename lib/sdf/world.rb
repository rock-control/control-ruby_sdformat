module SDF
    class World < Element
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

