module SDF
    # Representation of a world's spherical coordinates
    class SphericalCoordinates < Element
        xml_tag_name "spherical_coordinates"

        # Create a new element
        #
        # @param [REXML::Element] xml the XML element
        # @param [Element] parent the SDF element parent of this one
        def initialize(xml = REXML::Element.new(self.class.xml_tag_name), parent = nil)
            super

            @latitude_deg = @longitude_deg = nil
        end

        # The spherical model used
        def surface_model
            if model = xml.elements["surface_model"]
                model.text
            else
                "WGS-84"
            end
        end

        # The local latitude in degrees
        def latitude_deg
            if @latitude_deg
                @latitude_deg
            elsif model = xml.elements["latitude_deg"]
                result = Float(model.text)
                if model.text =~ /\.(\d{5,})$/
                    raise Invalid,
                          "Gazebo truncates spherical_coordinates/latitude_deg and spherical_coordinates/longitude_deg to 4 decimals, cannot have #{::Regexp.last_match(1).size}"
                end

                @latitude_deg = result
            else
                raise Invalid, "no latitude defined"
            end
        end

        # The local longitude in degrees
        def longitude_deg
            if @longitude_deg
                @longitude_deg
            elsif model = xml.elements["longitude_deg"]
                result = Float(model.text)
                if model.text =~ /\.(\d{5,})$/
                    raise Invalid,
                          "Gazebo truncates spherical_coordinates/latitude_deg and spherical_coordinates/longitude_deg to 4 decimals, cannot have #{::Regexp.last_match(1).size}"
                end

                @longitude_deg = result
            else
                raise Invalid, "no longitude defined"
            end
        end

        # The local elevation
        def elevation
            if model = xml.elements["elevation"]
                Float(model.text)
            else
                0
            end
        end

        # Relative heading of the local frame w.r.t. the global frame
        def heading
            if model = xml.elements["heading_deg"]
                Float(model.text) * Math::PI / 180
            else
                0
            end
        end

        # Guess the UTM zone that contains these coordinates
        def default_utm_zone
            zone = GeoUtm::UTMZones.calc_utm_default_zone(latitude_deg, longitude_deg)
            [GeoUtm::UTMZones.zone_number_from_zone(zone),
             !!GeoUtm::UTMZones.northern_hemisphere?(zone)]
        end

        UTM = Struct.new :easting, :northing, :zone, :zone_north do
            def north?
                !!zone_north
            end
        end

        # Convert the coordinates in corresponding UTM coordinates
        #
        # @return [GeoUtm::UTM]
        def utm(zone: nil, north: nil)
            if zone
                zone_number = zone
            else
                default_zone = GeoUtm::UTMZones.calc_utm_default_zone(latitude_deg,
                                                                      longitude_deg)
                zone_number, zone_letter = GeoUtm::UTMZones.split_zone(default_zone)
            end

            zone_letter ||= GeoUtm::UTMZones.calc_utm_default_letter(latitude_deg)

            unless north.nil?
                is_north = GeoUtm::UTMZones.northern_hemisphere?(zone_letter)
                if north && !is_north
                    force_north = true
                    zone_letter = "N"
                elsif !north && is_north
                    force_south = true
                    zone_letter = "M"
                end
            end

            utm = GeoUtm::LatLon.new(latitude_deg, longitude_deg)
                                .to_utm(zone: "#{zone_number}#{zone_letter}")

            result = UTM.new(utm.e, utm.n,
                             zone_number, GeoUtm::UTMZones.northern_hemisphere?(zone_letter))
            if force_north
                result.northing -= 10_000_000
            elsif force_south
                result.northing += 10_000_000
            end
            result
        end
    end
end
