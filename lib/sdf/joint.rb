module SDF
    class Joint < Element
        # The joint type
        def type
            if t = xml.attributes['type']
                t
            else
                raise Invalid, "expected attribute 'type' missing on #{self}"
            end
        end

        # The model's pose w.r.t. its parent
        #
        # @return [Array<Float>]
        def pose
            EigenConversions.pose_to_eigen(xml.elements["pose"])
        end

        # The joint's parent link
        #
        # @raise [Invalid] if the parent link is not declared or could not be
        #   found
        # @return [Link]
        def parent_link
            if !@parent_link
                parent_xml = xml.elements.to_a('parent').first
                if !parent_xml
                    raise Invalid, "required child element 'parent' of #{self} not found"
                end
                @parent_link = parent.child_by_name("link[@name=\"#{parent_xml.text}\"]", Link)
            end
            @parent_link
        end

        # The joint's child link
        #
        # @raise [Invalid] if the parent link is not declared or could not be
        #   found
        # @return [Link]
        def child_link
            if !@child_link
                child_xml = xml.elements.to_a('child').first
                if !child_xml
                    raise Invalid, "required child element 'child' of #{self} not found"
                end
                @child_link = parent.child_by_name("link[@name=\"#{child_xml.text}\"]", Link)
            end
            @child_link
        end

        AXIS_CLASSES = Hash[
            'revolute' => [RevoluteAxis],
            'revolute2' => [RevoluteAxis, RevoluteAxis],
            'gearbox' => [RevoluteAxis],
            'prismatic' => [Axis],
            'ball' => [RevoluteAxis, RevoluteAxis],
            'universal' => [RevoluteAxis, RevoluteAxis],
            'piston' => [Axis, RevoluteAxis]
        ]

        # Returns information about this joint's main axis
        #
        # @return [Axis]
        def axis
            if axis_class = AXIS_CLASSES[type]
                child_by_name('axis', axis_class[0])
            else
                raise NotImplementedError, "joint type #{type} not implemented"
            end
        end
    end
end
