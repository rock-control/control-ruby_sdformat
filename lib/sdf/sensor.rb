module SDF
    # Base class for sensors
    #
    # Note that one would usually never get a "plain" sensor, only one of its
    # subclasses
    class Sensor < Element
        xml_tag_name 'sensor'

        # In SDF. there exists a sensor-specific block for each sensor type
        # (e.g. a sensor/ray element will contain the information specific to
        # 'ray' sensors). This is this element
        #
        # @return [REXML::Element]
        attr_reader :sensor_info

        def initialize(xml, parent = nil)
            super
            @sensor_info = xml.elements[type]
        end

        # The sensor type
        def type
            return xml.attributes['type']
        end

        # The sensor's pose w.r.t. its parent
        #
        # @return [Array<Float>]
        def pose
            Conversions.pose_to_eigen(xml.elements["pose"])
        end

        # The sensor's update period in seconds, if specified
        #
        # @return [Float,nil]
        # @see update_rate
        def update_period
            if rate = update_rate
                1.0 / rate
            end
        end

        # The sensor's update rate in Hz, if specified
        #
        # @return [Integer,nil]
        # @see update_period
        def update_rate
            if update_rate = xml.elements['update_rate']
                Integer(update_rate.text)
            end
        end
    end
end
