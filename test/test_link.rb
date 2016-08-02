require 'sdf/test'

module SDF
    describe Link do
        describe "#pose" do
            it "returns the link's pose" do
                xml = REXML::Document.new("<link><pose>1 2 3 0 0 2</pose></link>").root
                link = Link.new(xml)
                p = link.pose
                assert Eigen::Vector3.new(1, 2, 3).approx?(p.translation)
                assert Eigen::Quaternion.from_angle_axis(2, Eigen::Vector3.UnitZ).approx?(p.rotation)
            end

            it "returns the link's inertial" do
                xml = REXML::Document.new("<link><pose>1 2 3 0 0 2</pose><inertial><pose>1 1.2 3 0 0 2</pose><mass>350.5</mass></inertial></link>").root
                link = Link.new(xml)
                i = link.inertial
                assert 350.5, i.mass
                assert Eigen::Vector3.new(1, 1.2, 3).approx?(i.pose.translation)
                assert Eigen::Quaternion.from_angle_axis(2, Eigen::Vector3.UnitZ).approx?(i.pose.rotation)
                assert Eigen::MatrixX.from_a([1,0,0, 0,1,0, 0,0,1], 3, 3, false), i.inertia
            end

            it "returns the link's inertia" do
                xml = REXML::Document.new("<link><pose>1 2 3 0 0 2</pose><inertial><mass>350.5</mass><inertia><ixx>100</ixx><ixy>1</ixy><ixz>2</ixz><iyy>150</iyy><iyz>3</iyz><izz>200</izz></inertia></inertial></link>").root
                link = Link.new(xml)
                i = link.inertial
                assert 350.5, i.mass
                assert Eigen::Vector3.new(0, 0, 0).approx?(i.pose.translation)
                assert Eigen::Quaternion.Identity.approx?(i.pose.rotation)
                assert Eigen::MatrixX.from_a([100,1,2, 1,150,3, 2,3,200], 3, 3, false), i.inertia
            end

            it "returns the link's default inertial" do
                xml = REXML::Document.new("<link><pose>1 2 3 0 0 2</pose></link>").root
                link = Link.new(xml)
                i = link.inertial
                assert 1, i.mass
                assert Eigen::Vector3.new(0,0,0).approx?(i.pose.translation)
                assert Eigen::Quaternion.Identity.approx?(i.pose.rotation)
                assert Eigen::MatrixX.from_a([1,0,0, 0,1,0, 0,0,1], 3, 3, false), i.inertia
            end
        end
    end
end
