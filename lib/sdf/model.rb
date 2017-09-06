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

            models, links, joints, plugins, frames = Hash.new, Hash.new, Hash.new, Array.new, Hash.new
            xml.elements.each do |child|
                if child.name == 'model'
                    models[child.attributes['name']] = child
                elsif child.name == 'link'
                    links[child.attributes['name']] = Link.new(child, self)
                elsif child.name == 'joint'
                    joints[child.attributes['name']] = child
                elsif child.name == 'plugin'
                    plugins << child
                elsif child.name == 'frame'
                    frames[child.attributes['name']] = Frame.new(child, self)
                end
            end
            @links  = links
            if parent.kind_of?(Model)
                @canonical_link = parent.canonical_link
            end
            if !@canonical_link && (first_link = links.first)
                @canonical_link = first_link.last
            end
            @frames = frames
            @joints = Hash.new
            @models = Hash.new
            models.each do |model_name, xml|
                @models[model_name] = Model.new(xml, self)
            end

            submodels = Hash.new
            @models.each do |child_name, child_model|
                child_model.each_model_with_name do |m, m_name|
                    submodels["#{child_model.name}::#{m_name}"] = m
                end
                child_model.each_link_with_name do |link, link_name|
                    @links["#{child_model.name}::#{link_name}"] = link
                end
                child_model.each_joint_with_name do |joint, joint_name|
                    @joints["#{child_model.name}::#{joint_name}"] = joint
                end
                child_model.each_frame_with_name do |frame, frame_name|
                    @frames["#{child_model.name}::#{frame_name}"] = frame
                end
            end
            @models.merge!(submodels)
            joints.each do |name, joint_xml|
                @joints[name] = Joint.new(joint_xml, self)
            end
            @plugins = plugins.map { |child| Plugin.new(child, self) }
        end

        # The link that is used to represent the pose of the model itself
        attr_reader :canonical_link

        # (see Element#find_by_name)
        def find_by_name(name)
            @models[name] || @links[name] || @joints[name]
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

        # Enumerates this model's submodels
        #
        # The enumeration is recursive, i.e. it will yield models-of-submodels
        #
        # @yieldparam [Model] model
        def each_model
            return enum_for(__method__) if !block_given?
            @models.each_value { |m| yield(m) }
        end

        # Enumerates this model's submodels along with their relative name
        #
        # @yieldparam [Model] model
        # @yieldparam [String] name the name, relative to self
        def each_model_with_name
            return enum_for(__method__) if !block_given?
            @models.each { |name, m| yield(m, name) }
        end

        # Enumerates this model's links
        #
        # @yieldparam [Link] link
        def each_link
            return enum_for(__method__) if !block_given?
            @links.each_value { |l| yield(l) }
        end

        # Enumerates this model's links with their relative names
        #
        # @yieldparam [Link] link
        # @yieldparam [String] name the name, relative to self
        def each_link_with_name
            return enum_for(__method__) if !block_given?
            @links.each { |name, link| yield(link, name) }
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
            return enum_for(__method__) if !block_given?
            @joints.each_value { |j| yield(j) }
        end

        # Enumerates this model's joints along with their relative names
        #
        # @yieldparam [Joint] joint
        # @yieldparam [String] name the name, relative to self
        def each_joint_with_name
            return enum_for(__method__) if !block_given?
            @joints.each { |name, j| yield(j, name) }
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

        def each_frame_with_name(&block)
            return enum_for(__method__) if !block_given?
            @frames.each { |frame_name, frame| yield(frame, frame_name) }
        end

        def each_frame(&block)
            @frames.each_value(&block)
        end
    end
end

