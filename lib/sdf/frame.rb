module SDF
    class Frame < Element
        xml_tag_name 'frame'

        # The model's frame w.r.t. its parent
        #
        # @return [Array<Float>]
        def pose
            Conversions.pose_to_eigen(xml.elements["pose"])
        end
    end
end
