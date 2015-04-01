require 'sdf/test'

describe SDF::XML do
    def models_dir
        File.join(File.dirname(__FILE__), 'data', 'models')
    end

    before do
        @model_path = SDF::XML.model_path
        SDF::XML.model_path = [models_dir]
    end
    after do
        SDF::XML.model_path = @model_path
        SDF::XML.clear_cache
    end

    describe "load_from_model_name" do
        it "loads a gazebo model from name" do            
            model = SDF::Model.load_from_model_name("simple_model")
            assert_equal('simple test model', model.name)
        end
        it "returns the latest SDF version if max_version is nil" do                
            model= SDF::Model.load_from_model_name("versioned_model")
            assert_equal('versioned model 1.5', model.name)
        end
        it "returns the latest version matching max_version if provided" do
            model = SDF::Model.load_from_model_name("versioned_model",130)
            assert_equal('versioned model 1.3', model.name)
        end
        it "raises if the version constraint is not matched" do
            assert_raises(SDF::XML::UnavailableSDFVersionInModel) do
                SDF::Model.load_from_model_name("versioned_model",0)
            end                
        end
    end

    describe "#each_link" do
        it "does not yield anything if the model has no link" do
            root = SDF::Model.new(REXML::Document.new("<model></model>").root)
            assert root.enum_for(:each_link).to_a.empty?
        end
        it "yields the links otherwise" do
            root = SDF::Model.new(REXML::Document.new("<model><link name=\"0\" /><link name=\"1\" /></model>").root)

            links = root.enum_for(:each_link).to_a
            assert_equal 2, links.size
            links.each do |l|
                assert_kind_of SDF::Link, l
                assert_equal root.xml.elements.to_a("link[@name=\"#{l.name}\"]"), [l.xml]
            end
        end
    end

end

