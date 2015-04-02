module SDF
    class Axis < Element
        def xyz
            EigenConversions.vector3_to_eigen(xml.elements['xyz'])
        end

        def limit
            child_by_name('limit', AxisLimit, false)
        end
    end
end
