require "sdf/test"

module SDF
    module Conversions
        describe "pose_to_eigen" do
            attr_reader :obj

            it "parses a pose into a Eigen vector and quaternion" do
                xml = REXML::Document.new("<pose>1 2 3 0 -0 2</pose>").root
                p = Conversions.pose_to_eigen(xml)
                assert Eigen::Vector3.new(1, 2, 3).approx?(p.translation)
                assert Eigen::Quaternion.from_angle_axis(2,
                                                         Eigen::Vector3.UnitZ).approx?(p.rotation)
            end

            it "returns identity if given nil" do
                p = Conversions.pose_to_eigen(nil)
                assert Eigen::Vector3.new(0, 0, 0).approx?(p.translation)
                assert Eigen::Quaternion.Identity.approx?(p.rotation)
            end

            it "ignores leading and trailing spaces" do
                xml = REXML::Document.new("<pose>\n1 2 3 0 -0 2 </pose>").root
                p = Conversions.pose_to_eigen(xml)
                assert Eigen::Vector3.new(1, 2, 3).approx?(p.translation)
                assert Eigen::Quaternion.from_angle_axis(2,
                                                         Eigen::Vector3.UnitZ).approx?(p.rotation)
            end

            it "parses elements separated by an arbitrary amount of spaces" do
                xml = REXML::Document.new("<pose>\n1 2\t3    0\n\n-0 2 </pose>").root
                p = Conversions.pose_to_eigen(xml)
                assert Eigen::Vector3.new(1, 2, 3).approx?(p.translation)
                assert Eigen::Quaternion.from_angle_axis(2,
                                                         Eigen::Vector3.UnitZ).approx?(p.rotation)
            end

            describe "when given a string, it provides plain error messages" do
                it "raises if one of the elements is not a valid number" do
                    e = assert_raises(Invalid) do
                        Conversions.pose_to_eigen("1 2 3 0 -x 0")
                    end
                    assert_equal "invalid number in '1 2 3 0 -x 0'", e.message
                end

                it "raises if there are not enough elements" do
                    e = assert_raises(Invalid) do
                        Conversions.pose_to_eigen("1 2 3 0 -0")
                    end
                    assert_equal "'1 2 3 0 -0' has 5 entries, expected 6", e.message
                end

                it "raises if there are too many elements" do
                    e = assert_raises(Invalid) do
                        Conversions.pose_to_eigen("1 2 3 0 -0 0 1")
                    end
                    assert_equal "'1 2 3 0 -0 0 1' has 7 entries, expected 6", e.message
                end
            end

            describe "when given an XML element, it provides error messages with the XML XPath" do
                it "raises if one of the elements is not a valid number" do
                    xml = REXML::Document.new("<pose>1 2 3 0 -x 0</pose>").root
                    e = assert_raises(Invalid) do
                        Conversions.pose_to_eigen(xml)
                    end
                    assert_equal "in /pose: invalid number in '1 2 3 0 -x 0'", e.message
                end

                it "raises if there are not enough elements" do
                    xml = REXML::Document.new("<pose>1 2 3 0 -0</pose>").root
                    e = assert_raises(Invalid) do
                        Conversions.pose_to_eigen(xml)
                    end
                    assert_equal "in /pose: '1 2 3 0 -0' has 5 entries, expected 6",
                                 e.message
                end

                it "raises if there are too many elements" do
                    xml = REXML::Document.new("<pose>1 2 3 0 -0 0 1</pose>").root
                    e = assert_raises(Invalid) do
                        Conversions.pose_to_eigen(xml)
                    end
                    assert_equal "in /pose: '1 2 3 0 -0 0 1' has 7 entries, expected 6",
                                 e.message
                end
            end
        end

        describe "eigen_to_pose" do
            it "converts an Eigen transform back into XML" do
                xml = REXML::Document.new("<pose>1 2 3 0 -0 0.2</pose>").root
                expected = Conversions.pose_to_eigen(xml)
                to_pose = Conversions.eigen_to_pose(expected)
                actual = Conversions.pose_to_eigen(to_pose)
                assert_approx_equals expected, actual
            end
        end

        describe "vector3_to_eigen" do
            attr_reader :obj

            it "parses a 3-float into a Eigen vector" do
                xml = REXML::Document.new("<pose>1 2 3</pose>").root
                v = Conversions.vector3_to_eigen(xml)
                assert Eigen::Vector3.new(1, 2, 3).approx?(v)
            end

            it "strips its input string" do
                xml = REXML::Document.new("<pose>\n1 2 3 </pose>").root
                v = Conversions.vector3_to_eigen(xml)
                assert Eigen::Vector3.new(1, 2, 3).approx?(v)
            end

            it "parses elements separated by an arbitrary amount of spaces" do
                xml = REXML::Document.new("<pose>1\n\n2    3\t</pose>").root
                v = Conversions.vector3_to_eigen(xml)
                assert Eigen::Vector3.new(1, 2, 3).approx?(v)
            end

            it "returns identity if given nil" do
                v = Conversions.vector3_to_eigen(nil)
                assert Eigen::Vector3.new(0, 0, 0).approx?(v)
            end

            describe "when given a string, it raises the plain error message" do
                it "raises if one of the elements is not a valid number" do
                    e = assert_raises(Invalid) do
                        Conversions.vector3_to_eigen("1 2 x")
                    end
                    assert_equal "invalid number in '1 2 x'", e.message
                end

                it "raises if there are too few elements" do
                    e = assert_raises(Invalid) do
                        Conversions.vector3_to_eigen("1 2")
                    end
                    assert_equal "'1 2' has 2 entries, expected 3", e.message
                end

                it "raises if there are too many elements" do
                    e = assert_raises(Invalid) do
                        Conversions.vector3_to_eigen("1 2 3 4")
                    end
                    assert_equal "'1 2 3 4' has 4 entries, expected 3", e.message
                end
            end

            describe "when given a XML element, it adds the XPath to the error messages" do
                it "raises if one of the elements is not a valid number" do
                    xml = REXML::Document.new("<pose>1 2 x</pose>").root
                    e = assert_raises(Invalid) do
                        Conversions.vector3_to_eigen(xml)
                    end
                    assert_equal "in /pose: invalid number in '1 2 x'", e.message
                end

                it "raises if there are too few elements" do
                    xml = REXML::Document.new("<pose>1 2</pose>").root
                    e = assert_raises(Invalid) do
                        Conversions.vector3_to_eigen(xml)
                    end
                    assert_equal "in /pose: '1 2' has 2 entries, expected 3", e.message
                end

                it "raises if there are too many elements" do
                    xml = REXML::Document.new("<pose>1 2 3 4</pose>").root
                    e = assert_raises(Invalid) do
                        Conversions.vector3_to_eigen(xml)
                    end
                    assert_equal "in /pose: '1 2 3 4' has 4 entries, expected 3",
                                 e.message
                end
            end
        end

        describe "to_boolean" do
            it "returns true for the 'true' string" do
                xml = REXML::Document.new("<b>true</b>").root
                assert_same true, Conversions.to_boolean(xml)
            end
            it "strips its input string" do
                xml = REXML::Document.new("<b> true </b>").root
                assert_same true, Conversions.to_boolean(xml)
            end
            it "does not remove intermediate spaces" do
                xml = REXML::Document.new("<b> tr ue </b>").root
                assert_raises(Invalid) do
                    Conversions.to_boolean(xml)
                end
            end
            it "returns false for the 'false' string" do
                xml = REXML::Document.new("<b>false</b>").root
                assert_same false, Conversions.to_boolean(xml)
            end
            it "returns true for the '1' string" do
                xml = REXML::Document.new("<b>1</b>").root
                assert_same true, Conversions.to_boolean(xml)
            end
            it "returns false for the '0' string" do
                xml = REXML::Document.new("<b>0</b>").root
                assert_same false, Conversions.to_boolean(xml)
            end
            it "raises Invalid for anything else" do
                e = assert_raises(Invalid) do
                    Conversions.to_boolean("bla")
                end
                assert_equal "invalid boolean value 'bla', expected true or false",
                             e.message
            end
            it "raises Invalid for anything else," \
               "adding the XPath when given an element" do
                xml = REXML::Document.new("<b>bla</b>").root
                e = assert_raises(Invalid) do
                    Conversions.to_boolean(xml)
                end
                assert_equal "in /b: invalid boolean value 'bla', expected true or false",
                             e.message
            end
        end
    end
end
