module SDF
    class AxisLimit < Element
        # @api private
        def read(element_name, default_value)
            if element = xml.elements[element_name]
                Float(element.text)
            else
                default_value
            end
        end

        def lower
            read('lower', nil)
        end

        def upper
            read('upper', nil)
        end

        def effort
            read('effort', nil)
        end

        def velocity
            read('velocity', nil)
        end
    end

    class AngularAxisLimit < AxisLimit
        def lower
            super * Math::PI / 180
        end

        def upper
            super * Math::PI / 180
        end

        def velocity
            super * Math::PI / 180
        end
    end
end

