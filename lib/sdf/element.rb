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
    end
end
