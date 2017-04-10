require 'sdf/test'

module SDF
    describe SphericalCoordinates do
        it "rejects longitudes with more than 4 decimals" do
            coord = SphericalCoordinates.from_string("<spherical_coordinates><longitude_deg>0.12345</longitude_deg></spherical_coordinates>")
            e = assert_raises(Invalid) do
                coord.longitude_deg
            end
            assert_equal "Gazebo truncates spherical_coordinates/latitude_deg and spherical_coordinates/longitude_deg to 4 decimals, cannot have 5",
                e.message
        end

        it "rejects latitudes with more than 4 decimals" do
            coord = SphericalCoordinates.from_string("<spherical_coordinates><latitude_deg>0.12345</latitude_deg></spherical_coordinates>")
            e = assert_raises(Invalid) do
                coord.latitude_deg
            end
            assert_equal "Gazebo truncates spherical_coordinates/latitude_deg and spherical_coordinates/longitude_deg to 4 decimals, cannot have 5",
                e.message
        end

        it "returns WGS84 as the default surface model" do
            coord = SphericalCoordinates.new
            assert_equal "WGS-84", coord.surface_model
        end
        it "returns the surface model content as-is" do
            coord = SphericalCoordinates.from_string("<spherical_coordinates><surface_model>TEST</surface_model></spherical_coordinates>")
            assert_equal "TEST", coord.surface_model
        end
        it "returns the latitude in degrees" do
            coord = SphericalCoordinates.from_string("<spherical_coordinates><latitude_deg>2.2</latitude_deg></spherical_coordinates>")
            assert_equal 2.2, coord.latitude_deg
        end
        it "raises if the latitude is not defined" do
            coord = SphericalCoordinates.new
            assert_raises(Invalid) do
                coord.latitude_deg
            end
        end
        it "returns the longitude in degrees" do
            coord = SphericalCoordinates.from_string("<spherical_coordinates><longitude_deg>2.2</longitude_deg></spherical_coordinates>")
            assert_equal 2.2, coord.longitude_deg
        end
        it "raises if the longitude is not defined" do
            coord = SphericalCoordinates.new
            assert_raises(Invalid) do
                coord.longitude_deg
            end
        end
        it "returns the elevation" do
            coord = SphericalCoordinates.from_string("<spherical_coordinates><elevation>2.2</elevation></spherical_coordinates>")
            assert_equal 2.2, coord.elevation
        end
        it "returns a zero elevation by default" do
            coord = SphericalCoordinates.new
            assert_equal 0, coord.elevation
        end
        it "returns the heading in radians" do
            coord = SphericalCoordinates.from_string("<spherical_coordinates><heading_deg>2.2</heading_deg></spherical_coordinates>")
            assert_equal 2.2 * Math::PI / 180, coord.heading
        end
        it "returns a zero heading by default" do
            coord = SphericalCoordinates.new
            assert_equal 0, coord.heading
        end

        describe "#default_utm_zone" do
            it "returns the zone and northing" do
                coord = SphericalCoordinates.from_string(
                    "<spherical_coordinates>
                        <latitude_deg>48.8580</latitude_deg>
                        <longitude_deg>2.2946</longitude_deg>
                     </spherical_coordinates>")
                assert_equal [31, true], coord.default_utm_zone

                coord = SphericalCoordinates.from_string(
                    "<spherical_coordinates>
                        <latitude_deg>-22.9707</latitude_deg>
                        <longitude_deg>-43.1823</longitude_deg>
                     </spherical_coordinates>")
                assert_equal [23, false], coord.default_utm_zone
            end
        end

        describe "the UTM conversion functionality" do
            it "automatically pick the UTM zone if given none - north hemishpere" do
                coord = SphericalCoordinates.from_string(
                    "<spherical_coordinates>
                        <latitude_deg>48.8580</latitude_deg>
                        <longitude_deg>2.2946</longitude_deg>
                     </spherical_coordinates>")
                utm = coord.utm
                assert_in_delta 448_258.92, utm.easting, 0.01
                assert_in_delta 5_411_910.37, utm.northing, 0.01
                assert utm.north?
            end
            it "automatically pick the UTM zone if given none - south hemishpere" do
                coord = SphericalCoordinates.from_string(
                    "<spherical_coordinates>
                        <latitude_deg>-22.9707</latitude_deg>
                        <longitude_deg>-43.1823</longitude_deg>
                     </spherical_coordinates>")
                utm = coord.utm
                assert_in_delta 686_342.74, utm.easting, 0.01
                assert_in_delta 7_458_569.92, utm.northing, 0.01
                refute utm.north?
            end

            it "allows to force the UTM zone if given one" do
                coord = SphericalCoordinates.from_string(
                    "<spherical_coordinates>
                        <latitude_deg>-22.9662</latitude_deg>
                        <longitude_deg>-41.9912</longitude_deg>
                     </spherical_coordinates>")
                utm = coord.utm(zone: 23)
                assert_in_delta 808_522, utm.easting, 1
                assert_in_delta 7_457_059, utm.northing, 1
                refute utm.north?
            end

            it "allows to force the UTM northing if given (force north when south)" do
                coord = SphericalCoordinates.from_string(
                    "<spherical_coordinates>
                        <latitude_deg>-0.001</latitude_deg>
                        <longitude_deg>-51.0810</longitude_deg>
                     </spherical_coordinates>")
                utm = coord.utm
                assert_in_delta 490_986, utm.easting, 1
                assert_in_delta 9_999_889, utm.northing, 1
                refute utm.north?

                utm = coord.utm(north: true)
                assert_in_delta 490_986, utm.easting, 1
                assert_in_delta -111, utm.northing, 1
                assert utm.north?
            end
        end
    end
end

