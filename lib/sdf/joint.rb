module SDF
    class Joint < Element
        xml_tag_name "joint"

        def initialize(xml, parent = nil)
            super

            @sensors = []

            return unless parent

            xml.elements.each do |child|
                case child.name
                when "parent"
                    name = child.text.strip
                    @parent_link = if name == "world"
                                       Link::World
                                   else
                                       parent.find_link_by_name(name)
                                   end

                    unless @parent_link
                        raise Invalid, "joint #{self} specifies #{name} as its parent link, but this link does not exist, existing links: #{parent.each_link_with_name.map do |_, name|
                                                                                                                                                name
                                                                                                                                            end.join(', ')}"
                    end
                when "child"
                    name = child.text.strip
                    @child_link = if name == "world"
                                      Link::World
                                  else
                                      parent.find_link_by_name(name)
                                  end
                    unless @child_link
                        raise Invalid, "joint #{self} specifies #{name} as its child link, but this link does not exist, existing links: #{parent.each_link_with_name.map do |_, name|
                                                                                                                                               name
                                                                                                                                           end.join(', ')}"
                    end
                when "sensor"
                    @sensors << Sensor.new(child, self)
                end
            end

            if !parent_link
                raise Invalid,
                      "joint element #{self} does not have the required <parent></parent> tag"
            elsif !child_link
                raise Invalid,
                      "joint element #{self} does not have the required <child></child> tag"
            end
        end

        # The joint type
        def type
            unless t = xml.attributes["type"]
                raise Invalid, "expected attribute 'type' missing on #{self}"
            end

            t
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
            child_by_name("axis", Axis)
        end

        # Compute this joint's transform based on the joint value(s)
        #
        # @return [Isometry3]
        def transform_for(value, _value2 = nil, xyz = axis.xyz)
            p = Eigen::Isometry3.new
            if type == "revolute"
                p.rotate(Eigen::Quaternion.from_angle_axis(value, xyz))
            elsif type == "prismatic"
                p.translate(xyz * value)
            elsif AXIS_CLASSES.has_key?(type)
                raise NotImplementedError, "joint type #{type} not implemented"
            else
                raise ArgumentError, "invalid joint type #{type}"
            end
            p
        end

        def each_frame
            return enum_for(__method__) unless block_given?

            xml.elements.to_a("frame").each do |frame_xml|
                yield(Frame.new(frame_xml, self))
            end
        end
    end
end
