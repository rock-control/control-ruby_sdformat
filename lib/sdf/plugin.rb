module SDF
    class Plugin < Element
        def filename
            if f = xml.attributes['filename']
                f
            else
                raise Invalid, "expected attribute 'filename' missing on #{self}"
            end
        end
    end
end
