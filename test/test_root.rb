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
            root = SDF::Root.load_from_model_name("simple_model")
            model = root.xml.elements.enum_for(:each, 'sdf/model').first
            assert_equal('simple test model', model.attributes['name'])
        end
        it "returns the latest SDF version if max_version is nil" do                
            root = SDF::Root.load_from_model_name("versioned_model")
            model = root.xml.elements.enum_for(:each, 'sdf/model').first
            assert_equal('versioned model 1.5', model.attributes['name'])
        end
        it "returns the latest version matching max_version if provided" do
            root = SDF::Root.load_from_model_name("versioned_model",130)
            model = root.xml.elements.enum_for(:each, 'sdf/model').first
            assert_equal('versioned model 1.3', model.attributes['name'])
        end
        it "raises if the version constraint is not matched" do
            assert_raises(SDF::XML::UnavailableSDFVersionInModel) do
                SDF::Root.load_from_model_name("versioned_model",0)
            end                
        end
    end
    
    describe "load" do
        it "loads a SDF file" do
            root = SDF::Root.load(File.join(models_dir, "simple_model", "model.sdf"))
            model = root.xml.elements.enum_for(:each, 'sdf/model').first
            assert_equal('simple test model', model.attributes['name'])
        end
        it "validates that the file is a SDF file" do
            assert_raises(SDF::XML::NotSDF) do
                SDF::Root.load(File.join(models_dir, "not_sdf.xml"))
            end
        end
        it "validates that the file exists" do
            assert_raises(Errno::ENOENT) do
                SDF::Root.load(File.join(models_dir, "does_not_exist.xml"))
            end
        end
        it "load each models direct children from root" do
            root = SDF::Root.load(File.join(models_dir, "model_with_includes", "model.sdf"))
            model_names = [];
            root.each_model do |m|
                model_names << m.name
            end
            assert_equal(['first model', 'second model', 'simple test model'], model_names.sort)
        end
        it "load each models children from parent" do
            root = SDF::Root.load(File.join(models_dir, "model_with_includes", "model.sdf"))
            model_names = [];
            root.each_model_from('sdf') do |m|
                model_names << m.name
            end
            assert_equal(['first model', 'second model', 'simple test model'], model_names.sort)
        end
    end

end

