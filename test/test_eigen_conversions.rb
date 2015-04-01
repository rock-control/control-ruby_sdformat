require 'sdf/test'

module SDF
    module EigenConversions
        describe "pose_to_eigen" do
            attr_reader :obj

            it "parses a pose into a Eigen vector and quaternion" do
                xml = REXML::Document.new("<pose>1 2 3 0 -0 90</pose>").root
                v, q = EigenConversions.pose_to_eigen(xml)
                assert Eigen::Vector3.new(1, 2, 3).approx?(v)
                assert Eigen::Quaternion.from_angle_axis(Math::PI/2, Eigen::Vector3.UnitZ).approx?(q)
            end

            it "returns identity if given nil" do
                v, q = EigenConversions.pose_to_eigen(nil)
                assert Eigen::Vector3.new(0, 0, 0).approx?(v)
                assert Eigen::Quaternion.Identity.approx?(q)
            end
        end
    end
end

