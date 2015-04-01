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
        describe "#parent_link" do
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
    end
end

