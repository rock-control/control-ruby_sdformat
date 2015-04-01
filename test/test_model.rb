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

    describe "#each_joint" do
        it "does not yield anything if the model has no joint" do
            root = SDF::Model.new(REXML::Document.new("<model></model>").root)
            assert root.enum_for(:each_joint).to_a.empty?
        end
        it "yields the joints otherwise" do
            root = SDF::Model.new(REXML::Document.new("<model><joint name=\"0\" /><joint name=\"1\" /></model>").root)

            joints = root.enum_for(:each_joint).to_a
            assert_equal 2, joints.size
            joints.each do |l|
                assert_kind_of SDF::Joint, l
                assert_equal root.xml.elements.to_a("joint[@name=\"#{l.name}\"]"), [l.xml]
            end
        end
    end
    
    describe "#static?" do
        it "returns false unless specified otherwise" do
            xml = REXML::Document.new("<model />").root
            assert !SDF::Model.new(xml).static?
        end
        it "returns true if a static tag contains 1" do
            xml = REXML::Document.new("<model><static>1</static></model>").root
            assert SDF::Model.new(xml).static?
        end
        it "returns true if a static tag contains 0" do
            xml = REXML::Document.new("<model><static>0</static></model>").root
            assert !SDF::Model.new(xml).static?
        end
        it "raises Invalid for any other value" do
            xml = REXML::Document.new("<model><static>false</static></model>").root
            assert_raises(SDF::Invalid) do
                SDF::Model.new(xml).static?
            end
        end
    end

    describe "#pose" do
        it "returns the model's pose" do
            xml = REXML::Document.new("<model><pose>1 2 3 0 0 90</pose></model>").root
            model = SDF::Model.new(xml)
            v, q = model.pose
            assert Eigen::Vector3.new(1, 2, 3).approx?(v)
            assert Eigen::Quaternion.from_angle_axis(Math::PI / 2, Eigen::Vector3.UnitZ).approx?(q)
        end
    end
end

