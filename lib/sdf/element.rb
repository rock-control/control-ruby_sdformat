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

        # Create a new element
        #
        # @param [REXML::Element] xml the XML element
        # @param [Element] parent the SDF element parent of this one
        def initialize(xml, parent = nil)
            @xml, @parent = xml, parent
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
    end
end

