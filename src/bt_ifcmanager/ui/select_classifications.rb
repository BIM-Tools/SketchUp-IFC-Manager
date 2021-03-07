#  select_materials.rb
#
#  Copyright 2020 Jan Brouwer <jan@brewsky.nl>
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
#  MA 02110-1301, USA.
#
#
# select2 for materials

module BimTools::IfcManager
  if Settings.common_psets
    require File.join(PLUGIN_PATH_LIB, "lib_ifc", 'add_common_psets.rb')
  end
  module PropertiesWindow      
    class HtmlSelectClassifications < HtmlSelect
      def set_value()
        selection = Set.new()
        su_selection = Sketchup.active_model.selection
        selection_count = su_selection.length
        i = 0
        while i < selection_count
          ent = su_selection[i]
          if(ent.is_a?(Sketchup::ComponentInstance) || ent.is_a?(Sketchup::Group))
            selection.add(ent.definition.get_attribute("AppliedSchemaTypes", @name))
          end
          i += 1
        end
        set_value_from_list(selection.to_a)
      end
      
      def html(selection)
        set_options()
        set_value()
        super
      end

      def set_callback()

        # Add save callback
        model = Sketchup.active_model
        @dialog.add_action_callback(@id) { |action_context, value|
          if model.classifications[@name]
            selection = model.selection
            selection_count = selection.length
            i = 0
            while i < selection_count
              ent = selection[i]
              if(ent.is_a? Sketchup::ComponentInstance) || (ent.is_a? Sketchup::Group)
                definition = ent.definition
                if value == "-"
                  old_value = definition.get_attribute("AppliedSchemaTypes", @name)
                  if old_value
                    definition.remove_classification(@name, old_value)
                  end
                else
                  definition.add_classification(@name, value)

                  # In case of IFC2X3 classification add common propertysets
                  #   together with the IFC classification
                  # (?) Is this the best place for this check?
                  if @name=="IFC 2x3"

                    # Set assigned enumerations to default value
                    ifc_dict = definition.attribute_dictionary("IFC 2x3")
                    ifc_dict.attribute_dictionaries.each do |attr_dict|
                      if attr_dict.attribute_dictionaries
                        attr_dict.attribute_dictionaries.each do |prop_dict|
                          if prop_dict["attribute_type"] == "enumeration"
                            if prop_dict["options"]
                              options = prop_dict["options"]
                              if options.include?("element")
                                prop_dict["value"] = "element"
                              else
                                prop_dict["value"] = prop_dict["options"].last
                              end
                            end
                          end
                        end
                      end
                    end
                    if Settings.common_psets
                      BimTools::IfcManager::add_common_psets(definition, value)
                    end
                  end
                end
              end
              i += 1
            end
          else
            notification = UI::Notification.new(IFCMANAGER_EXTENSION, "No classification with name: " + @name)
            notification.show
          end
          PropertiesWindow::update()
        }
      end
    end
  end
end