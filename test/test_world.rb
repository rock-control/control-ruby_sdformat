require 'sdf/test'

module SDF
    describe World do
        describe "#each_model" do
            it "does not yield anything if the world has no models" do
                root = SDF::World.new(REXML::Document.new("<world />").root)
                assert root.enum_for(:each_model).to_a.empty?
            end
            it "yields the models otherwise" do
                root = SDF::World.new(REXML::Document.new("<world><model name=\"0\" /><model name=\"1\" /></world>").root)

                models = root.enum_for(:each_model).to_a
                assert_equal 2, models.size
                models.each do |l|
                    assert_kind_of SDF::Model, l
                    assert_equal root.xml.elements.to_a("model[@name=\"#{l.name}\"]"), [l.xml]
                end
            end
        end
    end
end
