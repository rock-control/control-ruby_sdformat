require 'sdf/test'

describe SDF::XML do
    def models_dir
        File.join(File.dirname(__FILE__), 'data', 'models')
    end
    def invalid_models_dir
        File.join(File.dirname(__FILE__), 'data', 'invalid_models')
    end

    before do
        @model_path = SDF::XML.model_path
        SDF::XML.model_path = [models_dir]
    end
    after do
        SDF::XML.model_path = @model_path
        SDF::XML.clear_cache
    end

    describe "load_gazebo_model" do
        it "loads a gazebo model" do
            sdf = SDF::XML.load_gazebo_model(File.join(models_dir, "simple_model"))
            model = sdf.elements.enum_for(:each, 'sdf/model').first
            assert_equal('simple test model', model.attributes['name'])
        end
        it "returns the latest SDF version if max_version is nil" do
            sdf = SDF::XML.load_gazebo_model(File.join(models_dir, "versioned_model"))
            model = sdf.elements.enum_for(:each, 'sdf/model').first
            assert_equal('versioned model 1.5', model.attributes['name'])
        end
        it "handles unversioned config files" do
            sdf = SDF::XML.load_gazebo_model(File.join(models_dir, "model_without_version"))
            model = sdf.elements.enum_for(:each, 'sdf/model').first
            assert_equal('model without version', model.attributes['name'])
        end
        it "returns the latest version matching max_version if provided" do
            sdf = SDF::XML.load_gazebo_model(
                File.join(models_dir, "versioned_model"),
                130)
            model = sdf.elements.enum_for(:each, 'sdf/model').first
            assert_equal('versioned model 1.3', model.attributes['name'])
        end
        it "raises if the version constraint is not matched" do
            assert_raises(SDF::XML::UnavailableSDFVersionInModel) do
                SDF::XML.load_gazebo_model(
                    File.join(models_dir, "versioned_model"),
                    0)
            end
        end
    end

    describe "gazebo_models" do
        it "loads all models available in the path" do
            models = SDF::XML.gazebo_models
            assert_equal 21, models.size

            assert(sdf = models['simple_model'])
            model = sdf.elements.enum_for(:each, 'sdf/model').first
            assert_equal('simple test model', model.attributes['name'])

            assert(sdf = models['versioned_model'])
            model = sdf.elements.enum_for(:each, 'sdf/model').first
            assert_equal('versioned model 1.5', model.attributes['name'])
        end

        it "versions the models" do
            # Load up-to-date models to make sure we re-load for specific
            # versions
            SDF::XML.gazebo_models
            models = SDF::XML.gazebo_models(130)
            assert_equal 2, models.size

            assert(sdf = models['versioned_model'])
            model = sdf.elements.enum_for(:each, 'sdf/model').first
            assert_equal('versioned model 1.3', model.attributes['name'])
        end
    end

    describe "load_sdf" do
        it "loads a SDF file" do
            sdf = SDF::XML.load_sdf(File.join(models_dir, "simple_model", "model.sdf"))
            model = sdf.elements.enum_for(:each, 'sdf/model').first
            assert_equal('simple test model', model.attributes['name'])
        end
        it "validates that the file is a SDF file" do
            assert_raises(SDF::XML::NotSDF) do
                SDF::XML.load_sdf(File.join(models_dir, "not_sdf.xml"))
            end
        end
        it "validates that the file exists" do
            assert_raises(Errno::ENOENT) do
                SDF::XML.load_sdf(File.join(models_dir, "does_not_exist.xml"))
            end
        end

        it "handles the include tags" do
            sdf = SDF::XML.load_sdf(File.join(models_dir, "model_with_includes", "model.sdf"))
            models = sdf.elements.enum_for(:each, 'sdf/world/model').to_a
            model_names = models.map { |el| el.attributes['name'] }.sort
            assert_equal(
                ['simple test model'],
                model_names.sort)
        end
        it "raises if it does not find an uri element" do
            full_path = File.join(invalid_models_dir, "include_without_uri", "model.sdf")
            exception = assert_raises(SDF::XML::InvalidXML) do
                SDF::XML.load_sdf(full_path)
            end
            assert_equal "while loading #{full_path}: no uri element in include",
                exception.message
        end
        it "raises if it finds an unexpected element as child of the 'include' path" do
            full_path = File.join(invalid_models_dir, "include_with_invalid_element", "model.sdf")
            exception = assert_raises(SDF::XML::InvalidXML) do
                SDF::XML.load_sdf(full_path)
            end
            assert_equal "while loading #{full_path}: unexpected element 'invalid' found as child of an include",
                exception.message
        end
        it "processes includes in a toplevel world element" do
            sdf = SDF::XML.load_sdf(File.join(models_dir, 'includes_at_each_level', 'model.sdf'))
            assert sdf.elements["/sdf/world/model[@name='child_of_world']"]
        end
        it "processes includes in a model child of a toplevel world element" do
            sdf = SDF::XML.load_sdf(File.join(models_dir, 'includes_at_each_level', 'model.sdf'))
            assert sdf.elements["/sdf/world/model/model[@name='child_of_model']"]
        end
        it "processes includes in the model child of a model child of a toplevel world element" do
            sdf = SDF::XML.load_sdf(File.join(models_dir, 'includes_at_each_level', 'model.sdf'))
            assert sdf.elements["/sdf/world/model/model/model[@name='child_of_model_in_model']"]
        end
        it "processes includes in a toplevel model element" do
            sdf = SDF::XML.load_sdf(File.join(models_dir, 'includes_at_each_level', 'model.sdf'))
            assert sdf.elements["/sdf/model[@name='root_model']/model[@name='child_of_root_model']"]
        end
        it "processes includes in a model child of a toplevel model element" do
            sdf = SDF::XML.load_sdf(File.join(models_dir, 'includes_at_each_level', 'model.sdf'))
            assert sdf.elements["/sdf/model[@name='root_model']/model/model[@name='child_of_model_in_root_model']"]
        end

        it "accepts relative paths as URIs, and resolve them from the SDF file's own path" do
            sdf = SDF::XML.load_sdf(File.join(models_dir, "include_relative_path", "model.sdf"))
            assert_equal 'simple test model', sdf.root.elements['//model'].attributes['name']
        end
        it "raises if the uri is neither a model:// nor an existing directory" do
            full_path = File.join(invalid_models_dir, "include_invalid_path", "model.sdf")
            exception = assert_raises(ArgumentError) do
                SDF::XML.load_sdf(full_path)
            end
            assert_equal "while loading #{full_path}: URI /does/not/exist is neither a model:// URI nor an existing directory",
                exception.message
        end
        it "raises if the included SDF has more than one model" do
            full_path = File.join(invalid_models_dir, "include_multiple_models", "model.sdf")
            exception = assert_raises(ArgumentError) do
                SDF::XML.load_sdf(full_path)
            end
            assert_equal "while loading #{full_path}: expected included resource model://composite_model to have exactly one model",
                exception.message
        end
        it "uses the cache when loading the includes" do
            flexmock(SDF::XML).should_receive(:model_from_name).once.pass_thru
            SDF::XML.load_sdf(File.join(models_dir, "model_with_includes", "model.sdf"))
        end
        it "injects the include/pose element in the included tree" do
            sdf = SDF::XML.load_sdf(File.join(models_dir, "model_with_new_pose_in_include", "model.sdf"))
            model = sdf.elements.enum_for(:each, 'sdf/world/model/pose').first
            assert_equal "1 0 3 0 5 0", model.text
        end
        it "replaces an existing pose element by the include/pose element" do
            sdf = SDF::XML.load_sdf(File.join(models_dir, "model_that_replaces_pose_in_include", "model.sdf"))
            model = sdf.elements.enum_for(:each, 'sdf/world/model/pose').first
            assert_equal "1 0 3 0 5 0", model.text
        end
        it "does not modify the cached included XML tree when replacing the pose" do
            sdf = SDF::XML.load_sdf(File.join(models_dir, "model_that_replaces_pose_in_include", "model.sdf"))
            sdf = SDF::Root.new(sdf.root)
            sdf = SDF::XML.model_from_name("model_with_pose", sdf.version)
            model = sdf.elements.enum_for(:each, 'sdf/model/pose').first
            assert_equal "1 1 1 1 1 1", model.text
        end
        it "injects the include/static element in the included tree" do
            sdf = SDF::XML.load_sdf(File.join(models_dir, "model_with_new_static_in_include", "model.sdf"))
            model = sdf.elements.enum_for(:each, 'sdf/world/model/static').first
            assert_equal "true", model.text
        end
        it "replaces an existing static element by the include/static element" do
            sdf = SDF::XML.load_sdf(File.join(models_dir, "model_that_replaces_static_in_include", "model.sdf"))
            model = sdf.elements.enum_for(:each, 'sdf/world/model/static').first
            assert_equal "true", model.text
        end
        it "does not modify the cached included XML tree when replacing static" do
            sdf = SDF::XML.load_sdf(File.join(models_dir, "model_that_replaces_static_in_include", "model.sdf"))
            sdf = SDF::Root.new(sdf.root)
            sdf = SDF::XML.model_from_name("model_with_static", sdf.version)
            model = sdf.elements.enum_for(:each, 'sdf/model/static').first
            assert_equal "false", model.text
        end
        it "sets the name attribute on the included tree" do
            sdf = SDF::XML.load_sdf(File.join(models_dir, "model_that_replaces_name_in_include", "model.sdf"))
            model = sdf.elements.enum_for(:each, 'sdf/world/model').first
            assert_equal "new_name", model.attributes['name']
        end
        it "does not modify the cached included XML tree when replacing the model name" do
            sdf = SDF::XML.load_sdf(File.join(models_dir, "model_that_replaces_name_in_include", "model.sdf"))
            sdf = SDF::Root.new(sdf.root)
            sdf = SDF::XML.model_from_name("model_with_name", sdf.version)
            model = sdf.elements.enum_for(:each, 'sdf/model').first
            assert_equal "name", model.attributes['name']
        end

        it "resolves relative paths to a file in <uri> tags" do
            sdf = SDF::XML.load_sdf(File.join(models_dir, "model_with_relative_file_in_uri", "model.sdf"))
            uri = sdf.elements.to_a('//uri').first
            assert_equal(File.join(models_dir, 'model_with_relative_file_in_uri', 'visual.dae'), uri.text)
        end
        it "resolves relative paths to other model's paths in <uri> tags" do
            sdf = SDF::XML.load_sdf(File.join(models_dir, "model_with_plain_model_path_in_uri", "model.sdf"))
            uri = sdf.elements.to_a('//uri').first
            assert_equal(File.join(models_dir, 'simple_model'), uri.text)
        end
        it "properly resolves relative paths in <uri> tags from included models" do
            sdf = SDF::XML.load_sdf(File.join(models_dir, "model_that_includes_a_model_with_relative_paths", "model.sdf"))
            uri = sdf.elements.to_a('//uri').first
            assert_equal(File.join(models_dir, 'model_with_relative_uris', 'visual.dae'), uri.text)
        end
        it "resolves model:// in <uri> tags" do
            sdf = SDF::XML.load_sdf(File.join(models_dir, "model_with_model_uris", "model.sdf"))
            uri = sdf.elements.to_a('//uri').first
            assert_equal(File.join(models_dir, 'simple_model', 'visual.dae'), uri.text)
        end
    end

    describe "model_from_name" do
        it "resolves and returns the raw model" do
            sdf = SDF::XML.model_from_name('simple_model')
            model = sdf.elements.enum_for(:each, 'sdf/model').first
            assert_equal('simple test model', model.attributes['name'])
        end
        it "returns the model matching the SDF version" do
            sdf = SDF::XML.model_from_name('versioned_model', 130)
            model = sdf.elements.enum_for(:each, 'sdf/model').first
            assert_equal('versioned model 1.3', model.attributes['name'])
        end
        it "caches the result" do
            sdf1 = SDF::XML.model_from_name('simple_model')
            sdf2 = SDF::XML.model_from_name('simple_model')
            assert_same sdf1, sdf2
        end
        it "caches the result in a version-aware way" do
            sdf1 = SDF::XML.model_from_name('versioned_model')
            sdf2 = SDF::XML.model_from_name('versioned_model', 130)
            model = sdf1.elements.enum_for(:each, 'sdf/model').first
            assert_equal('versioned model 1.5', model.attributes['name'])
            model = sdf2.elements.enum_for(:each, 'sdf/model').first
            assert_equal('versioned model 1.3', model.attributes['name'])
        end
    end
end

