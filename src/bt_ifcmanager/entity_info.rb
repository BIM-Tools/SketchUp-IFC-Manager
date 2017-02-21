#  entity_info.rb
#
#  Copyright 2017 Jan Brouwer <jan@brewsky.nl>
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

module BimTools
 module IfcManager
   module PropertiesWindow
    module EntityInfo
      extend self
      @section = MenuSection.new( 'Entity Info', PropertiesWindow)

      def update(selection)
        if selection.length == 1 && selection[0].is_a?( Sketchup::ComponentInstance )
          @section.rename( "Component (" + Sketchup.active_model.selection[0].definition.count_used_instances.to_s + " in model)" )
          update_type
          update_nlsfb
          update_name
          update_materials
          update_layers
          @section.maximize
        else
          @section.rename( "Select a single Component" )
          @section.minimize
        end
      end # def update

      def add_name( entity )
        if entity.is_a?( Sketchup::ComponentInstance )
          name = entity.definition.name
        else
          name = ""
        end
        @name = SKUI::Textbox.new( name )
        lbl = SKUI::Label.new( 'Name:', @name )

        # get list of used component names
        list = Array.new
        Sketchup.active_model.definitions.each do | definition |
          list << definition.name
        end
        list.sort_by!(&:downcase) # alphabetize array ignoring case

        # get the name name for entity
        @name.value = name
        
        # inject options list AFTER window is loaded. (?) could be done on initialisation
        PropertiesWindow.window.on( :ready ) { |control, value| # (?) Second argument needed?
          @name.options( list )
        }
        
        # on click: show complete list
        @name.on( :click ) { |control, value| # (?) Second argument needed?
          js_command = "$('#" + control.ui_id + "_ui').autocomplete('search', '');"
          js_command << "$('#" + control.ui_id + "_ui').select();"
          PropertiesWindow.window.webdialog.execute_script(js_command)
        }
        
        @name.on( :blur || :textchange ) { |control, value| # (?) Second argument needed?
          model = Sketchup.active_model
          entity = Sketchup.active_model.selection[0]
          definition = entity.definition
          
          # update the component name
          if definition.name != control.value
            #if model.definitions[control.value] # (!) name cannot be a duplicate, set error message
            #  UI.messagebox('The component name must be unique.', MB_OK)
            #else
              definition.name = model.definitions.unique_name( control.value.downcase ) # create a unique name from value
            #end
          end

          # set IFC property
          selected = get_ifc_type( entity )
          if selected
            path = ["IFC 2x3", selected.to_s, "Name", "IfcLabel"]
            definition.set_classification_value(path, definition.name)
            
            # Improved interopability with solibri, solibri shows "name" as number and "longname" as "name": fill both with the same value
            # (!) must also update when ifctype changes to space
            if selected == 'IfcSpace'
              path = ["IFC 2x3", selected.to_s, "LongName", "IfcLabel"]
              definition.set_classification_value(path, definition.name)
            end
          end
          update_name
          PropertiesWindow.update
        }

        @section.add_control( lbl )
        @section.add_control( @name )
      end # def add_name

      def add_description( entity )
        if entity.is_a?( Sketchup::ComponentInstance )
          description = entity.definition.description
        else
          description = ""
        end
        @description = SKUI::Textbox.new( description )
        lbl = SKUI::Label.new( 'Description:', @description )

        # set the selected material as object material
        @description.on( :blur || :textchange ) { |control, value| # (?) Second argument needed?
          entity = Sketchup.active_model.selection[0]
          entity.definition.description = control.value
        }

        @section.add_control( lbl )
        @section.add_control( @description )

      end # def add_description

      def add_type( entity )

        list = ["IfcBeam", "IfcBuilding", "IfcBuildingElementProxy", "IfcBuildingStorey", "IfcColumn", "IfcCurtainWall", "IfcDoor", "IfcFooting", "IfcFurnishingElement", "IfcMember", "IfcPile", "IfcPlate", "IfcRailing", "IfcRamp", "IfcRampFlight", "IfcRoof", "IfcSite", "IfcSlab", "IfcSpace", "IfcStair", "IfcStairFlight", "IfcWall", "IfcWallStandardCase", "IfcWindow"]

        @type = SKUI::Textbox.new( get_ifc_type( entity ) )
        lbl = SKUI::Label.new( 'IFC entity:', @type )

        # get the type name for entity
        @type.value = get_ifc_type( entity )
        
        # inject options list AFTER window is loaded. (?) could be done on initialisation
        PropertiesWindow.window.on( :ready ) { |control, value| # (?) Second argument needed?
          @type.options( list )
        }
        
        # on click: show complete list
        @type.on( :click ) { |control, value| # (?) Second argument needed?
          js_command = "$('#" + control.ui_id + "_ui').autocomplete('search', '');"
          js_command << "$('#" + control.ui_id + "_ui').select();"
          PropertiesWindow.window.webdialog.execute_script(js_command)
        }

        @type.on( :blur || :textchange ) { |control, value| # (?) Second argument needed?
          entity = Sketchup.active_model.selection[0]
          selected = get_ifc_type( entity )
          if control.value == "" || control.value == nil # (?) should nil be a value?
            unless selected.nil?
              entity.definition.remove_classification("IFC 2x3", selected)
            end
          else
            entity.definition.add_classification("IFC 2x3", control.value)
          end

          PropertiesWindow.update
        }

        @section.add_control( lbl )
        @section.add_control( @type )
      end # def add_type

      def add_materials()
        entity = Sketchup.active_model.selection[0]
        if entity && entity.material
          value = entity.material.display_name
        else
          value = ""
        end

        @materials = SKUI::Textbox.new( value )
        lbl = SKUI::Label.new( 'Material:', @materials )
        
        @new_material = SKUI::Button.new( "" )
        @new_material.width = 20
        @new_material.height = 20
        
        # inject options list AFTER window is loaded. (?) could be done on initialisation
        PropertiesWindow.window.on( :ready ) { |control, value| # (?) Second argument needed?
          update_materials
        }
        
        # on click: show complete list
        @materials.on( :click ) { |control, value| # (?) Second argument needed?
          js_command = "$('#" + control.ui_id + "_ui').autocomplete('search', '');"
          js_command << "$('#" + control.ui_id + "_ui').select();"
          PropertiesWindow.window.webdialog.execute_script(js_command)
        }

        # set the selected material as object material
        @materials.on( :blur || :textchange ) { |control, value| # (?) Second argument needed?
          entity = Sketchup.active_model.selection[0]
          update_material_list
          entity.material = @material_list[control.value]
          PropertiesWindow.update
        }
        
        # on click: create new material
        @new_material.on( :click ) { |control, value| # (?) Second argument needed?
          js_command = "$('#" + control.ui_id + "_ui').autocomplete('search', '');"
          PropertiesWindow.window.webdialog.execute_script(js_command)
          
          input = UI.inputbox(["Name:"], [""], "Create material...")
          
          if input
          
            # make sure the input is never empty to get a proper material name
            if input[0] == ""
              input[0] = "Material"
            end
            
            new_material = Sketchup.active_model.materials.add(input[0].downcase)
            new_material.color = [255, 255, 255]
            entity = Sketchup.active_model.selection[0]
            entity.material = new_material.name
            PropertiesWindow.update
          end
        }

        @section.add_control( lbl )
        @section.add_control( @new_material )
        @section.add_control( @materials )


      end # def add_materials

      def add_layers()
        entity = Sketchup.active_model.selection[0]
        if entity
          value = entity.layer.name
        else
          value = ""
        end
        
        @new_layer = SKUI::Button.new( "" )
        @new_layer.width = 20 
        @new_layer.height = 20

        @layers = SKUI::Textbox.new( value )
        lbl = SKUI::Label.new( 'Layer:', @layers )
        
        # inject options list AFTER window is loaded. (?) could be done on initialisation
        PropertiesWindow.window.on( :ready ) { |control, value| # (?) Second argument needed?
          update_layers
        }
        
        # on click: show complete list
        @layers.on( :click ) { |control, value| # (?) Second argument needed?
          js_command = "$('#" + control.ui_id + "_ui').autocomplete('search', '');"
          js_command << "$('#" + control.ui_id + "_ui').select();"
          PropertiesWindow.window.webdialog.execute_script(js_command)
        }

        # set the selected layer as object layer
        @layers.on( :blur || :textchange ) { |control, value| # (?) Second argument needed?
          entity = Sketchup.active_model.selection[0]
          entity.layer = control.value
          PropertiesWindow.update
        }
        
        # on click: create new layer
        @new_layer.on( :click ) { |control, value| # (?) Second argument needed?
          js_command = "$('#" + control.ui_id + "_ui').autocomplete('search', '');"
          PropertiesWindow.window.webdialog.execute_script(js_command)
          
          input = UI.inputbox(["Name:"], [""], "Create layer...")
          
          if input
            
            # make sure the input is never empty to get a proper layer name
            if input[0] == ""
              input[0] = "Layer"
            end
            new_layer = Sketchup.active_model.layers.add(input[0].downcase)
            entity = Sketchup.active_model.selection[0]
            entity.layer = new_layer.name
            PropertiesWindow.update
          end
        }

        @section.add_control( lbl )
        @section.add_control( @new_layer )
        @section.add_control( @layers )

      end # def add_layers

      def add_nlsfb( entity )
        entity = Sketchup.active_model.selection[0]

        list = ['(0-) PROJECT TOTAAL', '(0-.0) indirecte projectvoorzieningen', '(0-.1) werkterreininrichtingen', '(0-.10) indirecte projectvoorzieningen; werkterreininrichting, algemeen (verzamelniveau)', '(0-.11) indirecte projectvoorzieningen; werkterreininrichting, bijkomende werken algemeen', '(0-.12) indirecte projectvoorzieningen; werkterreininrichting, personen/materiaalvoorzieningen', '(0-.13) indirecte projectvoorzieningen; werkterreininrichting, energievoorzieningen', '(0-.14) indirecte projectvoorzieningen; werkterreininrichting, beveiligingsvoorzieningen', '(0-.15) indirecte projectvoorzieningen; werkterreininrichting, doorwerkvoorzieningen', '(0-.16) indirecte projectvoorzieningen; werkterreininrichting, voorzieningen belendende percelen', '(0-.17) indirecte projectvoorzieningen; werkterreininrichting, onderhoudsvoorzieningen', '(0-.2) materieelvoorzieningen', '(0-.20) indirecte projectvoorzieningen; materieelvoorzieningen, algemeen (verzamelniveau)', '(0-.21) indirecte projectvoorzieningen; materieelvoorzieningen, transport', '(0-.22) indirecte projectvoorzieningen; materieelvoorzieningen, gereedschappen (algemeen)', '(0-.3) risicodekking', '(0-.30) indirecte projectvoorzieningen; risicodekking, algemeen (verzamelniveau)', '(0-.31) indirecte projectvoorzieningen; risicodekking, verzekeringen', '(0-.32) indirecte projectvoorzieningen; risicodekking, waarborgen', '(0-.33) indirecte projectvoorzieningen; risicodekking, prijsstijgingen', '(0-.4) projectorganisatie', '(0-.40) indirecte projectvoorzieningen; projectorganisatie, algemeen (verzamelniveau)', '(0-.41) indirecte projectvoorzieningen; projectorganisatie, administratie', '(0-.42) indirecte projectvoorzieningen; projectorganisatie, uitvoering', '(0-.43) indirecte projectvoorzieningen; projectorganisatie, documentatie', '(0-.5) bedrijfsorganisatie', '(0-.50) indirecte projectvoorzieningen; bedrijfsorganisatie, algemeen (verzamelniveau)', '(0-.51) indirecte projectvoorzieningen; bedrijfsorganisatie, bestuur en directie', '(0-.52) indirecte projectvoorzieningen; bedrijfsorganisatie, winstregelingen', '(1-) FUNDERINGEN', '(10) -gereserveerd-', '(11) Bodemvoorzieningen', '(11.0) bodemvoorzieningen; algemeen', '(11.1) bodemvoorzieningen; grond', '(11.10) bodemvoorzieningen; grond, algemeen (verzamelniveau)', '(11.11) bodemvoorzieningen; grond, ontgravingen', '(11.12) bodemvoorzieningen; grond, aanvullingen', '(11.13) bodemvoorzieningen; grond, sloop- en rooiwerkzaamheden', '(11.15) bodemvoorzieningen; grond, damwanden', '(11.2) bodemvoorzieningen; water', '(11.20) bodemvoorzieningen; water, algemeen (verzamelniveau)', '(11.24) bodemvoorzieningen; water, bemalingen', '(11.25) bodemvoorzieningen; water, damwanden', '(12) -gereserveerd-', '(13) Vloeren op grondslag', '(13.0) vloeren op grondslag; algemeen', '(13.1) vloeren op grondslag; niet constructief', '(13.10) vloeren op grondslag; niet constructief, algemeen (verzamelniveau)', '(13.11) vloeren op grondslag; niet constructief, bodemafsluitingen', '(13.12) vloeren op grondslag; niet constructief, vloeren als gebouwonderdeel', '(13.13) vloeren op grondslag; niet constructief, vloeren als bestrating', '(13.2) vloeren op grondslag; constructief', '(13.20) vloeren op grondslag; constructief, algemeen (verzamelniveau)', '(13.21) vloeren op grondslag; constructief, bodemafsluitingen', '(13.22) vloeren op grondslag; constructief, vloeren als gebouwonderdeel', '(13.25) vloeren op grondslag; constructief, grondverbeteringen', '(14) -gereserveerd-', '(15) -gereserveerd-', '(16) Funderingsconstructies', '(16.0) funderingsconstructies; algemeen', '(16.1) funderingsconstructies; voeten en balken', '(16.10) funderingsconstructies; voeten en balken, algemeen (verzamelniveau)', '(16.11) funderingsconstructies; voeten en balken, fundatie voeten', '(16.12) funderingsconstructies; voeten en balken, fundatie balken', '(16.13) funderingsconstructies; voeten en balken, fundatie poeren', '(16.14) funderingsconstructies; voeten en balken, gevelwanden (-200)', '(16.15) funderingsconstructies; voeten en balken, grondverbeteringen', '(16.2) funderingsconstructies; keerwanden', '(16.20) funderingsconstructies; keerwanden, algemeen (verzamelniveau)', '(16.21) funderingsconstructies; keerwanden, grondkerende wanden', '(16.22) funderingsconstructies; keerwanden, waterkerende wanden', '(16.23) funderingsconstructies; keerwanden, gevelwanden (-200)', '(16.25) funderingsconstructies; keerwanden, grondverbeteringen', '(17) Paalfunderingen', '(17.0) paalfunderingen; algemeen', '(17.1) paalfunderingen; niet geheid', '(17.10) paalfunderingen; niet geheid, algemeen (verzamelniveau)', '(17.11) paalfunderingen; niet geheid, dragende palen; geboord', '(17.12) paalfunderingen; niet geheid, dragende palen; geschroefd', '(17.13) paalfunderingen; niet geheid, trekverankeringen', '(17.14) paalfunderingen; niet geheid, pijler-putringfunderingen', '(17.15) paalfunderingen; niet geheid, bodeminjecties', '(17.2) paalfunderingen; geheid', '(17.20) paalfunderingen; geheid, algemeen (verzamelniveau)', '(17.21) paalfunderingen; geheid, dragende palen', '(17.22) paalfunderingen; geheid, palen; ingeheide bekisting', '(17.23) paalfunderingen; geheid, trekverankeringen', '(17.25) paalfunderingen; geheid, damwandenfunderingen', '(18) -gereserveerd-', '(19) -gereserveerd-', '(2-) RUWBOUW', '(20) -gereserveerd-', '(21) BUITENWANDEN', '(21.0) buitenwanden; algemeen', '(21.1) buitenwanden; niet constructief', '(21.10) buitenwanden; niet constructief, algemeen (verzamelniveau)', '(21.11) buitenwanden; niet constructief, massieve wanden', '(21.12) buitenwanden; niet constructief, spouwwanden', '(21.13) buitenwanden; niet constructief, systeemwanden', '(21.14) buitenwanden; niet constructief, vlieswanden', '(21.15) buitenwanden; niet constructief, borstweringen', '(21.16) buitenwanden; niet constructief, boeiboorden', '(21.2) buitenwanden; constructief', '(21.20) buitenwanden; constructief, algemeen (verzamelniveau)', '(21.21) buitenwanden; constructief, massieve wanden', '(21.22) buitenwanden; constructief, spouwwanden', '(21.23) buitenwanden; constructief, systeemwanden', '(21.25) buitenwanden; constructief, borstweringen', '(22) Binnenwanden', '(22.0) binnenwanden; algemeen', '(22.1) binnenwanden; niet constructief', '(22.10) binnenwanden; niet constructief, algemeen (verzamelniveau)', '(22.11) binnenwanden; niet constructief, massieve wanden', '(22.12) binnenwanden; niet constructief, spouwwanden', '(22.13) binnenwanden; niet constructief, systeemwanden; vast', '(22.14) binnenwanden; niet constructief, systeemwanden; verplaatsbaar', '(22.2) binnenwanden; constructief', '(22.20) binnenwanden; constructief, algemeen (verzamelniveau)', '(22.21) binnenwanden; constructief, massieve wanden', '(22.22) binnenwanden; constructief, spouwwanden', '(22.23) binnenwanden; constructief, systeemwanden; vast', '(23) Vloeren', '(23.0) vloeren; algemeen', '(23.1) vloeren; niet constructief', '(23.10) vloeren; niet constructief, algemeen (verzamelniveau)', '(23.11) vloeren; niet constructief, vrijdragende vloeren', '(23.12) vloeren; niet constructief, balkons', '(23.13) vloeren; niet constructief, galerijen', '(23.14) vloeren; niet constructief, bordessen', '(23.15) vloeren; niet constructief, vloeren t.b.v. technische voorzieningen', '(23.2) vloeren; constructief', '(23.20) vloeren; constructief, algemeen (verzamelniveau)', '(23.21) vloeren; constructief, vrijdragende vloeren', '(23.22) vloeren; constructief, balkons', '(23.23) vloeren; constructief, galerijen', '(23.24) vloeren; constructief, bordessen', '(23.25) vloeren; constructief, vloeren t.b.v. technische voorzieningen', '(24) Trappen en hellingen', '(24.0) trappen en hellingen; algemeen', '(24.1) trappen en hellingen; trappen', '(24.10) trappen en hellingen; trappen, algemeen (verzamelniveau)', '(24.11) trappen en hellingen; trappen, rechte steektrappen', '(24.12) trappen en hellingen; trappen, niet-rechte steektrappen', '(24.13) trappen en hellingen; trappen, spiltrappen', '(24.15) trappen en hellingen; trappen, bordessen', '(24.2) trappen en hellingen; hellingen', '(24.20) trappen en hellingen; hellingen, algemeen (verzamelniveau)', '(24.21) trappen en hellingen; hellingen, beloopbare hellingen', '(24.22) trappen en hellingen; hellingen, berijdbare hellingen', '(24.25) trappen en hellingen; hellingen, bordessen', '(24.3) trappen en hellingen; ladders en klimijzers', '(24.30) trappen en hellingen; ladders en klimijzers, algemeen (verzamelniveau)', '(24.31) trappen en hellingen; ladders en klimijzers, ladders', '(24.32) trappen en hellingen; ladders en klimijzers, klimijzers', '(24.35) trappen en hellingen; ladders en klimijzers, bordessen', '(25) -gereserveerd-', '(26) -gereserveerd-', '(27) Daken', '(27.0) daken; algemeen', '(27.1) daken; niet constructief', '(27.10) daken; niet constructief, algemeen (verzamelniveau)', '(27.11) daken; niet constructief, vlakke daken', '(27.12) daken; niet constructief, hellende daken', '(27.13) daken; niet constructief, luifels', '(27.14) daken; niet constructief, overkappingen', '(27.16) daken; niet constructief, gootconstructies', '(27.2) daken; constructief', '(27.20) daken; constructief, algemeen (verzamelniveau)', '(27.21) daken; constructief, vlakke daken', '(27.22) daken; constructief, hellende daken', '(27.23) daken; constructief, luifels', '(27.24) daken; constructief, overkappingen', '(27.26) daken; constructief, gootconstructies', '(28) Hoofddraagconstructies', '(28.0) hoofddraagconstructies; algemeen', '(28.1) hoofddraagconstructies; kolommen en liggers', '(28.10) hoofddraagconstructies; kolommen en liggers, algemeen (verzamelniveau)', '(28.11) hoofddraagconstructies; kolommen en liggers, kolom-/liggerconstructies', '(28.12) hoofddraagconstructies; kolommen en liggers, spanten', '(28.2) hoofddraagconstructies; wanden en vloeren', '(28.20) hoofddraagconstructies; wanden en vloeren, algemeen (verzamelniveau)', '(28.21) hoofddraagconstructies; wanden en vloeren, wand-/vloerconstructies', '(28.3) hoofddraagconstructies; ruimte-eenheden', '(28.30) hoofddraagconstructies; ruimte-eenheden, algemeen (verzamelniveau)', '(28.31) hoofddraagconstructies; ruimte-eenheden, doosconstructies', '(29) -gereserveerd-', '(3-) AFBOUW', '(30) -gereserveerd-', '(31) Buitenwandopeningen', '(31.0) buitenwandopeningen; algemeen', '(31.1) buitenwandopeningen; niet gevuld', '(31.10) buitenwandopeningen; niet gevuld, algemeen (verzamelniveau)', '(31.11) buitenwandopeningen; niet gevuld, daglichtopeningen', '(31.12) buitenwandopeningen; niet gevuld, buitenluchtopeningen', '(31.2) buitenwandopeningen; gevuld met ramen', '(31.20) buitenwandopeningen; gevuld met ramen, algemeen (verzamelniveau)', '(31.21) buitenwandopeningen; gevuld met ramen, gesloten ramen', '(31.22) buitenwandopeningen; gevuld met ramen, ramen draaiend aan een kant', '(31.23) buitenwandopeningen; gevuld met ramen, schuiframen', '(31.24) buitenwandopeningen; gevuld met ramen, ramen draaiend op verticale of horizontale as', '(31.25) buitenwandopeningen; gevuld met ramen, combinatieramen', '(31.3) buitenwandopeningen; gevuld met deuren', '(31.30) buitenwandopeningen; gevuld met deuren, algemeen (verzamelniveau)', '(31.31) buitenwandopeningen; gevuld met deuren, draaideuren', '(31.32) buitenwandopeningen; gevuld met deuren, schuifdeuren', '(31.33) buitenwandopeningen; gevuld met deuren, tuimeldeuren', '(31.34) buitenwandopeningen; gevuld met deuren, tourniquets', '(31.4) buitenwandopeningen; gevuld met puien', '(31.40) buitenwandopeningen; gevuld met puien, algemeen (verzamelniveau)', '(31.41) buitenwandopeningen; gevuld met puien, gesloten puien', '(32) Binnenwandopeningen', '(32.0) binnenwandopeningen; algemeen', '(32.1) binnenwandopeningen; niet gevuld', '(32.10) binnenwandopeningen; niet gevuld, algemeen (verzamelniveau)', '(32.11) binnenwandopeningen; niet gevuld, openingen als doorgang', '(32.12) binnenwandopeningen; niet gevuld, openingen als doorzicht', '(32.2) binnenwandopeningen; gevuld met ramen', '(32.20) binnenwandopeningen; gevuld met ramen, algemeen (verzamelniveau)', '(32.21) binnenwandopeningen; gevuld met ramen, gesloten ramen', '(32.22) binnenwandopeningen; gevuld met ramen, ramen draaiend aan een kant', '(32.23) binnenwandopeningen; gevuld met ramen, schuiframen', '(32.24) binnenwandopeningen; gevuld met ramen, ramen draaiend op verticale of horizontale as', '(32.25) binnenwandopeningen; gevuld met ramen, combinatieramen', '(32.3) binnenwandopeningen; gevuld met deuren', '(32.30) binnenwandopeningen; gevuld met deuren, algemeen (verzamelniveau)', '(32.31) binnenwandopeningen; gevuld met deuren, draaideuren', '(32.32) binnenwandopeningen; gevuld met deuren, schuifdeuren', '(32.33) binnenwandopeningen; gevuld met deuren, tuimeldeuren', '(32.34) binnenwandopeningen; gevuld met deuren, tourniquets', '(32.4) binnenwandopeningen; gevuld met puien', '(32.40) binnenwandopeningen; gevuld met puien, algemeen (verzamelniveau)', '(32.41) binnenwandopeningen; gevuld met puien, gesloten puien', '(33) Vloeropeningen', '(33.0) vloeropeningen; algemeen', '(33.1) vloeropeningen; niet gevuld', '(33.10) vloeropeningen; niet gevuld, algemeen (verzamelniveau)', '(33.11) vloeropeningen; niet gevuld, openingen als doorgang', '(33.12) vloeropeningen; niet gevuld, openingen als doorzicht', '(33.2) vloeropeningen; gevuld', '(33.20) vloeropeningen; gevuld, algemeen (verzamelniveau)', '(33.21) vloeropeningen; gevuld, beloopbare vullingen', '(33.22) vloeropeningen; gevuld, niet-beloopbare vullingen', '(34) Balustrades en leuningen', '(34.0) balustrades en leuningen; algemeen', '(34.1) balustrades en leuningen; balustrades', '(34.10) balustrades en leuningen; balustrades, algemeen (verzamelniveau)', '(34.11) balustrades en leuningen; balustrades, binnenbalustrades', '(34.12) balustrades en leuningen; balustrades, buitenbalustrades', '(34.2) balustrades en leuningen; leuningen', '(34.20) balustrades en leuningen; leuningen, algemeen (verzamelniveau)', '(34.21) balustrades en leuningen; leuningen, binnenleuningen', '(34.22) balustrades en leuningen; leuningen, buitenleuningen', '(35) -gereserveerd-', '(36) -gereserveerd-', '(37) Dakopeningen', '(37.0) dakopeningen; algemeen', '(37.1) dakopeningen; niet gevuld', '(37.10) dakopeningen; niet gevuld, algemeen (verzamelniveau)', '(37.11) dakopeningen; niet gevuld, daglichtopeningen', '(37.12) dakopeningen; niet gevuld, buitenluchtopeningen', '(37.2) dakopeningen; gevuld', '(37.20) dakopeningen; gevuld, algemeen (verzamelniveau)', '(37.21) dakopeningen; gevuld, gesloten ramen', '(37.22) dakopeningen; gevuld, ramen draaiend aan één kant', '(37.23) dakopeningen; gevuld, schuiframen', '(37.24) dakopeningen; gevuld, ramen draaiend op een as', '(37.25) dakopeningen; gevuld, combinatieramen', '(38) Inbouwpakketten', '(38.0) inbouwpakketten; algemeen', '(38.1) inbouwpakketten', '(38.10) inbouwpakketten; algemeen (verzamelniveau)', '(38.11) inbouwpakketten; inbouwpakketten met te openen delen', '(38.12) inbouwpakketten; inbouwpakketten met gesloten delen', '(39) -gereserveerd-', '(4-) AFWERKINGEN', '(40) -gereserveerd-', '(41) Buitenwandafwerkingen', '(41.0) buitenwandafwerkingen; algemeen', '(41.1) buitenwandafwerkingen', '(41.10) buitenwandafwerkingen; algemeen (verzamelniveau)', '(41.11) buitenwandafwerkingen; afwerklagen', '(41.12) buitenwandafwerkingen; bekledingen', '(41.13) buitenwandafwerkingen; voorzetwanden', '(42) Binnenwandafwerkingen', '(42.0) binnenwandafwerkingen; algemeen', '(42.1) binnenwandafwerkingen', '(42.10) binnenwandafwerkingen; algemeen (verzamelniveau)', '(42.11) binnenwandafwerkingen; afwerklagen', '(42.12) binnenwandafwerkingen; bekledingen', '(43) Vloerafwerkingen', '(43.0) vloerafwerkingen; algemeen', '(43.1) vloerafwerkingen; verhoogd', '(43.10) vloerafwerkingen; verhoogd, algemeen (verzamelniveau)', '(43.11) vloerafwerkingen; verhoogd, podiums', '(43.12) vloerafwerkingen; verhoogd, installatievloeren', '(43.2) vloerafwerkingen; niet verhoogd', '(43.20) vloerafwerkingen; niet verhoogd, algemeen (verzamelniveau)', '(43.21) vloerafwerkingen; niet verhoogd, afwerklagen', '(43.22) vloerafwerkingen; niet verhoogd, bekledingen', '(43.23) vloerafwerkingen; niet verhoogd, systeemvloerafwerkingen', '(44) Trap- en hellingafwerkingen', '(44.0) trap- en hellingafwerkingen; algemeen', '(44.1) trap- en hellingafwerkingen; trapafwerkingen', '(44.10) trap- en hellingafwerkingen; trapafwerkingen, algemeen (verzamelniveau)', '(44.11) trap- en hellingafwerkingen; trapafwerkingen, afwerklagen', '(44.12) trap- en hellingafwerkingen; trapafwerkingen, bekledingen', '(44.13) trap- en hellingafwerkingen; trapafwerkingen, systeemafwerkingen', '(44.2) trap- en hellingafwerkingen; hellingafwerkingen', '(44.20) trap- en hellingafwerkingen; hellingafwerkingen, algemeen (verzamelniveau)', '(44.21) trap- en hellingafwerkingen; hellingafwerkingen, afwerklagen', '(44.22) trap- en hellingafwerkingen; hellingafwerkingen, bekledingen', '(44.23) trap- en hellingafwerkingen; hellingafwerkingen, systeemafwerkingen', '(45) Plafondafwerkingen', '(45.0) plafondafwerkingen; algemeen', '(45.1) plafondafwerkingen; verlaagd', '(45.10) plafondafwerkingen; verlaagd, algemeen (verzamelniveau)', '(45.11) plafondafwerkingen; verlaagd, verlaagde plafonds', '(45.12) plafondafwerkingen; verlaagd, systeemplafonds', '(45.14) plafondafwerkingen; verlaagd, koofconstructies', '(45.15) plafondafwerkingen; verlaagd, gordijnplanken', '(45.2) plafondafwerkingen; niet verlaagd', '(45.20) plafondafwerkingen; niet verlaagd, algemeen (verzamelniveau)', '(45.21) plafondafwerkingen; niet verlaagd, afwerkingen', '(45.22) plafondafwerkingen; niet verlaagd, bekledingen', '(45.23) plafondafwerkingen; niet verlaagd, systeemafwerkingen', '(45.24) plafondafwerkingen; niet verlaagd, koofconstructies', '(45.25) plafondafwerkingen; niet verlaagd, gordijnplanken', '(46) -gereserveerd-', '(47) Dakafwerkingen', '(47.0) dakafwerkingen; algemeen', '(47.1) dakafwerkingen; afwerkingen', '(47.10) dakafwerkingen; afwerkingen, algemeen (verzamelniveau)', '(47.11) dakafwerkingen; afwerkingen, vlakke dakafwerkingen', '(47.12) dakafwerkingen; afwerkingen, hellende dakafwerkingen', '(47.13) dakafwerkingen; afwerkingen, luifelafwerkingen', '(47.14) dakafwerkingen; afwerkingen, overkappingsafwerkingen', '(47.15) dakafwerkingen; afwerkingen, beloopbare dakafwerkingen', '(47.16) dakafwerkingen; afwerkingen, berijdbare dakafwerkingen', '(47.2) dakafwerkingen; bekledingen', '(47.20) dakafwerkingen; bekledingen, algemeen (verzamelniveau)', '(47.21) dakafwerkingen; bekledingen, vlakke dak bekledingen', '(47.22) dakafwerkingen; bekledingen, hellende dak bekledingen', '(47.23) dakafwerkingen; bekledingen, luifel bekledingen', '(47.24) dakafwerkingen; bekledingen, overkapping bekledingen', '(47.25) dakafwerkingen; bekledingen, beloopbare dak bekledingen', '(47.26) dakafwerkingen; bekledingen, berijdbare dak  bekledingen', '(48) Afwerkingpakketten', '(48.0) afwerkingspakketten; algemeen', '(48.1) afwerkingspakketten', '(48.10) afwerkingspakketten; algemeen (verzamelniveau)', '(48.11) afwerkingspakketten; naadloze afwerkingen', '(48.12) afwerkingspakketten; overige afwerkingen', '(49) -gereserveerd-', '(5-) INSTALLATIES WERKTUIGBOUWKUNDIG', '(50) -gereserveerd-', '(51) Warmteopwekking', '(51.0) warmte-opwekking; algemeen', '(51.1) warmte-opwekking; lokaal', '(51.10) warmte-opwekking; lokaal, algemeen (verzamelniveau)', '(51.11) warmte-opwekking; lokaal, gasvormige brandstoffen', '(51.12) warmte-opwekking; lokaal, vloeibare brandstoffen', '(51.13) warmte-opwekking; lokaal, vaste brandstoffen', '(51.14) warmte-opwekking; lokaal, schoorstenen/kanalen (niet bouwkundig)', '(51.16) warmte-opwekking; lokaal, gecombineerde tapwaterverwarming', '(51.19) warmte-opwekking; lokaal, brandstoffenopslag', '(51.2) warmte-opwekking; centraal', '(51.20) warmte-opwekking; centraal, algemeen (verzamelniveau)', '(51.21) warmte-opwekking; centraal, gasvormige brandstoffen', '(51.22) warmte-opwekking; centraal, vloeibare brandstoffen', '(51.23) warmte-opwekking; centraal, vaste brandstoffen', '(51.24) warmte-opwekking; centraal, schoorstenen/kanalen (niet bouwkundig)', '(51.26) warmte-opwekking; centraal, gecombineerde tapwaterverwarming', '(51.29) warmte-opwekking; centraal, brandstoffenopslag', '(51.3) warmte-opwekking; toegeleverde warmte', '(51.30) warmte-opwekking; toegeleverde warmte, algemeen (verzamelniveau)', '(51.31) warmte-opwekking; toegeleverde warmte, water tot 140° c.', '(51.32) warmte-opwekking; toegeleverde warmte, water boven 140° c.', '(51.33) warmte-opwekking; toegeleverde warmte, stoom', '(51.36) warmte-opwekking; toegeleverde warmte, gecombineerde tapwaterverwarming', '(51.4) warmte-opwekking; warmte-krachtkoppeling', '(51.40) warmte-opwekking; warmte-krachtkoppeling, algemeen (verzamelniveau)', '(51.41) warmte-opwekking; warmte-krachtkoppeling, total-energy', '(51.44) warmte-opwekking; warmte-krachtkoppeling, schoorstenen/kanalen (niet bouwkundig)', '(51.46) warmte-opwekking; warmte-krachtkoppeling, gecombineerde tapwater verwarming', '(51.49) warmte-opwekking; warmte-krachtkoppeling, brandstoffenopslag', '(51.5) warmte-opwekking; bijzonder', '(51.50) warmte-opwekking; bijzonder, algemeen (verzamelniveau)', '(51.51) warmte-opwekking; bijzonder, warmtepomp', '(51.52) warmte-opwekking; bijzonder, zonnecollectoren', '(51.53) warmte-opwekking; bijzonder, accumulatie', '(51.54) warmte-opwekking; bijzonder, aardwarmte', '(51.55) warmte-opwekking; bijzonder, kernenergie', '(52) Afvoeren', '(52.0) afvoeren; algemeen', '(52.1) afvoeren; regenwater', '(52.10) afvoeren; regenwater, algemeen (verzamelniveau)', '(52.11) afvoeren; regenwater, afvoerinstallatie; in het gebouw', '(52.12) afvoeren; regenwater, afvoerinstallatie; buiten het gebouw', '(52.16) afvoeren; regenwater, pompsysteem', '(52.2) afvoeren; fecaliën', '(52.20) afvoeren; fecaliën, algemeen (verzamelniveau)', '(52.21) afvoeren; fecaliën, standaardsysteem', '(52.22) afvoeren; fecaliën, vacuümsysteem', '(52.23) afvoeren; fecaliën, overdruksysteem', '(52.26) afvoeren; fecaliën, pompsysteem', '(52.3) afvoeren; afvalwater', '(52.30) afvoeren; afvalwater, algemeen (verzamelniveau)', '(52.31) afvoeren; afvalwater, huishoudelijk afval', '(52.32) afvoeren; afvalwater, bedrijfsafval', '(52.36) afvoeren; afvalwater, pompsysteem', '(52.4) afvoeren; gecombineerd', '(52.40) afvoeren; gecombineerd, algemeen (verzamelniveau)', '(52.41) afvoeren; gecombineerd, geïntegreerd systeem', '(52.46) afvoeren; gecombineerd, pompsysteem', '(52.5) afvoeren; speciaal', '(52.50) afvoeren; speciaal, algemeen (verzamelniveau)', '(52.51) afvoeren; speciaal, chemisch verontreinigd afvalwater', '(52.52) afvoeren; speciaal, biologisch besmet afvalwater', '(52.53) afvoeren; speciaal, radioactief besmet afvalwater', '(52.56) afvoeren; speciaal, pompsysteem', '(52.6) afvoeren; vast vuil', '(52.60) afvoeren; vast vuil, algemeen (verzamelniveau)', '(52.61) afvoeren; vast vuil, stortkokers', '(52.62) afvoeren; vast vuil, vacuümsysteem', '(52.63) afvoeren; vast vuil, persluchtsysteem', '(52.64) afvoeren; vast vuil, verdichtingsysteem', '(52.65) afvoeren; vast vuil, verbrandingsysteem', '(53) Water', '(53.0) water; algemeen', '(53.1) water; drinkwater', '(53.10) water; drinkwater, algemeen (verzamelniveau)', '(53.11) water; drinkwater, netaansluiting', '(53.12) water; drinkwater, bronaansluiting', '(53.13) water; drinkwater, reinwaterkelderaansluiting', '(53.14) water; drinkwater, drukverhoging', '(53.19) water; drinkwater, opslagtanks', '(53.2) water; verwarmd tapwater', '(53.20) water; verwarmd tapwater, algemeen (verzamelniveau)', '(53.21) water; verwarmd tapwater, direct verwarmd met voorraad', '(53.22) water; verwarmd tapwater, indirect verwarmd met voorraad', '(53.23) water; verwarmd tapwater, doorstroom; direct verwarmd', '(53.24) water; verwarmd tapwater, doorstroom; indirect verwarmd', '(53.3) water; bedrijfswater', '(53.30) water; bedrijfswater, algemeen (verzamelniveau)', '(53.31) water; bedrijfswater, onthard-watersysteem', '(53.32) water; bedrijfswater, demi-watersysteem', '(53.33) water; bedrijfswater, gedistilleerd-watersysteem', '(53.34) water; bedrijfswater, zwembad-watersysteem', '(53.4) water; gebruiksstoom en condens', '(53.40) water; gebruiksstoom en condens, algemeen (verzamelniveau)', '(53.41) water; gebruiksstoom en condens, lage-druk stoomsysteem', '(53.42) water; gebruiksstoom en condens, hoge-druk stoomsysteem', '(53.44) water; gebruiksstoom en condens, condens verzamelsysteem', '(53.5) water; waterbehandeling', '(53.50) water; waterbehandeling, algemeen (verzamelniveau)', '(53.51) water; waterbehandeling, filtratiesysteem', '(53.52) water; waterbehandeling, absorptiesysteem', '(53.53) water; waterbehandeling, ontgassingsysteem', '(53.54) water; waterbehandeling, destillatiesysteem', '(54) Gassen', '(54.0) gassen; algemeen', '(54.1) gassen; brandstof', '(54.10) gassen; brandstof, algemeen (verzamelniveau)', '(54.11) gassen; brandstof, aardgasvoorziening', '(54.12) gassen; brandstof, butaanvoorziening', '(54.13) gassen; brandstof, propaanvoorziening', '(54.14) gassen; brandstof, lpg-voorziening', '(54.2) gassen; perslucht en vacuüm', '(54.20) gassen; perslucht en vacuüm, algemeen (verzamelniveau)', '(54.21) gassen; perslucht en vacuüm, persluchtvoorziening', '(54.22) gassen; perslucht en vacuüm, vacuümvoorziening', '(54.3) gassen; medisch', '(54.30) gassen; medisch, algemeen (verzamelniveau)', '(54.31) gassen; medisch, zuurstofvoorziening', '(54.32) gassen; medisch, carbogeenvoorziening', '(54.33) gassen; medisch, lachgasvoorziening', '(54.34) gassen; medisch, koolzuurvoorziening', '(54.35) gassen; medisch, medische luchtvoorziening', '(54.4) gassen; technisch', '(54.40) gassen; technisch, algemeen (verzamelniveau)', '(54.41) gassen; technisch, stikstofvoorziening', '(54.42) gassen; technisch, waterstofvoorziening', '(54.43) gassen; technisch, argonvoorziening', '(54.44) gassen; technisch, heliumvoorziening', '(54.45) gassen; technisch, acetyleenvoorziening', '(54.46) gassen; technisch, propaanvoorziening', '(54.47) gassen; technisch, koolzuurvoorziening', '(54.5) gassen; bijzonder', '(54.50) gassen; bijzonder, algemeen (verzamelniveau)', '(54.51) gassen; bijzonder, voorziening; zuivere gassen', '(54.52) gassen; bijzonder, voorziening; menggassen', '(55) Koude-opwekking en distributie', '(55.0) koude-opwekking; algemeen', '(55.1) koude-opwekking; lokaal', '(55.10) koude-opwekking; lokaal, algemeen (verzamelniveau)', '(55.11) koude-opwekking; lokaal, raamkoelers', '(55.12) koude-opwekking; lokaal, splitsystemen', '(55.13) koude-opwekking; lokaal, compactsystemen', '(55.2) koude-opwekking; centraal', '(55.20) koude-opwekking; centraal, algemeen (verzamelniveau)', '(55.21) koude-opwekking; centraal, compressorensystemen', '(55.22) koude-opwekking; centraal, absorptiesystemen', '(55.23) koude-opwekking; centraal, grondwatersystemen', '(55.24) koude-opwekking; centraal, oppervlaktewatersystemen', '(55.3) koude-opwekking; distributie', '(55.30) koude-opwekking; distributie, algemeen (verzamelniveau)', '(55.31) koude-opwekking; distributie, distributiesystemen', '(56) Warmtedistributie', '(56.0) warmtedistributie; algemeen', '(56.1) warmtedistributie; water', '(56.10) warmtedistributie; water, algemeen (verzamelniveau)', '(56.11) warmtedistributie; water, radiatorsystemen', '(56.12) warmtedistributie; water, convectorsystemen', '(56.13) warmtedistributie; water, vloerverwarmingssystemen', '(56.2) warmtedistributie; stoom', '(56.20) warmtedistributie; stoom, algemeen (verzamelniveau)', '(56.21) warmtedistributie; stoom, radiatorsystemen', '(56.22) warmtedistributie; stoom, convectorsystemen', '(56.24) warmtedistributie; stoom, stralingspanelen', '(56.3) warmtedistributie; lucht', '(56.30) warmtedistributie; lucht, algemeen (verzamelniveau)', '(56.31) warmtedistributie; lucht, direct distributiesysteem', '(56.32) warmtedistributie; lucht, systeem met stralingsoverdracht', '(56.4) warmtedistributie; bijzonder', '(56.40) warmtedistributie; bijzonder, algemeen (verzamelniveau)', '(56.41) warmtedistributie; bijzonder, zonnewarmtesystemen', '(56.42) warmtedistributie; bijzonder, aardwarmtesystemen', '(56.43) warmtedistributie; bijzonder, centraal', '(57) Luchtbehandeling', '(57.0) luchtbehandeling; algemeen', '(57.1) luchtbehandeling; natuurlijke ventilatie', '(57.10) luchtbehandeling; natuurlijke ventilatie, algemeen (verzamelniveau)', '(57.11) luchtbehandeling; natuurlijke ventilatie, voorzieningen; regelbaar', '(57.12) luchtbehandeling; natuurlijke ventilatie, voorzieningen; niet regelbaar', '(57.2) luchtbehandeling; lokale mechanische afzuiging', '(57.20) luchtbehandeling; lokale mechanische afzuiging, algemeen (verzamelniveau)', '(57.21) luchtbehandeling; lokale mechanische afzuiging, afzuiginstallatie', '(57.3) luchtbehandeling; centrale mechanische afzuiging', '(57.30) luchtbehandeling; centrale mechanische afzuiging, algemeen (verzamelniveau)', '(57.31) luchtbehandeling; centrale mechanische afzuiging, afzuiginstallatie', '(57.4) luchtbehandeling; lokale mechanische ventilatie', '(57.40) luchtbehandeling; lokale mechanische ventilatie, algemeen (verzamelniveau)', '(57.41) luchtbehandeling; lokale mechanische ventilatie, ventilatie-installatie', '(57.5) luchtbehandeling; centrale mechanische ventilatie', '(57.50) luchtbehandeling; centrale mechanische ventilatie, algemeen (verzamelniveau)', '(57.51) luchtbehandeling; centrale mechanische ventilatie, ventilatie-installatie', '(57.52) luchtbehandeling; centrale mechanische ventilatie, ventilatie-inst. met warmteterugwinning', '(57.6) luchtbehandeling; lokaal', '(57.60) luchtbehandeling; lokaal, algemeen (verzamelniveau)', '(57.61) luchtbehandeling; lokaal, luchtbehandelingsinstallatie', '(57.7) luchtbehandeling; centraal', '(57.70) luchtbehandeling; centraal, algemeen (verzamelniveau)', '(57.71) luchtbehandeling; centraal, luchtbehandelingsinstallatie', '(58) Regeling klimaat en sanitair', '(58.0) regeling klimaat en sanitair; algemeen', '(58.1) regeling klimaat en sanitair; specifieke regelingen', '(58.10) regeling klimaat en sanitair; specifieke regelingen, algemeen (verzamelniveau)', '(58.11) regeling klimaat en sanitair; specifieke regelingen, specifieke regeling', '(58.12) regeling klimaat en sanitair; specifieke regelingen, gecombineerde regeling', '(58.2) regeling klimaat en sanitair; centrale melding, meting en sturing', '(58.20) regeling klimaat en sanitair; centrale melding, meting en sturing, algemeen (verzamelniveau)', '(58.21) regeling klimaat en sanitair; centrale melding, meting en sturing, specifieke regeling', '(58.22) regeling klimaat en sanitair; centrale melding, meting en sturing, gecombineerde regeling', '(59) -gereserveerd-', '(6-) INSTALLATIES ELEKTROTECHNISCH', '(60) -gereserveerd-', '(61) Centrale elektrotechnische voorzieningen', '(61.0) centrale elektrotechnische voorzieningen; algemeen', '(61.1) centrale elektrotechnische voorzieningen; energie, noodstroom', '(61.10) centrale elektrotechnische voorz.; energie, noodstroom, algemeen (verzamelniveau)', '(61.11) centrale elektrotechnische voorz.; energie, noodstroom, eigen energieopwekking', '(61.2) centrale elektrotechnische voorzieningen; aarding', '(61.20) centrale elektrotechnische voorz.; aarding, algemeen (verzamelniveau)', '(61.21) centrale elektrotechnische voorz.; aarding, veiligheidsaarding', '(61.22) centrale elektrotechnische voorz.; aarding, medische aarding', '(61.23) centrale elektrotechnische voorz.; aarding, speciale aarding', '(61.24) centrale elektrotechnische voorz.; aarding, statische elektriciteit', '(61.25) centrale elektrotechnische voorz.; aarding, bliksemafleiding', '(61.26) centrale elektrotechnische voorz.; aarding, potentiaalvereffening', '(61.3) centrale elektrotechnische voorzieningen; kanalisatie', '(61.30) centrale elektrotechnische voorz.; kanalisatie, algemeen (verzamelniveau)', '(61.31) centrale elektrotechnische voorz.; kanalisatie, t.b.v. installaties voor hoge spanning', '(61.32) centrale elektrotechnische voorz.; kanalisatie, t.b.v. installaties voor lage spanning', '(61.33) centrale elektr. voorz.; kanalisatie, t.b.v. inst. v. communicatie of beveil.', '(61.4) centrale elektrotechnische voorzieningen; energie, hoogspanning', '(61.40) centrale elektrotechnische voorz.; energie, hoogspanning, algemeen', '(61.41) centrale elektrotechnische voorz.; energie, hoogspanning, 1 kv en hoger', '(61.5) centrale elektrotechnische voorzieningen; energie, laagspanning', '(61.50) centrale elektrotechnische voorz.; energie, laagspanning, algemeen', '(61.51) centrale elektrotechnische voorz.; energie, laagspanning, 1 kv  <> 100 v', '(61.6) centrale elektrotechnische voorzieningen; energie, zeer lage spanning', '(61.60) centrale elektrotechnische voorz.; energie, zeer lage spanning, algemeen', '(61.61) centrale elektrotechnische voorz.; energie, zeer lage spanning, < 100 v', '(61.7) centrale elektrotechnische voorzieningen; bliksemafleiding', '(61.70) centrale elektrotechnische voorz.; bliksemafleiding, algemeen', '(61.71) centrale elektrotechnische voorz.; bliksemafleiding', '(62) Krachtstroom', '(62.0) krachtstroom; algemeen', '(62.1) krachtstroom; hoogspanning', '(62.10) krachtstroom; hoogspanning, algemeen (verzamelniveau)', '(62.11) krachtstroom; hoogspanning, 1 t/m 3 kv', '(62.12) krachtstroom; hoogspanning, boven 3 kv', '(62.2) krachtstroom; laagspanning, onbewaakt', '(62.20) krachtstroom; laagspanning, onbewaakt, algemeen (verzamelniveau)', '(62.21) krachtstroom; laagspanning, onbewaakt, 220/230 v - 380 v', '(62.22) krachtstroom; laagspanning, onbewaakt, 380 v - 660 v', '(62.23) krachtstroom; laagspanning, onbewaakt, 660 v - 1 kv', '(62.3) krachtstroom; laagspanning, bewaakt', '(62.30) krachtstroom; laagspanning, bewaakt, algemeen (verzamelniveau)', '(62.31) krachtstroom; laagspanning, bewaakt, 220/230 v - 380 v', '(62.32) krachtstroom; laagspanning, bewaakt, 380 v - 660 v', '(62.33) krachtstroom; laagspanning, bewaakt, 660 v - 1 kv', '(62.4) krachtstroom; laagspanning, gestabiliseerd', '(62.40) krachtstroom; laagspanning, gestabiliseerd, algemeen (verzamelniveau)', '(62.41) krachtstroom; laagspanning, gestabiliseerd, 220/230 v - 380 v', '(62.42) krachtstroom; laagspanning, gestabiliseerd, 380 v - 660 v', '(62.43) krachtstroom; laagspanning, gestabiliseerd, 660 v - 1 kv', '(62.5) krachtstroom; laagspanning, gecompenseerd', '(62.50) krachtstroom; laagspanning, gecompenseerd, algemeen (verzamelniveau)', '(62.51) krachtstroom; laagspanning, gecompenseerd, 220/230 v - 380 v', '(62.52) krachtstroom; laagspanning, gecompenseerd, 380 v - 660 v', '(62.53) krachtstroom; laagspanning, gecompenseerd, 660 v - 1 kv', '(63) Verlichting', '(63.0) verlichting; algemeen', '(63.1) verlichting; standaard, onbewaakt', '(63.10) verlichting; standaard, onbewaakt, algemeen (verzamelniveau)', '(63.11) verlichting; standaard, onbewaakt, 220/230 v', '(63.12) verlichting; standaard, onbewaakt, 115 v', '(63.13) verlichting; standaard, onbewaakt, 42 v', '(63.14) verlichting; standaard, onbewaakt, 24 v', '(63.2) verlichting; calamiteiten, decentraal', '(63.20) verlichting; calamiteiten, decentraal gevoed, algemeen (verzamelniveau)', '(63.23) verlichting; calamiteiten, decentraal gevoed, 42 v', '(63.24) verlichting; calamiteiten, decentraal gevoed, 24 v', '(63.3) verlichting; bijzonder, onbewaakt', '(63.30) verlichting; bijzonder, onbewaakt, algemeen (verzamelniveau)', '(63.31) verlichting; bijzonder, onbewaakt, 220/230 v', '(63.32) verlichting; bijzonder, onbewaakt, 115 v', '(63.33) verlichting; bijzonder, onbewaakt, 42 v', '(63.34) verlichting; bijzonder, onbewaakt, 24 v', '(63.4) verlichting; standaard, bewaakt', '(63.40) verlichting; standaard, bewaakt, algemeen (verzamelniveau)', '(63.41) verlichting; standaard, bewaakt, 220/230 v', '(63.42) verlichting; standaard, bewaakt, 115 v', '(63.43) verlichting; standaard, bewaakt, 42 v', '(63.44) verlichting; standaard, bewaakt, 24 v', '(63.5) verlichting; calamiteiten, centraal', '(63.50) verlichting; calamiteiten, centraal gevoed, algemeen (verzamelniveau)', '(63.51) verlichting; calamiteiten, centraal gevoed, 220/230 v', '(63.52) verlichting; calamiteiten, centraal gevoed, 115 v', '(63.53) verlichting; calamiteiten, centraal gevoed, 42 v', '(63.54) verlichting; calamiteiten, centraal gevoed, 24 v', '(63.6) verlichting; bijzonder, bewaakt', '(63.60) verlichting; bijzonder, bewaakt, algemeen (verzamelniveau)', '(63.61) verlichting; bijzonder, bewaakt, 220/230 v', '(63.62) verlichting; bijzonder, bewaakt, 115 v', '(63.63) verlichting; bijzonder, bewaakt, 42 v', '(63.64) verlichting; bijzonder, bewaakt, 24 v', '(63.7) verlichting; bijzonder, reclame', '(63.70) verlichting; bijzonder, reclame, algemeen (verzamelniveau)', '(63.71) verlichting; bijzonder, reclame, 220/230 v', '(63.72) verlichting; bijzonder, reclame, 115 v', '(63.73) verlichting; bijzonder, reclame, 42 v', '(63.74) verlichting; bijzonder, reclame, 24 v', '(63.75) verlichting; bijzonder, reclame, 1 kv en hoger', '(64) Communicatie', '(64.0) communicatie; algemeen', '(64.1) communicatie; signalen', '(64.10) communicatie; overdracht van signalen, algemeen (verzamelniveau)', '(64.11) communicatie; overdracht van signalen, algemene signaleringen', '(64.12) communicatie; overdracht van signalen, algemene personenoproep', '(64.13) communicatie; overdracht van signalen, tijdsignalering', '(64.14) communicatie; overdracht van signalen, aanwezigheid-/beletsignalering', '(64.2) communicatie; geluiden', '(64.20) communicatie; overdracht van geluid/spraak, algemeen (verzamelniveau)', '(64.21) communicatie; overdracht van geluid/spraak, telefoon', '(64.22) communicatie; overdracht van geluid/spraak, intercom', '(64.23) communicatie; overdracht van geluid/spraak, radio/mobilofoon', '(64.24) communicatie; overdracht van geluid/spraak, geluidsdistributie', '(64.25) communicatie; overdracht van geluid/spraak, vertaalsystemen', '(64.26) communicatie; overdracht van geluid/spraak, conferentiesystemen', '(64.3) communicatie; beelden', '(64.30) communicatie; overdracht van beelden, algemeen (verzamelniveau)', '(64.31) communicatie; overdracht van beelden, gesloten televisiecircuits', '(64.32) communicatie; overdracht van beelden, beeldreproductie', '(64.33) communicatie; overdracht van beelden, film/dia/overhead', '(64.4) communicatie; data', '(64.40) communicatie; overdracht van data, algemeen (verzamelniveau)', '(64.41) communicatie; overdracht van data, gesloten datanet', '(64.42) communicatie; overdracht van data, openbaar datanet', '(64.5) communicatie; geïntegreerde systemen', '(64.50) communicatie; geïntegreerde systemen, algemeen (verzamelniveau)', '(64.51) communicatie; geïntegreerde systemen, gesloten netwerken', '(64.52) communicatie; geïntegreerde systemen, openbare netwerken', '(64.6) communicatie; antenne-inrichtingen', '(64.60) communicatie; antenne-inrichtingen, algemeen', '(65) Beveiliging', '(65.0) beveiliging; algemeen', '(65.1) beveiliging; brand', '(65.10) beveiliging; brand, algemeen (verzamelniveau)', '(65.11) beveiliging; brand, detectie en alarmering', '(65.12) beveiliging; brand, deurvergrendelingen en -ontgrendelingen', '(65.13) beveiliging; brand, brandbestrijding', '(65.2) beveiliging; braak', '(65.20) beveiliging; braak, algemeen (verzamelniveau)', '(65.21) beveiliging; braak, detectie en alarmering', '(65.22) beveiliging; braak, toegangscontrole', '(65.3) beveiliging; overlast, detectie en alarmering', '(65.30) beveiliging; overlast, detectie en alarmering, algemeen (verzamelniveau)', '(65.31) beveiliging; overlast, detectie en alarmering, zonweringsinstallatie', '(65.32) beveiliging; overlast, detectie en alarmering, elektromagnetische voorzieningen', '(65.33) beveiliging; overlast, detectie en alarmering, elektromagnetische voorzieningen', '(65.34) beveiliging; overlast, detectie en alarmering, overspanningsbeveiliging', '(65.35) beveiliging; overlast, detectie en alarmering, gassenbeveiliging', '(65.36) beveiliging; overlast, detectie en alarmering, vloeistofbeveiliging', '(65.37) beveiliging; overlast, detectie en alarmering, stralingsbeveiliging', '(65.39) beveiliging; overlast, detectie en alarmering, overige beveiligingen', '(65.4) beveiliging; sociale alarmering', '(65.40) beveiliging; sociale alarmering, algemeen (verzamelniveau)', '(65.41) beveiliging; sociale alarmering, nooddetectie; gesloten systemen', '(65.42) beveiliging; sociale alarmering, nooddetectie; open systemen', '(65.5) beveiliging; milieu-overlast, detectie en alarmering', '(65.50) beveiliging; milieu-overlast, detectie en alarmering, algemeen (verzamelniveau)', '(66) Transport', '(66.0) transport; algemeen', '(66.1) transport; liften', '(66.10) transport; liften, algemeen (verzamelniveau)', '(66.11) transport; liften, elektrische liften', '(66.12) transport; liften, hydraulische liften', '(66.13) transport; liften, trapliften', '(66.14) transport; liften, heftableaus', '(66.2) transport; roltrappen en rolpaden', '(66.20) transport; roltrappen en rolpaden, algemeen (verzamelniveau)', '(66.21) transport; roltrappen en rolpaden, roltrappen', '(66.22) transport; roltrappen en rolpaden, rolpaden', '(66.3) transport; goederen', '(66.30) transport; goederen, algemeen (verzamelniveau)', '(66.31) transport; goederen, goederenliften', '(66.32) transport; goederen, goederenheffers', '(66.33) transport; goederen, baantransportmiddelen', '(66.34) transport; goederen, bandtransportmiddelen', '(66.35) transport; goederen, baktransportmiddelen', '(66.36) transport; goederen, hijswerktuigen', '(66.37) transport; goederen, vrije-baan-transportvoertuigen', '(66.4) transport; documenten', '(66.40) transport; documenten, algemeen (verzamelniveau)', '(66.41) transport; documenten, buizenpost', '(66.42) transport; documenten, railcontainer banen', '(66.44) transport; documenten, bandtransportmiddelen', '(67) Gebouwbeheervoorzieningen', '(67.0) gebouwbeheervoorzieningen; algemeen', '(67.1) gebouwbeheervoorzieningen; bediening en signalering', '(67.10) gebouwbeheervoorzieningen; bediening en signalering, algemeen (verzamelniveau)', '(67.11) gebouwbeheervoorzieningen; bediening en signalering, elektrotechnische systemen', '(67.12) gebouwbeheervoorzieningen; bediening en signalering, optische systemen', '(67.13) gebouwbeheervoorzieningen; bediening en signalering, pneumatische systemen', '(67.14) gebouwbeheervoorzieningen; bediening en signalering, geïntegreerde systemen', '(67.2) gebouwbeheervoorzieningen; automatisering', '(67.20) gebouwbeheervoorzieningen; gebouwautomatisering, algemeen (verzamelniveau)', '(67.21) gebouwbeheervoorzieningen; gebouwautomatisering, elektrotechnische systemen', '(67.22) gebouwbeheervoorzieningen; gebouwautomatisering, optische systemen', '(67.23) gebouwbeheervoorzieningen; gebouwautomatisering, pneumatische systemen', '(67.24) gebouwbeheervoorzieningen; gebouwautomatisering, geïntegreerde systemen', '(67.3) gebouwbeheervoorzieningen; regeling klimaat en sanitair op afstand', '(67.30) gebouwbeheervoorz.; reg. klimaat en sanitair (op afstand), alg. (verzamelniveau)', '(67.31) gebouwbeheervoorz.; reg. klimaat en sanitair (op afstand), elektr. systemen', '(67.32) gebouwbeheervoorz.; reg. klimaat en sanitair (op afstand), optische systemen', '(67.33) gebouwbeheervoorz.; reg. klimaat en sanitair (op afstand), pneum. systemen', '(67.34) gebouwbeheervoorz.; reg. klimaat en sanitair (op afstand), geïntegreerde systemen', '(68) -gereserveerd-', '(69) -gereserveerd-', '(7-) VASTE VOORZIENINGEN', '(70) -gereserveerd-', '(71) Vaste verkeersvoorzieningen', '(71.0) vaste verkeersvoorzieningen; algemeen', '(71.1) vaste verkeersvoorzieningen; standaard', '(71.10) vaste verkeersvoorzieningen; standaard, algemeen (verzamelniveau)', '(71.11) vaste verkeersvoorzieningen; standaard, meubileringen', '(71.12) vaste verkeersvoorzieningen; standaard, bewegwijzeringen', '(71.13) vaste verkeersvoorzieningen; standaard, kunstwerken', '(71.14) vaste verkeersvoorzieningen; standaard, decoraties e.d.', '(71.2) vaste verkeersvoorzieningen; bijzonder', '(71.20) vaste verkeersvoorzieningen; bijzonder, algemeen (verzamelniveau)', '(71.21) vaste verkeersvoorzieningen; bijzonder, meubileringen', '(71.22) vaste verkeersvoorzieningen; bijzonder, bewegwijzeringen', '(71.23) vaste verkeersvoorzieningen; bijzonder, specifieke voorzieningen', '(72) Vaste gebruikersvoorzieningen', '(72.0) vaste gebruikersvoorzieningen; algemeen', '(72.1) vaste gebruikersvoorzieningen; standaard', '(72.10) vaste gebruikersvoorzieningen; standaard, algemeen (verzamelniveau)', '(72.11) vaste gebruikersvoorzieningen; standaard, meubilering', '(72.12) vaste gebruikersvoorzieningen; standaard, lichtweringen', '(72.13) vaste gebruikersvoorzieningen; standaard, gordijnvoorzieningen', '(72.14) vaste gebruikersvoorzieningen; standaard, beschermende voorzieningen', '(72.2) vaste gebruikersvoorzieningen; bijzonder', '(72.20) vaste gebruikersvoorzieningen; bijzonder, algemeen (verzamelniveau)', '(72.21) vaste gebruikersvoorzieningen; bijzonder, meubilering voor specifieke functiedoeleinden', '(72.22) vaste gebruikersvoorzieningen; bijzonder, instrumenten/apparatuur', '(73) Vaste keukenvoorzieningen', '(73.0) vaste keukenvoorzieningen; algemeen', '(73.1) vaste keukenvoorzieningen; standaard', '(73.10) vaste keukenvoorzieningen; standaard, algemeen (verzamelniveau)', '(73.11) vaste keukenvoorzieningen; standaard, keukenmeubilering', '(73.12) vaste keukenvoorzieningen; standaard, keukenapparatuur', '(73.2) vaste keukenvoorzieningen; bijzonder', '(73.20) vaste keukenvoorzieningen; bijzonder, algemeen (verzamelniveau)', '(73.21) vaste keukenvoorzieningen; bijzonder, keukenmeubilering', '(73.22) vaste keukenvoorzieningen; bijzonder, keukenapparatuur', '(74) Vaste sanitaire voorzieningen', '(74.0) vaste sanitaire voorzieningen; algemeen', '(74.1) vaste sanitaire voorzieningen; standaard', '(74.10) vaste sanitaire voorzieningen; standaard, algemeen (verzamelniveau)', '(74.11) vaste sanitaire voorzieningen; standaard, sanitaire toestellen; normaal', '(74.12) vaste sanitaire voorzieningen; standaard, sanitaire toestellen; aangepast', '(74.13) vaste sanitaire voorzieningen; standaard, accessoires', '(74.2) vaste sanitaire voorzieningen; bijzonder', '(74.20) vaste sanitaire voorzieningen; bijzonder, algemeen (verzamelniveau)', '(74.21) vaste sanitaire voorzieningen; bijzonder, sanitaire toestellen voor bijzondere toepassing', '(74.22) vaste sanitaire voorzieningen; bijzonder, ingebouwde sanitaire voorzieningen', '(75) Vaste onderhoudsvoorzieningen', '(75.0) vaste onderhoudsvoorzieningen; algemeen', '(75.1) vaste onderhoudsvoorzieningen; standaard', '(75.10) vaste onderhoudsvoorzieningen; standaard, algemeen (verzamelniveau)', '(75.11) vaste onderhoudsvoorzieningen; standaard, gebouwonderhoudsvoorzieningen', '(75.12) vaste onderhoudsvoorzieningen; standaard, interieur onderhoudsvoorzieningen', '(75.13) vaste onderhoudsvoorzieningen; standaard, gevelonderhoudsvoorzieningen', '(75.2) vaste onderhoudsvoorzieningen; bijzonder', '(75.20) vaste onderhoudsvoorzieningen; bijzonder, algemeen (verzamelniveau)', '(75.21) vaste onderhoudsvoorzieningen; bijzonder, gebouwonderhoudsvoorzieningen', '(75.22) vaste onderhoudsvoorzieningen; bijzonder, interieuronderhoudsvoorzieningen', '(75.23) vaste onderhoudsvoorzieningen; bijzonder, gemechaniseerde gevelonderhoudsvoorzieningen', '(76) Vaste opslagvoorzieningen', '(76.0) vaste opslagvoorzieningen; algemeen', '(76.1) vaste opslagvoorzieningen; standaard', '(76.10) vaste opslagvoorzieningen; standaard, algemeen (verzamelniveau)', '(76.11) vaste opslagvoorzieningen; standaard, meubileringen', '(76.2) vaste opslagvoorzieningen; bijzonder', '(76.20) vaste opslagvoorzieningen; bijzonder, algemeen (verzamelniveau)', '(76.21) vaste opslagvoorzieningen; bijzonder, gemechaniseerde voorzieningen', '(76.22) vaste opslagvoorzieningen; bijzonder, specifieke voorzieningen', '(77) -gereserveerd-', '(78) -gereserveerd-', '(79) -gereserveerd-', '(8-) LOSSE INVENTARIS', '(80) -gereserveerd-', '(81) Losse verkeersinventaris', '(81.0) losse verkeersinventaris; algemeen', '(81.1) losse verkeersinventaris; standaard', '(81.10) losse verkeersinventaris; standaard, algemeen (verzamelniveau)', '(81.11) losse verkeersinventaris; standaard, meubilering', '(81.12) losse verkeersinventaris; standaard, bewegwijzering', '(81.13) losse verkeersinventaris; standaard, kunstwerken', '(81.14) losse verkeersinventaris; standaard, decoraties e.d.', '(81.2) losse verkeersinventaris; bijzonder', '(81.20) losse verkeersinventaris; bijzonder, algemeen (verzamelniveau)', '(81.21) losse verkeersinventaris; bijzonder, meubilering', '(81.22) losse verkeersinventaris; bijzonder, bewegwijzering', '(81.23) losse verkeersinventaris; bijzonder, specifieke voorzieningen', '(82) Losse gebruikersinventaris', '(82.0) losse gebruikersinventaris; algemeen', '(82.1) losse gebruikersinventaris; standaard', '(82.10) losse gebruikersinventaris; standaard, algemeen (verzamelniveau)', '(82.11) losse gebruikersinventaris; standaard, meubilering', '(82.12) losse gebruikersinventaris; standaard, lichtweringen/verduisteringen', '(82.13) losse gebruikersinventaris; standaard, stofferingen', '(82.2) losse gebruikersinventaris; bijzonder', '(82.20) losse gebruikersinventaris; bijzonder, algemeen (verzamelniveau)', '(82.21) losse gebruikersinventaris; bijzonder, meubilering voor specifieke functiedoeleinden', '(82.22) losse gebruikersinventaris; bijzonder, instrumenten/apparatuur', '(83) Losse keukeninventaris', '(83.0) losse keukeninventaris; algemeen', '(83.1) losse keukeninventaris; standaard', '(83.10) losse keukeninventaris; standaard, algemeen (verzamelniveau)', '(83.11) losse keukeninventaris; standaard, keukenmeubilering', '(83.12) losse keukeninventaris; standaard, keukenapparatuur', '(83.13) losse keukeninventaris; standaard, kleine keukeninventaris', '(83.2) losse keukeninventaris; bijzonder', '(83.20) losse keukeninventaris; bijzonder, algemeen (verzamelniveau)', '(83.21) losse keukeninventaris; bijzonder, keukeninrichting', '(83.22) losse keukeninventaris; bijzonder, keukenapparatuur', '(83.23) losse keukeninventaris; bijzonder, kleine keukeninventaris', '(83.24) losse keukeninventaris; bijzonder, transportmiddelen', '(84) Losse sanitaire inventaris', '(84.0) losse sanitaire inventaris; algemeen', '(84.1) losse sanitaire inventaris; standaard', '(84.10) losse sanitaire inventaris; standaard, algemeen (verzamelniveau)', '(84.11) losse sanitaire inventaris; standaard, afvalvoorzieningen', '(84.12) losse sanitaire inventaris; standaard, voorzieningen t.b.v. hygiëne', '(84.13) losse sanitaire inventaris; standaard, accessoires', '(84.2) losse sanitaire inventaris; bijzonder', '(84.20) losse sanitaire inventaris; bijzonder, algemeen (verzamelniveau)', '(84.21) losse sanitaire inventaris; bijzonder, sanitaire toestellen voor bijzondere toepassing', '(85) Losse schoonmaakinventaris', '(85.0) losse schoonmaakinventaris; algemeen', '(85.1) losse schoonmaakinventaris; standaard', '(85.10) losse schoonmaakinventaris; standaard, algemeen (verzamelniveau)', '(85.11) losse schoonmaakinventaris; standaard, schoonmaakapparatuur', '(85.12) losse schoonmaakinventaris; standaard, vuilopslag', '(85.13) losse schoonmaakinventaris; standaard, vuiltransport', '(85.2) losse schoonmaakinventaris; bijzonder', '(85.20) losse schoonmaakinventaris; bijzonder, algemeen (verzamelniveau)', '(85.21) losse schoonmaakinventaris; bijzonder, schoonmaakapparatuur', '(85.22) losse schoonmaakinventaris; bijzonder, vuilopslag', '(85.23) losse schoonmaakinventaris; bijzonder, vuiltransport', '(86) Losse opslaginventaris', '(86.0) losse opslaginventaris; algemeen', '(86.1) losse opslaginventaris; standaard', '(86.10) losse opslaginventaris; standaard, algemeen (verzamelniveau)', '(86.11) losse opslaginventaris; standaard, meubileringen', '(86.2) losse opslaginventaris; bijzonder', '(86.20) losse opslaginventaris; bijzonder, algemeen (verzamelniveau)', '(86.21) losse opslaginventaris; bijzonder, gemechaniseerde voorzieningen', '(86.22) losse opslaginventaris; bijzonder, specifieke voorzieningen', '(87) -gereserveerd-', '(88) -gereserveerd-', '(89) -gereserveerd-', '(9-) TERREIN', '(90) -gereserveerd-', '(90.0) terrein', '(90.1) grondvoorzieningen', '(90.10) terrein; grondvoorzieningen, algemeen (verzamelniveau)', '(90.11) terrein; grondvoorzieningen, verwijderen obstakels', '(90.12) terrein; grondvoorzieningen, grondwaterverlagingen', '(90.13) terrein; grondvoorzieningen, drainagevoorzieningen', '(90.2) opstallen', '(90.20) terrein; opstallen, algemeen (verzamelniveau)', '(90.21) terrein; opstallen, gebouwtjes met speciale functie', '(90.22) terrein; opstallen, overkappingen', '(90.3) omheiningen', '(90.30) terrein; omheiningen, algemeen (verzamelniveau)', '(90.31) terrein; omheiningen, muren', '(90.32) terrein; omheiningen, hekwerken', '(90.33) terrein; omheiningen, overige afscheidingen', '(90.34) terrein; omheiningen, toegangen', '(90.4) terreinafwerkingen', '(90.40) terrein; terreinafwerkingen, algemeen (verzamelniveau)', '(90.41) terrein; terreinafwerkingen, verhardingen', '(90.42) terrein; terreinafwerkingen, beplantingen', '(90.43) terrein; terreinafwerkingen, waterpartijen', '(90.44) terrein; terreinafwerkingen, keerwanden en balustrades', '(90.45) terrein; terreinafwerkingen, pergola s', '(90.5) terreinvoorzieningen; werktuigbouwkundig', '(90.50) terrein; werktuigbouwkundig, algemeen (verzamelniveau)', '(90.51) terrein; werktuigbouwkundig, verwarmingsvoorzieningen', '(90.52) terrein; werktuigbouwkundig, afvoervoorzieningen', '(90.53) terrein; werktuigbouwkundig, watervoorzieningen', '(90.54) terrein; werktuigbouwkundig, gasvoorzieningen', '(90.55) terrein; werktuigbouwkundig, koudeopwekkingsvoorzieningen', '(90.56) terrein; werktuigbouwkundig, warmtedistributievoorzieningen', '(90.57) terrein; werktuigbouwkundig, luchtbehandelingsvoorzieningen', '(90.58) terrein; werktuigbouwkundig, regelingvoorzieningen', '(90.6) terreinvoorzieningen; elektrotechnisch', '(90.60) terrein; elektrotechnisch, algemeen (verzamelniveau)', '(90.61) terrein; elektrotechnisch, elektrotechnische en aardingsvoorzieningen', '(90.62) terrein; elektrotechnisch, krachtvoorzieningen', '(90.63) terrein; elektrotechnisch, lichtvoorzieningen', '(90.64) terrein; elektrotechnisch, communicatievoorzieningen', '(90.65) terrein; elektrotechnisch, beveiligingsvoorzieningen', '(90.66) terrein; elektrotechnisch, transportvoorzieningen', '(90.67) terrein; elektrotechnisch, beheervoorzieningen', '(90.7) terreininrichtingen; standaard', '(90.70) terrein; terreininrichtingen, standaard, algemeen (verzamelniveau)', '(90.71) terrein; terreininrichtingen, standaard, terreinmeubilering', '(90.72) terrein; terreininrichtingen, standaard, bewegwijzering', '(90.73) terrein; terreininrichtingen, standaard, kunstwerken', '(90.74) terrein; terreininrichtingen, standaard, decoraties e.d.', '(90.8) terreininrichtingen; bijzonder', '(90.80) terrein; terreininrichtingen, bijzonder, algemeen (verzamelniveau)', '(90.81) terrein; terreininrichtingen, bijzonder, terreinmeubilering', '(90.82) terrein; terreininrichtingen, bijzonder, specifieke voorzieningen', '(90.83) terrein; terreininrichtingen, bijzonder, bijzondere verhardingen', '(91) -gereserveerd-', '(92) -gereserveerd-', '(93) -gereserveerd-', '(94) -gereserveerd-', '(95) -gereserveerd-', '(96) -gereserveerd-', '(97) -gereserveerd-', '(98) -gereserveerd-', '(99) -gereserveerd']

        @nlsfb = SKUI::Textbox.new( get_nlsfb_type( entity ) )
        lbl = SKUI::Label.new( 'NL/SfB classification:', @nlsfb )

        # get the type name for entity
        @nlsfb.value = get_nlsfb_type( entity )
        
        # set tooltip
        @nlsfb.tooltip = 'Type a few characters to see possible values'
        
        # inject options list AFTER window is loaded. (?) could be done on initialisation
        PropertiesWindow.window.on( :ready ) { |control, value| # (?) Second argument needed?
          @nlsfb.options( list, 2 )
        }
        
        # on click: show complete list
        @nlsfb.on( :click ) { |control, value| # (?) Second argument needed?
          js_command = "$('#" + control.ui_id + "_ui').autocomplete('search', '');"
          js_command << "$('#" + control.ui_id + "_ui').select();"
          PropertiesWindow.window.webdialog.execute_script(js_command)
        }

        @nlsfb.on( :blur || :textchange ) { |control, value| # (?) Second argument needed?
          entity = Sketchup.active_model.selection[0]
          selected = get_nlsfb_type( entity )
          if control.value == "" || control.value == nil # (?) should nil be a value?
            unless selected.nil?
              entity.definition.remove_classification("NL-SfB 2005, tabel 1", selected)
            end
          else
            entity.definition.add_classification("NL-SfB 2005, tabel 1", control.value)
          end

          PropertiesWindow.update
        }

        @section.add_control( lbl )
        @section.add_control( @nlsfb )


      end # def add_nlsfb

      def update_material_list
        @material_list = Hash.new
        @material_list["Default"] = nil
        Sketchup.active_model.materials.each do | material |
          @material_list[material.display_name] = material
        end
      end # def update_material_list

      def update_materials
        if PropertiesWindow.ready
          entity = Sketchup.active_model.selection[0]
          update_material_list
          @materials.options( @material_list.keys )
          if entity
            if entity.material.nil?
              @materials.value = "Default"
            else
              @materials.value = entity.material.display_name
            end
          end
        end
      end

	  def update_layers
        if PropertiesWindow.ready
          entity = Sketchup.active_model.selection[0]
          list = Array.new
          Sketchup.active_model.layers.each do | layer |
            list << layer.name
          end
          @layers.options( list )
          if entity
            @layers.value = entity.layer.name
          end
        end
      end # def update_layers

      def update_type
        if PropertiesWindow.ready
          entity = Sketchup.active_model.selection[0]
          selected = get_ifc_type( entity )
          @type.value = selected
        end
      end # def update_type

      def update_nlsfb
        if PropertiesWindow.ready
          entity = Sketchup.active_model.selection[0]
          selected = get_nlsfb_type( entity )
          @nlsfb.value = selected
        end
      end # def update_type

      def update_name
        if PropertiesWindow.ready
          entity = Sketchup.active_model.selection[0]
          
          # get list of used component names
          list = Array.new
          Sketchup.active_model.definitions.each do | definition |
            list << definition.name
          end
          list.sort_by!(&:downcase) # alphabetize array ignoring case
          
          @name.options( list )
          if entity
            @name.value = entity.definition.name
          end
        end
      end # def update_name

      def get_ifc_type( entity )
        if entity.is_a? Sketchup::ComponentInstance
          type = entity.definition.get_attribute "AppliedSchemaTypes", "IFC 2x3"
          if type
            return type
          end
        end
        return ""
      end

      def get_nlsfb_type( entity )
        if entity.is_a? Sketchup::ComponentInstance
          type = entity.definition.get_attribute "AppliedSchemaTypes", "NL-SfB 2005, tabel 1"
          if type
            return type
          end
        end
        return ""
      end

      add_type( Sketchup.active_model.selection[0] )
      add_nlsfb( Sketchup.active_model.selection[0] )
      add_name( Sketchup.active_model.selection[0] )
      #add_description( Sketchup.active_model.selection[0] )
      add_materials()
      add_layers()
      update(Sketchup.active_model.selection)
    end # module EntityInfo
  end # module PropertiesWindow
 end # module IfcManager
end # module BimTools
