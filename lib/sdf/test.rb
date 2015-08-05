# simplecov must be loaded FIRST. Only the files required after it gets loaded
# will be profiled !!!
if ENV['TEST_ENABLE_COVERAGE'] == '1'
    begin
        require 'simplecov'
        SimpleCov.start
    rescue LoadError
        require 'sdf'
        SDF.warn "coverage is disabled because the 'simplecov' gem cannot be loaded"
    rescue Exception => e
        require 'sdf'
        SDF.warn "coverage is disabled: #{e.message}"
    end
end

require 'sdf'
require 'minitest/autorun'
require 'minitest/spec'
require 'flexmock/minitest_integration'

if ENV['TEST_ENABLE_PRY'] != '0'
    begin
        require 'pry'
    rescue Exception
        SDF.warn "debugging is disabled because the 'pry' gem cannot be loaded"
    end
end

module SDF
    # This module is the common setup for all tests
    #
    # It should be included in the toplevel describe blocks
    #
    # @example
    #   require 'sdf/test'
    #   describe SDF do
    #   end
    #
    module SelfTest
        def setup
            # Setup code for all the tests
            super
        end

        def teardown
            super
            # Teardown code for all the tests
        end
    end
end

class Minitest::Test
    include SDF::SelfTest
end
