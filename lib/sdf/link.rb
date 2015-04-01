module SDF
    class Link < Element
        # The model's pose w.r.t. its parent
        #
        # @return [Array<Float>]
        def pose
            EigenConversions.pose_to_eigen(xml.elements["pose"])
        end
    end
end
