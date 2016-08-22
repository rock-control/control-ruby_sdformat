require 'sdf/test'

module SDF
    module Conversions
        describe "pose_to_eigen" do
            attr_reader :obj

            it "parses a pose into a Eigen vector and quaternion" do
                xml = REXML::Document.new("<pose>1 2 3 0 -0 2</pose>").root
                p = Conversions.pose_to_eigen(xml)
                assert Eigen::Vector3.new(1, 2, 3).approx?(p.translation)
                assert Eigen::Quaternion.from_angle_axis(2, Eigen::Vector3.UnitZ).approx?(p.rotation)
            end

            it "returns identity if given nil" do
                p = Conversions.pose_to_eigen(nil)
                assert Eigen::Vector3.new(0, 0, 0).approx?(p.translation)
                assert Eigen::Quaternion.Identity.approx?(p.rotation)
            end
        end

        describe 'to_boolean' do
            it "returns true for the 'true' string" do
                xml = REXML::Document.new("<b>true</b>").root
                assert_same true, Conversions.to_boolean(xml)

                xml = REXML::Document.new("<b> true </b>").root
                assert_same true, Conversions.to_boolean(xml)
            end
            it "returns false for the 'false' string" do
                xml = REXML::Document.new("<b>false</b>").root
                assert_same false, Conversions.to_boolean(xml)
            end
            it "returns true for the '1' string" do
                xml = REXML::Document.new("<b>1</b>").root
                assert_same true, Conversions.to_boolean(xml)
            end
            it "returns false for the '0' string" do
                xml = REXML::Document.new("<b>0</b>").root
                assert_same false, Conversions.to_boolean(xml)
            end
            it "raises Invalid for anything else" do
                xml = REXML::Document.new("<b>bla</b>").root
                assert_raises(Invalid) do
                    Conversions.to_boolean(xml)
                end
            end
        end
    end
end

