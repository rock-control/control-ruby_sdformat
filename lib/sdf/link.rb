module SDF
    class Link < Element
        xml_tag_name 'link'

        # Enumerates this link's sensors
        #
        # @yieldparam [Sensor] sensor
        def each_sensor
            return enum_for(__method__) if !block_given?
            xml.elements.each('sensor') do |element|
                yield(Sensor.new(element, self))
            end
        end

        # The model's pose w.r.t. its parent
        #
        # @return [Array<Float>]
        def pose
            Conversions.pose_to_eigen(xml.elements["pose"])
        end
    end
end
