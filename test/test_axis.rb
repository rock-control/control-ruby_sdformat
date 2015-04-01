require 'sdf/test'

module SDF
    describe Axis do
        describe "xyz" do
            it "returns the axis coordinates" do
                xml = REXML::Document.new("<axis><xyz>1 2 3</xyz></axis>").root
                v = Axis.new(xml).xyz
                assert Eigen::Vector3.new(1, 2, 3).approx?(v)
            end
        end

        describe "limit" do
            it "creats a tag with defaults if there is none" do
                xml = REXML::Document.new("<axis />").root
                limit = Axis.new(xml).limit
                assert_kind_of AxisLimit, limit
            end
            it "returns the Limit object for the tag" do
                xml = REXML::Document.new("<axis><limit /></axis>").root
                limit = Axis.new(xml).limit
                assert_kind_of AxisLimit, limit
                assert_equal xml.elements['limit'], limit.xml
            end
        end
    end
end

