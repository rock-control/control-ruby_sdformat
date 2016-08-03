module SDF
    class Link < Element
        xml_tag_name 'link'

        # Enumerates this link's sensors
        #
        # @yieldparam [Sensor] sensor
        def each_sensor
            return enum_for(__method__) if !block_given?
            xml.elements.each('sensor') do |element|
                yield(Sensor.new(element, self))
            end
        end

        # The model's pose w.r.t. its parent
        #
        # @return [Array<Float>]
        def pose
            Conversions.pose_to_eigen(xml.elements["pose"])
        end

        # Check if link is kinematic
        #
        #
        def kinematic
            if kinematic = xml.elements["kinematic"]
                return Conversions.to_boolean(kinematic)
            end
            return false
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
            inertial = Inertial.new(pose, mass, Eigen::MatrixX.from_a([ixx,ixy,ixz, ixy,iyy,iyz, ixz,iyz,izz], 3, 3, false))
            inertial
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
            return default
        end
    end
end
