module SDF
    class Axis < Element
        xml_tag_name 'axis'

        def xyz
            EigenConversions.vector3_to_eigen(xml.elements['xyz'])
        end

        def use_parent_model_frame?
            if flag = xml.elements['use_parent_model_frame']
                flag.text == '1'
            else
                false
            end
        end

        def limit
            child_by_name('limit', AxisLimit, false)
        end
    end
end
