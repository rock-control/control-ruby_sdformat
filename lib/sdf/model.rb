module SDF
    # Representation of a SDF model tag
    class Model < Element
        # Load a model from its name
        #
        # See {XML.find_and_load_gazebo_model}. This method raises if the model
        # cannot be found
        #
        # @param [String] model_name the model name
        # @param [Integer,nil] sdf_version the maximum expected SDF version
        #   (as version * 100, i.e. version 1.5 is represented by 150). Leave to
        #   nil to always read the latest.
        # @return [Model]
        def self.load_from_model_name(model_name, sdf_version = nil)
            new(XML.model_from_name(model_name, sdf_version).elements.to_a('sdf/model').first)
        end

        include Tools::Pose

        # Whether the model is static
        def static?
            if static = xml.elements.to_a('static').first
                static = static.text.strip
                if static == '1'
                    true
                elsif static == '0'
                    false
                else
                    raise Invalid, "invalid boolean value for the static field of #{self}, expected '0' or '1' and got #{static}"
                end
            else
                false
            end
        end

        # Enumerates this model's links
        #
        # @yieldparam [Link] link
        def each_link
            return enum_for(__method__) if !block_given?
            xml.elements.each('link') do |element|
                yield(Link.new(element, self))
            end
        end

        # Enumerates this model's joints
        #
        # @yieldparam [Joint] joint
        def each_joint
            return enum_for(__method__) if !block_given?
            xml.elements.each('joint') do |element|
                yield(Joint.new(element, self))
            end
        end
    end
end

