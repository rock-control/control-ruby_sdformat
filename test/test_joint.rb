require 'sdf/test'

module SDF
    describe Joint do
        attr_reader :xml, :model, :joint
        before do
            @xml = REXML::Document.new(<<-EOD
                    <model>
                        <link name="parent_l" />
                        <link name="child_l" />
                        <joint name="joint">
                            <parent>parent_l</parent>
                            <child>child_l</child>
                        </joint>
                        <joint name="attached_to_world_from_parent">
                            <parent>world</parent>
                            <child>child_l</child>
                        </joint>
                        <joint name="attached_to_world_from_child">
                            <parent>parent_l</parent>
                            <child>world</child>
                        </joint>
                    </model>
                    EOD
            )

            @model = Model.new(xml.root)
            @joint = model.find_joint_by_name("joint")
        end

        describe "#initialize" do
            it "raises Invalid if there is no parent element" do
                xml = REXML::Document.new("<joint><child>test</child></joint>").root
                assert_raises(Invalid) { Joint.new(xml, flexmock(find_link_by_name: Object.new)) }
            end
            it "raises Invalid if there is no child element" do
                xml = REXML::Document.new("<joint><parent>test</parent></joint>").root
                assert_raises(Invalid) { Joint.new(xml, flexmock(find_link_by_name: Object.new)) }
            end
            it "raises Invalid if the specified parent link cannot be found" do
                xml.root.delete_element(model.xml.elements.to_a("link[@name='parent_l']").first)
                assert_raises(Invalid) do
                    Model.new(xml.root)
                end
            end
            it "raises Invalid if the specified child link cannot be found" do
                xml.root.delete_element(model.xml.elements.to_a("link[@name='child_l']").first)
                assert_raises(Invalid) do
                    Model.new(xml.root)
                end
            end
        end

        describe "#type" do
            it "raises Invalid if the type attribute does not exist" do
                xml = REXML::Document.new("<joint />").root
                assert_raises(Invalid) do
                    Joint.new(xml).type
                end
            end
            it "returns the type as a string" do
                xml = REXML::Document.new("<joint type='revolute'/>").root
                assert_equal 'revolute', Joint.new(xml).type
            end
        end

        describe "#pose" do
            it "returns the joint's pose" do
                xml = REXML::Document.new("<joint><pose>1 2 3 0 0 2</pose></joint>").root
                joint = Joint.new(xml)
                p = joint.pose
                assert Eigen::Vector3.new(1, 2, 3).approx?(p.translation)
                assert Eigen::Quaternion.from_angle_axis(2, Eigen::Vector3.UnitZ).approx?(p.rotation)
            end
        end

        describe "#parent_link" do
            it "returns the special World link if the parent link is 'world'" do
                joint = model.find_joint_by_name('attached_to_world_from_parent')
                assert_equal Link::World, joint.parent_link
            end
            it "returns the Link object that is the joint's parent" do
                assert_equal model.find_link_by_name('parent_l'),
                    joint.parent_link
            end
        end
        describe "#child_link" do
            it "returns the special World link if the child link is 'world'" do
                joint = model.find_joint_by_name('attached_to_world_from_child')
                assert_equal Link::World, joint.child_link
            end
            it "returns the Link object that is the joint's child" do
                assert_equal model.find_link_by_name('child_l'),
                    joint.child_link
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
                t = joint.transform_for(1)
                assert_equal Eigen::Vector3.Zero, t.translation
                assert Eigen::Quaternion.from_angle_axis(1, Eigen::Vector3.UnitX).approx?(t.rotation)
            end
            it "computes the transformation of prismatic joints" do
                xml = REXML::Document.new("<joint type='prismatic'><axis><xyz>1 0 0</xyz></axis></joint>").root
                joint = Joint.new(xml)
                t = joint.transform_for(2)
                assert Eigen::Vector3.new(2, 0, 0).approx?(t.translation)
                assert Eigen::Quaternion.Identity.approx?(t.rotation)
            end
        end
    end
end

