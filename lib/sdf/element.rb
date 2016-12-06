module SDF
    # Root class for all SDF elements
    #
    # This library is only wrapping the XML representation, not parsing it
    # in-place. This class provides the common API to store and access the
    # underlying XML
    class Element
        # The SDF element that is parent of this one
        #
        # @return [Element,nil] the element, or nil if self is root
        attr_reader :parent

        # The underlying XML element where information about this SDF element is
        # stored
        #
        # @return [REXML::Element]
        attr_reader :xml

        @xml_tag_name = nil

        def self.xml_tag_name(*args)
            if args.empty?
                @xml_tag_name
            else
                @xml_tag_name = args.first
            end
        end

        # Create a new element
        #
        # @param [REXML::Element] xml the XML element
        # @param [Element] parent the SDF element parent of this one
        def initialize(xml, parent = nil)
            xml_tag_name = self.class.xml_tag_name
            if xml_tag_name && xml_tag_name != xml.name
                raise ArgumentError, "expected the XML element to be a '#{xml_tag_name}' tag, but got #{xml}"
            end
            @xml, @parent = xml, parent
        end

        # The element's root
        #
        # @return [Element]
        def root
            obj = self
            while obj.parent
                obj = obj.parent
            end
            obj
        end

        # The model name
        #
        # @return [String]
        def name
            xml.attributes['name']
        end

        # The XPath from the root this element
        #
        # @return [String]
        def xpath
            xml.xpath
        end

        # Create its parent elements until the provided root element is reached
        def make_parents(root)
            xml = self.xml
            if xml.parent == root.xml
                @parent = root
            else
                @parent = self.class.wrap(xml.parent)
                parent.make_parents(root)
            end
        end

        def self.wrap(xml, parent = nil)
            xml_to_class = Hash[
                'world' => World,
                'model' => Model,
                'sdf' => Root,
                'link' => Link,
                'joint' => Joint]
            if klass = xml_to_class[xml.name]
                return klass.new(xml, parent)
            else
                raise NotImplementedError, "don't know how to wrap the #{xml.name} XML element #{xml}"
            end
        end

        def to_s
            xpath
        end

        def full_name
            if (p = parent) && (p_name = p.full_name)
                p_name + '::' + name
            else
                name
            end
        end

        # @api private
        #
        # Gets one of this element's child
        #
        # @param [String] name the child's tag name
        # @param [#new(xml, parent)] class the object that should be
        #   instanciated to represent the child
        # @param [Boolean] required if true, the method will raise if the child
        #   is not present. Otherwise, klass will be instanciated with an empty
        #   XML element
        def child_by_name(name, klass, required = true)
            children = xml.elements.to_a(name)
            if children.empty?
                if required
                    raise Invalid, "expected #{self} to have a #{name} child element, but could not find one"
                else
                    child = xml.add_element(name)
                    return klass.new(child, self)
                end
            elsif children.size > 1
                raise Invalid, "more than one child matching #{name} found on #{self}, was expecting exactly one"
            else
                klass.new(children.first, self)
            end
        end

        def ==(other)
            self.class == other.class &&
                xml == other.xml
        end

        def eql?(other)
            self.class == other.class &&
                xml == other.xml
        end

        def hash
            xml.hash
        end

        # Create a new SDF document where self is the first element inside the
        # <sdf></sdf> element
        def make_root
            Root.make(xml.deep_clone, root.version)
        end
    end
end

