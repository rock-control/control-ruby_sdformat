module SDF
    class Link < Element
        xml_tag_name "link"

        def initialize(xml, parent = nil)
            super

            @sensors = []
            xml.elements.each do |child|
                @sensors << Sensor.new(child, self) if child.name == "sensor"
            end
        end

        # Enumerates this link's sensors
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

        # Check if link is kinematic
        #
        def kinematic?
            return unless kinematic = xml.elements["kinematic"]

            Conversions.to_boolean(kinematic)
        end

        # The link's inertial.
        #
        # @return Inertial struct
        Inertial = Struct.new(:pose, :mass, :inertia)
        def inertial
            mass = ixx = iyy = izz = 1
            ixy = ixz = iyz = 0
            pose = Eigen::Isometry3.new
            if inertial = xml.elements["inertial"]
                mass = read_float_child_element(inertial, "mass", 1)
                pose = Conversions.pose_to_eigen(inertial.elements["pose"])
                if inertia = inertial.elements["inertia"]
                    ixx = read_float_child_element(inertia, "ixx", 1)
                    iyy = read_float_child_element(inertia, "iyy", 1)
                    izz = read_float_child_element(inertia, "izz", 1)
                    ixy = read_float_child_element(inertia, "ixy", 0)
                    ixz = read_float_child_element(inertia, "ixz", 0)
                    iyz = read_float_child_element(inertia, "iyz", 0)
                end
            end
            Inertial.new(pose, mass,
                         Eigen::MatrixX.from_a([ixx, ixy, ixz, ixy, iyy, iyz, ixz, iyz, izz], 3, 3, false))
        end

        # @api private
        #
        # Read an element whose text can be interpreted as float
        #
        # @param [REXML::Element] the element whose child is looked for
        # @param [String] xpath the xpath of the child element
        # @param [Float] default the default value to be returned if the element is not present
        def read_float_child_element(element, xpath, default)
            if ret = element.elements[xpath]
                return Float(ret.text)
            end

            default
        end

        xml = REXML::Element.new("link")
        xml.attributes["name"] = "__world__"
        World = Link.new(xml).freeze

        def each_frame
            return enum_for(__method__) unless block_given?

            xml.elements.to_a("frame").each do |frame_xml|
                yield(Frame.new(frame_xml, self))
            end
        end
    end
end
