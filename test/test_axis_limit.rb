require 'sdf/test'

module SDF
    describe AxisLimit do
        describe "#read" do
            it "returns the element's text converted as float if present" do
                xml = REXML::Document.new("<root><test>10</test></root>").root
                limit = AxisLimit.new(xml)
                assert_in_delta 10, limit.read("test", nil), 1e-6
            end
            it "returns the default value if the element is absent" do
                xml = REXML::Document.new("<root />").root
                limit = AxisLimit.new(xml)
                assert_in_delta 10, limit.read("test", 10), 1e-6
            end
        end
    end
end
