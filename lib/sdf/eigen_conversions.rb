module SDF
    module EigenConversions
        # Converts a SDF pose to an eigen vector3 and Quaternion
        #
        # @param [String,#text,nil] pose the pose as "x y z r p y" (as expected in SDF) or
        #   nil, in which case a zero translation and zero rotation are returned
        # @return [Eigen::Isometry3]
        def self.pose_to_eigen(pose)
            if pose
                if pose.respond_to?(:text)
                    pose = pose.text
                end
                values = pose.split(/\s+/).map { |v| Float(v) }
                xyz = values[0, 3]
                rpy = values[3, 3].map do |deg|
                    deg * Math::PI / 180
                end

                q = Eigen::Quaternion.from_angle_axis(rpy[2], Eigen::Vector3.UnitZ) *
                    Eigen::Quaternion.from_angle_axis(rpy[1], Eigen::Vector3.UnitY) *
                    Eigen::Quaternion.from_angle_axis(rpy[0], Eigen::Vector3.UnitX)

                pose = Eigen::Isometry3.new
                pose.translate(Eigen::Vector3.new(*xyz))
                pose.rotate(q)
                return pose
            else
                return Eigen::Isometry3.new
            end
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
    end
end
