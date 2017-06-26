module SDF
    # Representation of a SDF model tag
    class Model < Element
        xml_tag_name 'model'

        # Load a model from its name
        #
        # See {XML.find_and_load_gazebo_model}. This method raises if the model
        # cannot be found
        #
        # @param [String] model_name the model name
        # @param [Integer,nil] sdf_version the maximum expected SDF version
        #   (as version * 100, i.e. version 1.5 is represented by 150). Leave to
        #   nil to always read the latest.
        # @return [Model]
        def self.load_from_model_name(model_name, sdf_version = nil)
            new(XML.model_from_name(model_name, sdf_version).elements.to_a('sdf/model').first)
        end

        def initialize(xml = REXML::Element.new('model'), parent = nil)
            super

            links, joints, plugins = Hash.new, Hash.new, Array.new
            xml.elements.each do |child|
                if child.name == 'link'
                    links[child.attributes['name']] = Link.new(child, self)
                elsif child.name == 'joint'
                    joints[child.attributes['name']] = child
                elsif child.name == 'plugin'
                    plugins << child
                end
            end
            @links   = links
            @joints = Hash.new
            joints.each do |name, child|
                @joints[name] = Joint.new(child, self)
            end
            @plugins = plugins.map { |child| Plugin.new(child, self) }
        end

        # The model's pose w.r.t. its parent
        #
        # @return [Eigen::Isometry3]
        def pose
            Conversions.pose_to_eigen(xml.elements["pose"])
        end

        # Whether the model is static
        def static?
            if static = xml.elements['static']
                Conversions.to_boolean(static)
            else
                false
            end
        end

        # Enumerates this model's links
        #
        # @yieldparam [Link] link
        def each_link(&block)
            @links.each_value(&block)
        end

        # Resolves a link by its name
        #
        # @return [Link,nil]
        def find_link_by_name(name)
            @links[name]
        end

        # Enumerates this model's joints
        #
        # @yieldparam [Joint] joint
        def each_joint(&block)
            @joints.each_value(&block)
        end

        # Resolves a joint by its name
        #
        # @return [Joint,nil]
        def find_joint_by_name(name)
            @joints[name]
        end

        # Enumerates this model's plugins
        #
        # @yieldparam [Plugin] plugin
        def each_plugin(&block)
            @plugins.each(&block)
        end

        # Enumerates the sensors contained in this model
        #
        # Note that sensors are children of links and joints, i.e. calling
        # #parent on the yield sensor objects will not return self
        #
        # @yieldparam [Sensor] sensor
        def each_sensor(&block)
            return enum_for(__method__) if !block_given?
            each_link do |l|
                l.each_sensor(&block)
            end
            each_joint do |j|
                j.each_sensor(&block)
            end
        end
    end
end

