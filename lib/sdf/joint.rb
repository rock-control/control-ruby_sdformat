module SDF
    class Joint < Element
        xml_tag_name 'joint'

        def initialize(xml, parent = nil)
            super

            @sensors = Array.new

            if parent
                xml.elements.each do |child|
                    case child.name
                    when 'parent'
                        name = child.text.strip
                        if name == 'world'
                            @parent_link = Link::World
                        else
                            @parent_link = parent.find_link_by_name(name)
                        end

                        if !@parent_link
                            raise Invalid, "joint #{self} specifies #{name} as its parent link, but this link does not exist, existing links: #{parent.each_link.map(&:name).join(", ")}"
                        end
                    when 'child'
                        name = child.text.strip
                        if name == 'world'
                            @child_link = Link::World
                        else
                            @child_link  = parent.find_link_by_name(name)
                        end
                        if !@child_link
                            raise Invalid, "joint #{self} specifies #{name} as its child link, but this link does not exist, existing links: #{parent.each_link.map(&:name).join(", ")}"
                        end
                    when 'sensor'
                        @sensors << Sensor.new(child, self)
                    end
                end

                if !parent_link
                    raise Invalid, "joint element #{self} does not have the required <parent></parent> tag"
                elsif !child_link
                    raise Invalid, "joint element #{self} does not have the required <child></child> tag"
                end
            end
        end

        # The joint type
        def type
            if t = xml.attributes['type']
                t
            else
                raise Invalid, "expected attribute 'type' missing on #{self}"
            end
        end

        # Enumerates this joint's sensors
        #
        # @yieldparam [Sensor] sensor
        def each_sensor(&block)
            @sensors.each(&block)
        end

        # The model's pose w.r.t. its parent
        #
        # @return [Array<Float>]
        def pose
            Conversions.pose_to_eigen(xml.elements["pose"])
        end

        # The joint's parent link
        #
        # @raise [Invalid] if the parent link is not declared or could not be
        #   found
        # @return [Link]
        attr_reader :parent_link

        # The joint's child link
        #
        # @raise [Invalid] if the parent link is not declared or could not be
        #   found
        # @return [Link]
        attr_reader :child_link

        # Returns the axis of rotation for revolute joints or the axis of
        # translation for prismatic joints
        #
        # @return [Eigen::Vector3]
        def axis
            child_by_name('axis', Axis)
        end

        # Compute this joint's transform based on the joint value(s)
        #
        # @return [Isometry3]
        def transform_for(value, value2 = nil, xyz = self.axis.xyz)
            p = Eigen::Isometry3.new
            if type == 'revolute'
                p.rotate(Eigen::Quaternion.from_angle_axis(value, xyz))
            elsif type == 'prismatic'
                p.translate(xyz * value)
            elsif AXIS_CLASSES.has_key?(type)
                raise NotImplementedError, "joint type #{type} not implemented"
            else
                raise ArgumentError, "invalid joint type #{type}"
            end
            return p
        end

        def each_frame
            return enum_for(__method__) if !block_given?
            xml.elements.to_a('frame').each do |frame_xml|
                yield(Frame.new(frame_xml, self))
            end
        end
    end
end
