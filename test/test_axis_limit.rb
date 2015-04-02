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

    describe AngularAxisLimit do
        describe "#upper" do
            it "converts the value to radians" do
                xml = REXML::Document.new("<root><upper>10</upper></root>").root
                assert_equal 10 * Math::PI / 180, AngularAxisLimit.new(xml).upper
            end
        end
        describe "#lower" do
            it "converts the value to radians" do
                xml = REXML::Document.new("<root><lower>10</lower></root>").root
                assert_equal 10 * Math::PI / 180, AngularAxisLimit.new(xml).lower
            end
        end
        describe "#velocity" do
            it "converts the value to radians" do
                xml = REXML::Document.new("<root><velocity>10</velocity></root>").root
                assert_equal 10 * Math::PI / 180, AngularAxisLimit.new(xml).velocity
            end
        end
    end
end
