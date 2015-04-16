require 'sdf/test'

module SDF
    describe Element do
        describe "#full_name" do
            attr_reader :xml
            before do
                @xml = REXML::Document.new("<root><parent name=\"p\"><child name=\"c\" /></parent></root>").
                    root
            end

            it "returns the name if there is no parent" do
                xml = REXML::Document.new("<e name=\"p\" />")
                element = Element.new(xml.root)
                assert_equal 'p', element.full_name
            end

            it "returns the name if the parent has no name" do
                xml = REXML::Document.new("<root><e name=\"p\" /></root>")
                # This is because all SDF elements have a name except the root
                root = Element.new(xml.root)
                element = Element.new(xml.root.elements.first, root)
                assert_equal 'p', element.full_name
            end

            it "combines the parent and child names to form the full name, recursively" do
                xml = REXML::Document.new("<root><e name=\"0\"><e name=\"1\"><e name=\"p\" /></e></e></root>")
                # This is because all SDF elements have a name except the root
                el0 = Element.new(xml.root.elements.first)
                el1 = Element.new(el0.xml.elements.first, el0)
                elp = Element.new(el1.xml.elements.first, el1)
                assert_equal '0::1::p', elp.full_name
            end
        end

        describe "#child_by_name" do
            describe "required child" do
                attr_reader :element
                before do
                    xml = REXML::Document.new("<e name=\"0\"><e name=\"0.1\" /><e name=\"0.2\" /></e>")
                    @element = Element.new(xml.root)
                end

                it "creates a child of the specified class if there is exactly one XML element matching" do
                    child_xml = element.xml.elements.to_a('e[@name=0.1]').first
                    klass = flexmock
                    klass.should_receive(:new).
                        with(child_xml, element).
                        once.
                        and_return(obj = flexmock)
                    assert_equal obj, element.child_by_name('e[@name=0.1]', klass)
                end
                it "raises if there is more than one match" do
                    assert_raises(Invalid) do
                        element.child_by_name('e', flexmock)
                    end
                end
                it "raises if there is no match and required is true" do
                    assert_raises(Invalid) do
                        element.child_by_name('does_not_exist', flexmock)
                    end
                end
                it "creates a new element if there is no match and required is false" do
                    klass = flexmock
                    klass.should_receive(:new).
                        with(FlexMock.any, element).
                        once.
                        and_return(obj = flexmock)
                    assert_equal obj, element.child_by_name('default_element', klass, false)
                end
            end
        end

        describe "#==" do
            it "returns true if the two elements have the same XML and class" do
                xml = REXML::Document.new
                el0 = Element.new(xml)
                el1 = Element.new(xml)
                assert_equal el0, el1
            end
            it "returns false if the two elements have different classes" do
                xml = REXML::Document.new
                el0 = Element.new(xml)
                el1 = Class.new(Element).new(xml)
                refute_equal el0, el1
            end
            it "returns false if the two elements have different xml" do
                el0 = Element.new(REXML::Document.new)
                el1 = Element.new(REXML::Document.new)
                refute_equal el0, el1
            end
            it "returns false for an arbitrary object" do
                el0 = Element.new(REXML::Document.new)
                refute_equal Object.new, el0
            end
        end

        describe "behaviour as hash key" do
            it "matches as a hash key against an object that has the same class and xml" do
                hash = Hash.new
                xml = REXML::Document.new
                el0 = Element.new(xml)
                hash[el0] = 10
                assert_equal 10, hash[Element.new(xml)]
            end
            it "does not match as a hash key against an object that has the same class and but different xml" do
                hash = Hash.new
                el0 = Element.new(REXML::Document.new)
                el1 = Element.new(REXML::Document.new)
                hash[el0] = 10
                assert !hash.has_key?(el1)
            end
            it "does not match as a hash key against an object that has different class and same xml" do
                hash = Hash.new
                xml = REXML::Document.new
                el0 = Element.new(xml)
                el1 = Class.new(Element).new(xml)
                hash[el0] = 10
                assert !hash.has_key?(el1)
            end
        end

        describe "#make_parents" do
            it "assigns the parent attribute to the root if given a direct child of the root" do
                xml = REXML::Document.new("<sdf><world name=\"p\" /></sdf>")
                root = SDF::Root.new(xml.root)
                world = World.new(xml.elements.to_a('sdf/world').first)
                assert !world.parent
                world.make_parents(root)
                assert_same root, world.parent
            end
            it "creates intermediate elements if needed" do
                xml = REXML::Document.new("<sdf><world name=\"p\"><model name=\"m\" /></world></sdf>")
                root = SDF::Root.new(xml.root)
                model = SDF::Model.new(xml.elements.to_a('sdf/world/model').first)
                model.make_parents(root)
                assert_kind_of(World, model.parent)
                assert_equal xml.elements.to_a('sdf/world').first, model.parent.xml
                assert_equal root, model.parent.parent
            end
        end
    end
end

