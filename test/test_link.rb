require 'sdf/test'

module SDF
    describe Link do
        describe "#pose" do
            it "returns the link's pose" do
                xml = REXML::Document.new("<link><pose>1 2 3 0 0 90</pose></link>").root
                link = Link.new(xml)
                p = link.pose
                assert Eigen::Vector3.new(1, 2, 3).approx?(p.translation)
                assert Eigen::Quaternion.from_angle_axis(Math::PI / 2, Eigen::Vector3.UnitZ).approx?(p.rotation)
            end
        end
    end
end

