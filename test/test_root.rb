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
            model = root.xml.elements.enum_for(:each, 'model').first
            assert_equal('simple test model', model.attributes['name'])
        end
        it "returns the latest SDF version if max_version is nil" do                
            root = SDF::Root.load_from_model_name("versioned_model")
            model = root.xml.elements.enum_for(:each, 'model').first
            assert_equal('versioned model 1.5', model.attributes['name'])
        end
        it "returns the latest version matching max_version if provided" do
            root = SDF::Root.load_from_model_name("versioned_model",130)
            model = root.xml.elements.enum_for(:each, 'model').first
            assert_equal('versioned model 1.3', model.attributes['name'])
        end
        it "raises if the version constraint is not matched" do
            assert_raises(SDF::XML::UnavailableSDFVersionInModel) do
                SDF::Root.load_from_model_name("versioned_model",0)
            end                
        end
    end
    
    describe "load" do
        it "loads a SDF file if given a path" do
            root = SDF::Root.load(File.join(models_dir, "simple_model", "model.sdf"))
            model = root.xml.elements.enum_for(:each, 'model').first
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
        it "calls load_from_model_name if given a URI" do
            version = flexmock
            flexmock(SDF::Root).should_receive(:load_from_model_name).once.with('model_in_uri', version).and_return(obj = flexmock)
            assert_equal obj, SDF::Root.load('model://model_in_uri', version)
        end
    end

    describe "each_world" do
        it "does not yield anything if no worlds are defined" do
            root = SDF::Root.new(REXML::Document.new("<sdf></sdf>").root)
            assert root.each_world.to_a.empty?
        end
        it "yields the worlds otherwise" do
            root = SDF::Root.new(REXML::Document.new("<sdf><world name=\"w0\" /><world name=\"w1\"><world name=\"recursive_should_be_ignored\" /></world></sdf>").root)

            worlds = root.each_world.to_a
            assert_equal 2, worlds.size
            worlds.each do |w|
                assert_kind_of SDF::World, w
                assert_equal root.xml.elements.to_a("world[@name=\"#{w.name}\"]"), [w.xml]
            end
        end
    end

    describe "each_model" do
        it "does not yield anything if no models are defined" do
            root = SDF::Root.new(REXML::Document.new("<sdf></sdf>").root)
            assert root.enum_for(:each_model).to_a.empty?
        end
        it "yields the models otherwise" do
            root = SDF::Root.new(REXML::Document.new("<sdf><model name=\"w0\" /><model name=\"w1\"><model name=\"recursive_should_be_ignored\" /></model></sdf>").root)

            models = root.enum_for(:each_model).to_a
            assert_equal 2, models.size
            models.each do |w|
                assert_kind_of SDF::Model, w
                assert_equal root.xml.elements.to_a("model[@name=\"#{w.name}\"]"), [w.xml]
            end
        end
        it "enumerates models within a world if recursive is set" do
            root = SDF::Root.new(REXML::Document.new("<sdf><world name=\"w\"><model name=\"child_model\"/></world><model name=\"root_model\"/></sdf>").root)

            models = root.each_model(recursive: true).to_a
            assert_equal 2, models.size
            models.each do |w|
                assert_kind_of SDF::Model, w
                assert %w{child_model root_model}.include?(w.name)
                assert_equal root.xml.elements.to_a("//model[@name=\"#{w.name}\"]"), [w.xml]
            end
        end
    end
end

