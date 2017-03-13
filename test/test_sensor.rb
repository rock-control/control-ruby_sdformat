require 'sdf/test'

module SDF
    describe Sensor do
        describe "#update_rate" do
            it "returns the rate as integer" do
                xml = REXML::Document.new("<sensor><update_rate>22</update_rate></sensor>").root
                sensor = Sensor.new(xml)
                p = sensor.update_rate
                assert p.integer?
                assert_equal 22, p
            end
            it "returns nil if the rate is not defined" do
                xml = REXML::Document.new("<sensor/>").root
                sensor = Sensor.new(xml)
                assert_nil sensor.update_rate
            end
        end

        describe "#update_period" do
            it "returns the period in seconds" do
                xml = REXML::Document.new("<sensor><update_rate>22</update_rate></sensor>").root
                sensor = Sensor.new(xml)
                assert_in_delta (1.0/22.0), sensor.update_period, 1e-6
            end
            it "returns nil if the rate is not defined" do
                xml = REXML::Document.new("<sensor/>").root
                sensor = Sensor.new(xml)
                assert_nil sensor.update_period
            end
        end
    end
end
