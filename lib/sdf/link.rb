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

        # The link's inertial.
        #
        # @return Inertial struct
        Inertial = Struct.new(:pose, :mass, :inertia)
        def inertial
            m = ixx = iyy = izz = 1
            ixy = ixz = iyz = 0
            pose = Eigen::Isometry3.new
            if xml.elements["inertial"].respond_to?(:text)
                inertial_elements = xml.elements["inertial"]
                if inertial_elements.elements["mass"].respond_to?(:text)
                    mass = inertial_elements.elements["mass"].text{ |v| Float(v) }
                end
                if inertial_elements.elements["inertia"].respond_to?(:text)
                    inertia = inertial_elements.elements["inertia"]
                    if inertia.elements["ixx"].respond_to?(:text)
                        ixx = inertia.elements["ixx"].text{ |v| Float(v) }
                    end
                    if inertia.elements["iyy"].respond_to?(:text)
                        iyy = inertia.elements["iyy"].text{ |v| Float(v) }
                    end
                    if inertia.elements["izz"].respond_to?(:text)
                        izz = inertia.elements["izz"].text{ |v| Float(v) }
                    end
                    if inertia.elements["ixy"].respond_to?(:text)
                        ixy = inertia.elements["ixy"].text{ |v| Float(v) }
                    end
                    if inertia.elements["ixz"].respond_to?(:text)
                        ixz = inertia.elements["ixz"].text{ |v| Float(v) }
                    end
                    if inertia.elements["iyz"].respond_to?(:text)
                        iyz = inertia.elements["iyz"].text{ |v| Float(v) }
                    end
                end
                pose = Conversions.pose_to_eigen(inertial_elements.elements["pose"])
            end
            inertial = Inertial.new(pose, mass, Eigen::MatrixX.from_a([ixx,ixy,ixz, ixy,iyy,iyz, ixz,iyz,izz], 3, 3, false))
            inertial
        end
    end
end
