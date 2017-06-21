module SDF
    module Conversions
        def self.pose_to_xyz_rpy(pose)
            if pose
                if pose.respond_to?(:text)
                    pose = pose.text
                end
                values = pose.strip.split(/\s+/).map { |v| Float(v) }
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

        # Converts a SDF vector3 to an eigen vector3
        #
        # @param [String,#text,nil] pose the pose as "x y z" (as expected in SDF) or
        #   nil, in which case a zero translation is returned
        # @return [Eigen::Vector3]
        def self.vector3_to_eigen(vector3)
            if vector3
                if vector3.respond_to?(:text)
                    vector3 = vector3.text
                end
                values = vector3.split(/\s+/).map { |v| Float(v) }
                return Eigen::Vector3.new(*values)
            else
                return Eigen::Vector3.Zero
            end
        end

        # Converts a SDF boolean into a Ruby true/false value
        #
        # @param [String,#text] boolean the SDF boolean ('true','false','0',1')
        # @return [Boolean]
        def self.to_boolean(xml)
            if xml.respond_to?(:text)
                xml = xml.text
            end
            xml = xml.strip
            if xml == 'true' || xml == '1'
                true
            elsif xml == 'false' || xml == '0'
                false
            else
                raise Invalid, "invalid boolean value #{xml}, expected true or false"
            end
        end
    end
end
