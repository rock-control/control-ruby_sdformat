require 'eigen'
require 'sdf/xml'
require 'sdf/eigen_conversions'
require 'sdf/element'
require 'sdf/root'
require 'sdf/world'
require 'sdf/model'
require 'sdf/link'
require 'sdf/axis_limit'
require 'sdf/axis'
require 'sdf/joint'

# The toplevel namespace for sdf
#
# You should describe the basic idea about sdf here
require 'utilrb/logger'
module SDF
    extend Logger::Root('SDF', Logger::WARN)

    # Exception raised when the XML does not match the SDF specification
    class Invalid < RuntimeError; end
end

