module SDF
    module Conversions
        def self.pose_to_xyz_rpy(pose)
            xml = nil
            if pose
                values = parse_number_array(pose, 6)
                xyz = values[0, 3]
                rpy = values[3, 3]
                return xyz, rpy
            else
                return [0, 0, 0], [0, 0, 0]
            end
        end

        # Converts a SDF pose to an eigen vector3 and Quaternion
        #
        # @param [String,#text,nil] pose the pose as "x y z r p y" (as expected in SDF) or
        #   nil, in which case a zero translation and zero rotation are returned
        # @return [Eigen::Isometry3]
        def self.pose_to_eigen(pose)
            xyz, rpy = pose_to_xyz_rpy(pose)

            q = Eigen::Quaternion.from_angle_axis(rpy[2], Eigen::Vector3.UnitZ) *
                Eigen::Quaternion.from_angle_axis(rpy[1], Eigen::Vector3.UnitY) *
                Eigen::Quaternion.from_angle_axis(rpy[0], Eigen::Vector3.UnitX)

            pose = Eigen::Isometry3.new
            pose.translate(Eigen::Vector3.new(*xyz))
            pose.rotate(q)
            return pose
        end

        # Converts an Eigen pose to a SDF pose
        #
        # @return [REXML::Element]
        def self.eigen_to_pose(pose)
            x, y, z = pose.translation.to_a
            yaw, pitch, roll = pose.rotation.to_euler.to_a
            pose = REXML::Element.new("pose")
            pose.text = "#{x} #{y} #{z} #{roll} #{pitch} #{yaw}"
            pose
        end

        # Converts a SDF vector3 to an eigen vector3
        #
        # @param [String,#text,nil] pose the pose as "x y z" (as expected in SDF) or
        #   nil, in which case a zero translation is returned
        # @return [Eigen::Vector3]
        def self.vector3_to_eigen(vector3)
            if vector3
                values = parse_number_array(vector3, 3)
                return Eigen::Vector3.new(*values)
            else
                return Eigen::Vector3.Zero
            end
        end

        # Converts an Eigen vector into a SDF vector3
        def self.eigen_to_vector3(v, element_name = "xyz")
            el = REXML::Element.new(element_name)
            el.text = "#{v.x} #{v.y} #{v.z}"
            el
        end

        # Converts a SDF boolean into a Ruby true/false value
        #
        # @param [String,#text] boolean the SDF boolean ('true','false','0',1')
        # @return [Boolean]
        def self.to_boolean(text)
            if text.respond_to?(:text)
                xml = text
                text = xml.text
            end
            text = text.strip
            if text == 'true' || text == '1'
                true
            elsif text == 'false' || text == '0'
                false
            else
                raise Invalid, invalid_message_with_xpath(xml,
                    "invalid boolean value '#{text}', expected true or false")
            end
        end

        # @api private
        #
        # Parse a XML element or a string that contains a fixed-size array of numbers
        #
        # @param [String,#text] xml_or_text the string or XML element to parse
        # @param [Integer] expected_size the expected number of elements
        # @return [Array<Number>]
        # @raise [Invalid] if some elements are not numbers, or if the array has
        #   less or more elements than expected
        def self.parse_number_array(xml_or_text, expected_size)
            text =
                if xml_or_text.respond_to?(:text)
                    xml = xml_or_text
                    xml_or_text.text
                else
                    xml_or_text
                end

            text = text.strip
            begin
                values = text.split(/\s+/).map { |v| Float(v) }
            rescue ArgumentError
                raise Invalid, invalid_message_with_xpath(xml,
                    "invalid number in '#{text}'")
            end

            unless expected_size == values.size
                raise Invalid, invalid_message_with_xpath(xml,
                    "'#{text}' has #{values.size} entries, expected #{expected_size}")
            end
            values
        end

        # @api private
        #
        # Generate a message for the Invalid exceptions, optionally prepending
        # the XPath of a given XML element if one is indeed given
        #
        # @param [#xpath,nil] xml the element whose XPath should be added, or
        #   nil if none
        # @param [String] message the actual error message
        # @return [String]
        def self.invalid_message_with_xpath(xml, message)
            if xml
                "in #{xml.xpath}: #{message}"
            else
                message
            end
        end

    end
end
