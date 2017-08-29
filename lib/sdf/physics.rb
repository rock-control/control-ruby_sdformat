module SDF
    # Physics engine parameters
    class Physics < Element
        xml_tag_name 'physics'

        # The selected physics engine
        def type
            return xml.attributes['type']
        end

        # The world's update period, in realtime, in simulated seconds
        #
        # @return [Float,nil] nil if the update period is not explicitely set.
        #   The SDF spec does not specify a default update period
        def simulation_time_update_period
            if realtime_period = real_time_update_period
                realtime_period * real_time_factor
            end
        end

        # The simulated time / realtime factor
        #
        # @return [Float,nil]
        # @see update_rate
        def real_time_factor
            if factor = xml.elements['real_time_factor']
                Float(factor.text)
            else
                1
            end
        end

        # The world's update rate in realtime, in Hz, if specified
        #
        # @return [Integer,nil]
        # @see update_period
        def real_time_update_rate
            if real_time_update_rate = xml.elements['real_time_update_rate']
                Integer(real_time_update_rate.text)
            end
        end

        # The world's update period, in realtime seconds, if specified
        #
        # @return [Float,nil]
        # @see update_rate
        def real_time_update_period
            if rate = real_time_update_rate
                1.0 / rate
            end
        end
    end
end

