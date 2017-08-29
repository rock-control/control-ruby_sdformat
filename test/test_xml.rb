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
            assert_equal 22, models.size

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
        it "validates that the file is a XML file" do
            assert_raises(SDF::XML::InvalidXML) do
                SDF::XML.load_sdf(File.join(models_dir, "not_xml.xml"))
            end
        end
        it "validates that the file has a root" do
            assert_raises(SDF::XML::NotSDF) do
                SDF::XML.load_sdf(File.join(models_dir, "no_root.xml"))
            end
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

        describe "the include tag" do
            describe "URI validation and included model validation" do
                it "raises if it does not find an uri element" do
                    full_path = File.join(invalid_models_dir, "include_without_uri", "model.sdf")
                    exception = assert_raises(SDF::XML::InvalidXML) do
                        SDF::XML.load_sdf(full_path)
                    end
                    assert_equal "while loading #{full_path}: no uri element in include",
                        exception.message
                end
                it "raises if it the URI refers to a specific file" do
                    full_path = File.join(invalid_models_dir, "include_with_specific_file_in_uri", "model.sdf")
                    exception = assert_raises(ArgumentError) do
                        SDF::XML.load_sdf(full_path)
                    end
                    assert_equal "while loading #{full_path}: does not know how to resolve an explicit file in a model:// URI inside an include",
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

            it "reports the mapping from on-disk model path to in-SDF model path in metadata" do
                _, metadata = SDF::XML.load_sdf(
                    File.join(models_dir, 'includes_at_each_level', 'model.sdf'),
                    metadata: true)

                model_full_path = File.expand_path(File.join(
                    'data', 'models', 'simple_model', 'model.sdf'), __dir__)
                expected = [
                    'w::child_of_world',
                    'w::model::child_of_model',
                    'w::model::model_in_model::child_of_model_in_model',
                    'root_model::child_of_root_model',
                    'root_model::model_in_root_model::child_of_model_in_root_model'
                ]

                assert_equal [model_full_path], metadata['includes'].keys
                assert_equal expected.sort,
                    metadata['includes'][model_full_path].sort
            end

            it "handles a include tag directly under root" do
                sdf = SDF::XML.load_sdf(File.join(models_dir, 'include_directly_under_root', 'model.sdf'))
                assert sdf.elements["/sdf/model[@name='root_model']"]
            end

            describe "a toplevel model include" do
                it "adds the included model as child of a toplevel world element" do
                    sdf = SDF::XML.load_sdf(File.join(models_dir, 'includes_at_each_level', 'model.sdf'))
                    assert sdf.elements["/sdf/world/model[@name='child_of_world']"]
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
                it "sets the name attribute on the included tree" do
                    sdf = SDF::XML.load_sdf(File.join(models_dir, "model_that_replaces_name_in_include", "model.sdf"))
                    model = sdf.elements.enum_for(:each, 'sdf/world/model').first
                    assert_equal "new_name", model.attributes['name']
                end
            end

            describe "a model included in another model" do
                def sdf_includes_at_each_level
                    SDF::XML.load_sdf(File.join(models_dir, 'includes_at_each_level', 'model.sdf'))
                end

                def sdf_model_in_model_that_replaces_pose_in_include
                    SDF::XML.load_sdf(File.join(models_dir, 'model_in_model_that_replaces_pose_in_include', 'model.sdf'))
                end

                it "processes it if the parent model is root of a world" do
                    sdf = sdf_includes_at_each_level
                    assert sdf.elements["/sdf/world/model[@name='model']/link[@name='child_of_model::link']"]
                end
                it "processes it if the parent model is itself child of another model that is child of a world" do
                    sdf = sdf_includes_at_each_level
                    assert sdf.elements["/sdf/world/model[@name='model']/link[@name='model_in_model::child_of_model_in_model::link']"]
                end
                it "processes it if the parent model is toplevel" do
                    sdf = sdf_includes_at_each_level
                    assert sdf.elements["/sdf/model[@name='root_model']/link[@name='child_of_root_model::link']"]
                end
                it "processes it if the parent model is itself child of a toplevel model" do
                    sdf = sdf_includes_at_each_level
                    assert sdf.elements["/sdf/model[@name='root_model']/link[@name='model_in_root_model::child_of_model_in_root_model::link']"]
                end

                it "namespaces a joints parent link" do
                    sdf = sdf_model_in_model_that_replaces_pose_in_include
                    joint_without_pose = sdf.elements[
                        'sdf/world/model/joint[@name="model_with_pose::joint_without_pose"]"']
                    assert_equal "model_with_pose::link_with_pose",
                        joint_without_pose.elements['parent'].text
                end
                it "namespaces a joints child link" do
                    sdf = sdf_model_in_model_that_replaces_pose_in_include
                    joint_without_pose = sdf.elements[
                        'sdf/world/model/joint[@name="model_with_pose::joint_without_pose"]"']
                    assert_equal "model_with_pose::link_without_pose",
                        joint_without_pose.elements['child'].text
                end

                it "adds a pose tag to links without poses to reflect the include pose" do
                    sdf = sdf_model_in_model_that_replaces_pose_in_include
                    link_pose = sdf.elements[
                        'sdf/world/model/link[@name="model_with_pose::link_without_pose"]/pose"']
                    link_pose = SDF::Conversions.pose_to_eigen(link_pose)
                    expected_pose = SDF::Conversions.pose_to_eigen("1 0 3 0 0 0.1")
                    assert_approx_equals expected_pose, link_pose
                end
                it "adds a pose tag to joints without poses to reflect the include pose" do
                    sdf = sdf_model_in_model_that_replaces_pose_in_include
                    joint_pose = sdf.elements[
                        'sdf/world/model/joint[@name="model_with_pose::joint_without_pose"]/pose"']
                    joint_pose = SDF::Conversions.pose_to_eigen(joint_pose)
                    expected_pose = SDF::Conversions.pose_to_eigen("1 0 3 0 0 0.1")
                    assert_approx_equals expected_pose, joint_pose
                end

                it "transforms a links's pose with the include pose" do
                    sdf = sdf_model_in_model_that_replaces_pose_in_include
                    link_pose = sdf.elements[
                        'sdf/world/model/link[@name="model_with_pose::link_with_pose"]/pose"']
                    link_pose = SDF::Conversions.pose_to_eigen(link_pose)
                    expected_pose = SDF::Conversions.pose_to_eigen("1 0 3 0 0 0.1") *
                        SDF::Conversions.pose_to_eigen("1 0 1 0 0 1")
                    assert_approx_equals expected_pose, link_pose
                end

                it "transforms a joint's pose with the include pose" do
                    sdf = sdf_model_in_model_that_replaces_pose_in_include
                    joint_pose = sdf.elements[
                        'sdf/world/model/joint[@name="model_with_pose::joint_with_pose"]/pose"']
                    joint_pose = SDF::Conversions.pose_to_eigen(joint_pose)
                    expected_pose = SDF::Conversions.pose_to_eigen("1 0 3 0 0 0.1") *
                        SDF::Conversions.pose_to_eigen("2 1 2 0 0 2")
                    assert_approx_equals expected_pose, joint_pose
                end
            end

            describe "caching" do
                it "uses the cache when loading the includes" do
                    flexmock(SDF::XML).should_receive(:model_from_name).once.pass_thru
                    SDF::XML.load_sdf(File.join(models_dir, "model_with_includes", "model.sdf"))
                end
                it "does not modify the cached included XML tree when replacing the pose" do
                    sdf = SDF::XML.load_sdf(File.join(models_dir, "model_that_replaces_pose_in_include", "model.sdf"))
                    sdf = SDF::Root.new(sdf.root)
                    sdf = SDF::XML.model_from_name("model_with_pose", sdf.version)
                    model = sdf.elements.enum_for(:each, 'sdf/model/pose').first
                    assert_equal "1 1 1 1 1 1", model.text
                end
                it "does not modify the cached included XML tree when replacing static" do
                    sdf = SDF::XML.load_sdf(File.join(models_dir, "model_that_replaces_static_in_include", "model.sdf"))
                    sdf = SDF::Root.new(sdf.root)
                    sdf = SDF::XML.model_from_name("model_with_static", sdf.version)
                    model = sdf.elements.enum_for(:each, 'sdf/model/static').first
                    assert_equal "false", model.text
                end
                it "does not modify the cached included XML tree when replacing the model name" do
                    sdf = SDF::XML.load_sdf(File.join(models_dir, "model_that_replaces_name_in_include", "model.sdf"))
                    sdf = SDF::Root.new(sdf.root)
                    sdf = SDF::XML.model_from_name("model_with_name", sdf.version)
                    model = sdf.elements.enum_for(:each, 'sdf/model').first
                    assert_equal "name", model.attributes['name']
                end
            end
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
            sdf1 = SDF::XML.model_from_name('simple_model', flatten: false)
            sdf2 = SDF::XML.model_from_name('simple_model', flatten: false)
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
        it "raises if the model cannot be found" do
            exception = assert_raises(SDF::XML::NoSuchModel) do
                SDF::XML.model_from_name('does_not_exist')
            end
            expected = /cannot find model does_not_exist in path .*. You probably want to update the GAZEBO_MODEL_PATH environment variable, or set SDF.model_path explicitely/
            assert_match expected, exception.message
        end
        it "raises if the model can be found, but not for the expected version" do
            exception = assert_raises(SDF::XML::UnavailableSDFVersionInModel) do
                SDF::XML.model_from_name('versioned_model', 100)
            end
            assert_equal "gazebo model in #{File.join(models_dir, 'versioned_model')} does not offer a SDF file matching version 100", exception.message
        end
    end
end

