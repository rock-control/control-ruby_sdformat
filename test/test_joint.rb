require 'sdf/test'

module SDF
    describe Joint do
        attr_reader :model, :joint
        before do
            xml = REXML::Document.new(<<-EOD
                    <model>
                        <link name="parent_l" />
                        <link name="child_l" />
                        <joint name="joint">
                            <parent>parent_l</parent>
                            <child>child_l</child>
                        </joint>
                    </model>
                    EOD
            )

            @model = Model.new(xml.root)
            @joint = model.child_by_name("joint", Joint)
        end

        describe "#type" do
            it "raises Invalid if the type attribute does not exist" do
                xml = REXML::Document.new("<root />").root
                assert_raises(Invalid) do
                    Joint.new(xml).type
                end
            end
            it "returns the type as a string" do
                xml = REXML::Document.new("<root type='revolute'/>").root
                assert_equal 'revolute', Joint.new(xml).type
            end
        end

        describe "#pose" do
            it "returns the joint's pose" do
                xml = REXML::Document.new("<joint><pose>1 2 3 0 0 90</pose></joint>").root
                joint = Joint.new(xml)
                p = joint.pose
                assert Eigen::Vector3.new(1, 2, 3).approx?(p.translation)
                assert Eigen::Quaternion.from_angle_axis(Math::PI / 2, Eigen::Vector3.UnitZ).approx?(p.rotation)
            end
        end

        describe "#parent_link" do
            it "raises Invalid if there is no parent element" do
                xml = REXML::Document.new("<joint />").root
                assert_raises(Invalid) { Joint.new(xml).parent_link }
            end
            it "returns the Link object that is the joint's parent" do
                assert_equal model.child_by_name('link[@name="parent_l"]', Link),
                    joint.parent_link
            end
            it "raises Invalid if the link cannot be found" do
                model.xml.delete_element(model.xml.elements.to_a("link[@name='parent_l']").first)
                assert_raises(Invalid) do
                    joint.parent_link
                end
            end
        end
        describe "#child_link" do
            it "raises Invalid if there is no parent element" do
                xml = REXML::Document.new("<joint />").root
                assert_raises(Invalid) { Joint.new(xml).child_link }
            end
            it "returns the Link object that is the joint's child" do
                assert_equal model.child_by_name('link[@name="child_l"]', Link),
                    joint.child_link
            end
            it "raises Invalid if the link cannot be found" do
                model.xml.delete_element(model.xml.elements.to_a("link[@name='child_l']").first)
                assert_raises(Invalid) do
                    joint.child_link
                end
            end
        end

        describe "axis" do
            it "raises Invalid if there is no axis tag" do
                xml = REXML::Document.new("<joint />").root
                assert_raises(Invalid) do
                    Joint.new(xml).axis
                end
            end
            it "returns an Axis object for the axis tag" do
                xml = REXML::Document.new("<joint><axis /></joint>").root
                joint = Joint.new(xml)
                axis = joint.axis
                assert_kind_of Axis, axis
                assert_same joint, axis.parent
                assert_equal xml.elements['axis'], axis.xml
            end
        end

        describe "transform_for" do
            it "computes the transformation of revolute joints" do
                xml = REXML::Document.new("<joint type='revolute'><axis><xyz>1 0 0</xyz></axis></joint>").root
                joint = Joint.new(xml)
                v, q = joint.transform_for(1)
                assert_equal Eigen::Vector3.Zero, v
                assert Eigen::Quaternion.from_angle_axis(1, Eigen::Vector3.UnitX).approx?(q)
            end
            it "computes the transformation of prismatic joints" do
                xml = REXML::Document.new("<joint type='prismatic'><axis><xyz>1 0 0</xyz></axis></joint>").root
                joint = Joint.new(xml)
                v, q = joint.transform_for(2)
                assert Eigen::Vector3.new(2, 0, 0).approx?(v)
                assert Eigen::Quaternion.Identity.approx?(q)
            end
        end
    end
end

