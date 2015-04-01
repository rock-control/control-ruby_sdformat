module SDF
    class World < Element
        # Enumerates the models from this world
        #
        # @yieldparam [Model] model
        def each_model
            return enum_for(__method__) if !block_given?
            xml.elements.each('model') do |element|
                yield(Model.new(element, self))
            end
        end
    end
end

