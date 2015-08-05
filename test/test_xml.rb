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
            assert_equal 11, models.size

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
            models = sdf.elements.enum_for(:each, 'sdf/model').to_a
            model_names = models.map { |el| el.attributes['name'] }.sort
            assert_equal(
                ['first model', 'second model', 'simple test model'],
                model_names.sort)
        end
        it "injects tags children of include into the included model" do
            sdf = SDF::XML.load_sdf(File.join(models_dir, "model_with_new_tags_in_include", "model.sdf"))
            model = sdf.elements.enum_for(:each, 'sdf/model/pose').first
            assert_equal "1 0 3 0 5 0", model.text
        end
        it "replaces tags in the included model by tags present in the include tag" do
            sdf = SDF::XML.load_sdf(File.join(models_dir, "model_with_overriding_tags_in_include", "model.sdf"))
            model = sdf.elements.enum_for(:each, 'sdf/model/pose').first
            # The included model has a non-ID pose
            assert_equal "0 0 0 0 0 0", model.text
        end
        it "resolves relative paths in <uri> tags" do
            sdf = SDF::XML.load_sdf(File.join(models_dir, "model_with_relative_uris", "model.sdf"))
            uri = sdf.elements.to_a('//uri').first
            assert_equal(File.join(models_dir, 'model_with_relative_uris', 'visual.dae'), uri.text)
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

