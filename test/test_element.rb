# frozen_string_literal: true

require 'sdf/test'

module SDF
    describe Element do
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

        describe '#full_name' do
            attr_reader :xml
            before do
                @xml = REXML::Document.new(
                    '<root><parent name="p"><child name="c" /></parent></root>'
                ).root
            end

            it "is changed if the element's name is modified" do
                xml = REXML::Document.new('<a name="a"><e name="p" /></a>')
                element = Element.new(xml.root)
                child   = Element.new(xml.root.elements.first, element)
                assert_equal 'a::p', child.full_name
                child.name = 'child'
                assert_equal 'a::child', child.full_name
                element.name = 'parent'
                assert_equal 'parent::child', child.full_name
            end

            it 'returns the name if there is no parent' do
                xml = REXML::Document.new('<e name="p" />')
                element = Element.new(xml.root)
                assert_equal 'p', element.full_name
            end

            it 'returns the name if the parent has no name' do
                xml = REXML::Document.new('<root><e name="p" /></root>')
                # This is because all SDF elements have a name except the root
                root = Element.new(xml.root)
                element = Element.new(xml.root.elements.first, root)
                assert_equal 'p', element.full_name
            end

            it 'combines the parent and child names to form the full name, recursively' do
                xml = REXML::Document.new(
                    '<root><e name="0"><e name="1"><e name="p" /></e></e></root>'
                )
                # This is because all SDF elements have a name except the root
                el0 = Element.new(xml.root.elements.first)
                el1 = Element.new(el0.xml.elements.first, el0)
                elp = Element.new(el1.xml.elements.first, el1)
                assert_equal '0::1::p', elp.full_name
            end

            it 'stops at the provided root if given' do
                xml = REXML::Document.new(
                    '<root><e name="0"><e name="1"><e name="p" /></e></e></root>'
                )
                # This is because all SDF elements have a name except the root
                el0 = Element.new(xml.root.elements.first)
                el1 = Element.new(el0.xml.elements.first, el0)
                elp = Element.new(el1.xml.elements.first, el1)
                assert_equal 'p', elp.full_name(root: el1)
                assert_equal '1::p', elp.full_name(root: el0)
            end
        end

        describe '#child_by_name' do
            describe 'required child' do
                attr_reader :element
                before do
                    xml = REXML::Document.new(
                        '<e name="0"><e name="0.1" /><e name="0.2" /></e>'
                    )
                    @element = Element.new(xml.root)
                end

                it 'creates a child of the specified class if there is exactly '\
                   'one XML element matching' do
                    child_xml = element.xml.elements.to_a('e[@name=0.1]').first
                    klass = flexmock
                    klass.should_receive(:new)
                         .with(child_xml, element)
                         .once.and_return(obj = flexmock)
                    assert_equal obj, element.child_by_name('e[@name=0.1]', klass)
                end
                it 'raises if there is more than one match' do
                    assert_raises(Invalid) do
                        element.child_by_name('e', flexmock)
                    end
                end
                it 'raises if there is no match and required is true' do
                    assert_raises(Invalid) do
                        element.child_by_name('does_not_exist', flexmock)
                    end
                end
                it 'creates a new element if there is no match and required is false' do
                    klass = flexmock
                    klass.should_receive(:new)
                         .with(FlexMock.any, element)
                         .once.and_return(obj = flexmock)
                    assert_equal(obj, element
                                      .child_by_name('default_element', klass, false))
                end
            end
        end

        describe '#==' do
            it 'returns true if the two elements have the same XML and class' do
                xml = REXML::Document.new
                el0 = Element.new(xml)
                el1 = Element.new(xml)
                assert_equal el0, el1
            end
            it 'returns false if the two elements have different classes' do
                xml = REXML::Document.new
                el0 = Element.new(xml)
                el1 = Class.new(Element) { @xml_tag_name = nil }.new(xml)
                refute_equal el0, el1
            end
            it 'returns false if the two elements have different xml' do
                el0 = Element.new(REXML::Document.new)
                el1 = Element.new(REXML::Document.new)
                refute_equal el0, el1
            end
            it 'returns false for an arbitrary object' do
                el0 = Element.new(REXML::Document.new)
                refute_equal Object.new, el0
            end
        end

        describe 'behaviour as hash key' do
            it 'matches as a hash key against an object that '\
               'has the same class and xml' do
                hash = {}
                xml = REXML::Document.new
                el0 = Element.new(xml)
                hash[el0] = 10
                assert_equal 10, hash[Element.new(xml)]
            end
            it 'does not match as a hash key against an object that '\
               'has the same class and but different xml' do
                hash = {}
                el0 = Element.new(REXML::Document.new)
                el1 = Element.new(REXML::Document.new)
                hash[el0] = 10
                assert !hash.key?(el1)
            end
            it 'does not match as a hash key against an object that '\
               'has different class and same xml' do
                hash = {}
                xml = REXML::Document.new
                el0 = Element.new(xml)
                el1 = Class.new(Element) { @xml_tag_name = nil }.new(xml)
                hash[el0] = 10
                assert !hash.key?(el1)
            end
        end

        describe '#make_parents' do
            it 'assigns the parent attribute to the root if given '\
               'a direct child of the root' do
                xml = REXML::Document.new('<sdf><world name="p" /></sdf>')
                root = SDF::Root.new(xml.root)
                world = World.new(xml.elements.to_a('sdf/world').first)
                assert !world.parent
                world.make_parents(root)
                assert_same root, world.parent
            end
            it 'creates intermediate elements if needed' do
                xml = REXML::Document.new(
                    '<sdf><world name="p"><model name="m" /></world></sdf>'
                )
                root = SDF::Root.new(xml.root)
                model = SDF::Model.new(xml.elements.to_a('sdf/world/model').first)
                model.make_parents(root)
                assert_kind_of(World, model.parent)
                assert_equal xml.elements.to_a('sdf/world').first, model.parent.xml
                assert_equal root, model.parent.parent
            end
        end

        describe '#make_root' do
            before do
                xml = REXML::Document.new(<<-EOXML)
                <sdf><world name="w">
                    <model name="m">
                        <link name="l" />
                    </model>
                </world></sdf>
                EOXML
                @root = SDF::Root.new(xml.root)
                @model = @root.each_world.first.each_model.first
                @new_root = @model.make_root
            end
            it 'returns a Root object that only includes the element' do
                assert_equal 'm', @new_root.each_model.first.name
            end
            it 'deep-copies the XML tree' do
                link = @new_root.each_model.first.each_link.first
                link.xml.attributes['name'] = 'deep_copy_test'
                assert_equal 'l', @root.each_world.first.each_model
                                       .first.each_link.first.name
            end
            it 'ignores a root without a version' do
                assert_nil @new_root.version
            end
            it 'ignores a node without a root' do
                xml = REXML::Document.new('<world name="w"><model name="m" /></world>')
                world = SDF::World.new(xml.root)
                new_root = world.each_model.first.make_root
                assert_nil new_root.version
            end
            it 'copies the SDF version of the root if it has one' do
                @root.xml.attributes['version'] = '1.6'
                new_root = @model.make_root
                assert_equal 160, new_root.version
            end
        end

        describe '#find_by_name' do
            def self.common(context)
                context.it 'returns nil if the model does not exist' do
                    assert_nil @root.find_by_name('does_not_exist')
                end

                context.it 'returns a model that is not a direct descendant '\
                           'of the root' do
                    assert_equal @root.xml.elements["//model[@name='model']"],
                                 @root.find_by_name('w::model').xml
                end

                context.it 'returns a model that is a direct descendant of the root' do
                    assert_equal @root.xml.elements["//model[@name='root_model']"],
                                 @root.find_by_name('root_model').xml
                end
            end

            describe 'on flattened models' do
                before do
                    @root = SDF::Root.load_from_model_name('includes_at_each_level',
                                                           flatten: true)
                end
                common(self)

                it 'resolves recursively within the models as well' do
                    expected = @root.xml.elements[
                        "//link[@name='model_in_model::child_of_model_in_model::link']"
                    ]
                    assert_equal expected, @root.find_by_name(
                        'w::model::model_in_model::child_of_model_in_model::link'
                    ).xml
                end
            end

            describe 'on non-flattened models' do
                before do
                    @root = SDF::Root.load_from_model_name('includes_at_each_level',
                                                           flatten: false)
                end
                common(self)

                it 'resolves recursively within the models as well' do
                    expected = @root.xml.elements[
                        "//model[@name='child_of_model_in_model']/link[@name='link']"
                    ]
                    assert_equal expected, @root.find_by_name(
                        'w::model::model_in_model::child_of_model_in_model::link'
                    ).xml
                end
            end
        end
    end
end
