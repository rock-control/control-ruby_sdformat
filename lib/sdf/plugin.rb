module SDF
    class Plugin < Element
        def filename
            unless f = xml.attributes["filename"]
                raise Invalid, "expected attribute 'filename' missing on #{self}"
            end

            f
        end
    end
end
