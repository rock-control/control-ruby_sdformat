require 'sdf/test'

module SDF
    module Tools
        describe Pose do
            attr_reader :obj
            before do
                klass = Class.new do
                    attr_accessor :xml
                    include Tools::Pose
                end
                @obj = klass.new
            end

            it "parses a pose into a Eigen vector and quaternion" do
                obj.xml = REXML::Document.new("<root><pose>1 2 3 0 -0 90</pose></root>").root
                v, q = obj.pose
                assert Eigen::Vector3.new(1, 2, 3).approx?(v)
                assert Eigen::Quaternion.from_angle_axis(Math::PI/2, Eigen::Vector3.UnitZ).approx?(q)
            end

            it "returns identity if the pose element is not there" do
                obj.xml = REXML::Document.new("<root />").root
                v, q = obj.pose
                assert Eigen::Vector3.new(0, 0, 0).approx?(v)
                assert Eigen::Quaternion.Identity.approx?(q)
            end
        end
    end
end

