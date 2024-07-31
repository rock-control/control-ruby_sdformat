require "sdf/test"

module SDF
    describe Physics do
        describe "#update_rate" do
            it "returns the rate as integer" do
                xml = REXML::Document.new("<physics><real_time_update_rate>22</real_time_update_rate></physics>").root
                physics = Physics.new(xml)
                p = physics.real_time_update_rate
                assert p.integer?
                assert_equal 22, p
            end
            it "returns nil if the rate is not defined" do
                xml = REXML::Document.new("<physics/>").root
                physics = Physics.new(xml)
                assert_nil physics.real_time_update_rate
            end
        end

        describe "#update_period" do
            it "returns the period in seconds" do
                xml = REXML::Document.new("<physics><real_time_update_rate>22</real_time_update_rate></physics>").root
                physics = Physics.new(xml)
                assert_in_delta (1.0 / 22.0), physics.real_time_update_period, 1e-6
            end
            it "returns nil if the rate is not defined" do
                xml = REXML::Document.new("<physics/>").root
                physics = Physics.new(xml)
                assert_nil physics.real_time_update_period
            end
        end

        describe "#real_time_factor" do
            it "returns the factor as a floating-point value" do
                xml = REXML::Document.new("<physics><real_time_factor>0.1</real_time_factor></physics>").root
                physics = Physics.new(xml)
                assert_in_delta 0.1, physics.real_time_factor, 1e-6
            end
            it "returns 1 if the factor is not defined" do
                xml = REXML::Document.new("<physics/>").root
                physics = Physics.new(xml)
                assert_in_delta 1, physics.real_time_factor, 1e-6
            end
        end

        describe "#simulation_time_update_period" do
            it "returns the period as a floating-point value" do
                xml = REXML::Document.new("<physics><real_time_update_rate>22</real_time_update_rate><real_time_factor>0.1</real_time_factor></physics>").root
                physics = Physics.new(xml)
                assert_in_delta (1.0 / 22.0 * 0.1), physics.simulation_time_update_period,
                                1e-6
            end
            it "returns nil if the update rate is not specified" do
                xml = REXML::Document.new("<physics/>").root
                physics = Physics.new(xml)
                assert_nil physics.simulation_time_update_period, 1e-6
            end
        end
    end
end
