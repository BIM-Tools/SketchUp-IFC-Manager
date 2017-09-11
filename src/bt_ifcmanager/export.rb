#  export.rb
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
    require 'tempfile'
    require 'csv'
    require File.join(PLUGIN_PATH, 'update_ifc_fields.rb')

    # IFC object index number
    @row = 0 # (?) instance variable correct here?

    def export( file_path )

      model = Sketchup.active_model
      
      # update all IFC name fields with the component definition name
      # (?) is this necessary, or should this already be 100% correct at the time of export?
      update_ifc_fields( model )

      # make sure file_path ends in "ifc"
      unless file_path.split('.').last == "ifc"
        file_path << '.ifc' # (!) creates duplicate extentions when extention exists
      end

      # Export ifc file
      # status = model.export file_path, false
      temp_file = write_temp

      if temp_file
        fix_export( file_path, temp_file )
        temp_file.unlink
      end
    end # export
    
    # returns a hash containing the guids and objects for all component instances in the model
    # def get_guids( ent, guids )
      # ent.entities.each do | ins |
        # if ins.is_a? Sketchup::ComponentInstance
          # guids[ins.guid] = ins
          # get_guids( ins.definition, guids )
        # end
      # end
      # return guids
    # end # get_guids
    
    # returns an array containing all component instances in the model
    def get_instances( ent, instances )
      ent.entities.each do | ins |
        if ins.is_a? Sketchup::ComponentInstance
          
          # store type unless one of following
          list = ["IfcBuilding", "IfcSite"]#["IfcBuilding", "IfcBuildingStorey", "IfcSite", "IfcSpace"]
          type = ins.definition.get_attribute "AppliedSchemaTypes", "IFC 2x3"
          unless list.include? type
            instances << ins
          end
          get_instances( ins.definition, instances )
        end
      end
      return instances
    end # get_instances

    # returns a new guid
    # shouldn't this function be in some sort of basic library?
    def new_guid
      guid = '';22.times{|i|guid<<'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_$'[rand(64)]}
      return guid
    end
    
    # read temporary IFC file, write modified version to output IFC file
    def fix_export( file_path, temp_path )
      
      ifc_objects = Hash.new # collect ifc objects: guid[row]
      su_components = Hash.new # collect sketchup objects without matching GUID: componentdefinition[row]
      representations = Hash.new # collect ifc representation objects
      object_list = Hash.new # combination of ifc row index and sketchup component instance
      
      # get guids for all component instances from sketchup model
      #guids = Hash.new
      #get_guids( Sketchup.active_model, guids ) # get hash with sketchup guids[objects]
    
      # get names for all component instances from sketchup model
      instances = Array.new
      get_instances( Sketchup.active_model, instances ) # get hash with sketchup names[objects]
      
      # variable that helps to skip the header section
      skip = true
      
      # variable that helps search for representation object
      representation = false
      
      # counter for sketchup instance row index
      su_index = 0

      # open temp_ifc_file
      t = File.open(temp_path, "r")
      f = File.open(file_path, "w")

      # loop temp_ifc_file
      t.each_line{ |line|
        
        # check if line is in header / main / footer
        if line[0] == "#" # currently in main
        
          # set row number
          @row = line[1..(line.index(' '))].to_i
          
          #check if line contains a guid
          #guid = line[/'([^"]\S{21})'/] # get first set of quotes containing only word characters with length of 21
          #if guid
            #guid.gsub!(/\A'|'\Z/, '') # strip quotes
            
            # match the ifc row with a sketchup instance
            list = ["IfcBuildingStorey", "IfcSpace", "IfcBeam", "IfcBuildingElementProxy", "IfcColumn", "IfcCurtainWall", "IfcDoor", "IfcFooting", "IfcFurnishingElement", "IfcMember", "IfcPile", "IfcPlate", "IfcRailing", "IfcRamp", "IfcRampFlight", "IfcRoof", "IfcSlab", "IfcStair", "IfcStairFlight", "IfcWall", "IfcWallStandardCase", "IfcWindow"]
            if list.any? { |type| line.include?(type.upcase) }
              
              #if comp_name = line.scan(/'.*?'/)[1] # component name is the second string (between ' )
                #comp_name.gsub!(/\A'|'\Z/, '') # strip quotes
            
                # add elevation to IFCBUILDINGSTOREY
                if line.include?("IFCBUILDINGSTOREY")
                  
                  # Get instance elevation
                  elevation = instances[ su_index ].transformation.origin.z.to_mm.to_s
                  
                  # works only with exactly the current IFC implementation in sketchup                  
                  line.sub! '0.);', elevation + ");"
                end
                
                # check if there are any sketchup instances left
                if instances[ su_index ]
                  object_list[ @row ] = instances[ su_index ]
                end
                
                # forward su counter
                su_index +=1
              #end
            end
            
            # check if object type needs a material
            list = ["IfcBeam", "IfcBuildingElementProxy", "IfcColumn", "IfcCurtainWall", "IfcDoor", "IfcFooting", "IfcFurnishingElement", "IfcMember", "IfcPile", "IfcPlate", "IfcRailing", "IfcRamp", "IfcRampFlight", "IfcRoof", "IfcSlab", "IfcStair", "IfcStairFlight", "IfcWall", "IfcWallStandardCase", "IfcWindow"]
            if list.any? { |type| line.include?(type.upcase) }
              
              # check if guid is in sketchup guid list
              #if guids.has_key?(guid)
              #
              #  # if true add to row+object to objects hash
              #  ifc_objects[guid] = @row
              #  
              #  # and set representation to the object layer for search for the next IFCSHAPEREPRESENTATION
              #  representation = guids[guid].layer
              #end
              
              # match against component name
              if comp_name = line.scan(/'.*?'/)[1] # component name is the second string (between ' )
                comp_name.gsub!(/\A'|'\Z/, '') # strip quotes
                
                ifc_objects[@row] = comp_name
                
                if component = Sketchup.active_model.definitions[comp_name]
                  su_components[@row] = component
                  
                  # and set representation to the object layer for search for the next IFCSHAPEREPRESENTATION
                  representation = @row
                end
              end
            
            # add longname to IFCSPACE
            elsif line.include?("IFCSPACE")
              # replace the first $ with the name
              # works only with exactly the current IFC implementation in sketchup
              name = line[/\', #2, (.*?), '/,1]
              line.sub! '$, $, $, $)', name + ", $, $, $)" # (!)Apostrophes in component name should be escaped!
            end
          if representation != false && line.include?("IFCSHAPEREPRESENTATION")
            
            representations[representation] = @row #sketchup_object.layer
            
            # reset representation (disable representation search)
            representation = false
          end
          
          # copy line
          f.write line
          skip = false
        else
          if skip # currently in header
            
            # change IFC file creator
            if line.include?('FILE_NAME')
              version = "SketchUp"
              if Sketchup.is_pro?
                version = version + " Pro"
              end
              number = Sketchup.version_number/100000000.floor
              version = version + " 20" + number.to_s
              version = version + " (" + Sketchup.version + ")"
              line.sub! ", '', 'SketchUp Pro 2015',", ", 'IFC-manager for SketchUp (1.0.4)', '" + version + "',"
            end
            
            # copy line
            f.write line
          else # currently in footer
            
            # ifc_objects[@row] = comp_name
            # values = sketchup component names
            # keys = ifc file row id's as integer
            
            # ifc_names = ifc_objects.values
            # ifc_rows = ifc_objects.keys
            # i = 0
            # j = 0
            # rows = Hash.new
            # # rows:values = sketchup component instances
            # # rows:keys = ifc file row id's as integer
            
            # # combine ifc_object row numbers with su_instances
            # while j < instances.length do
              # if instances[ i ].definition.name == ifc_names[ j ]
                # rows[ifc_rows[ j ]] = instances[ i ]
                # i +=1
              # end
              # j +=1
            # end
          
            # first add material / classification / layer
            f.write create_materials( object_list )
            f.write create_layers( representations, object_list )
            f.write create_nlsfb_classifications( su_components )
            
            # then copy line
            f.write line
            
            # continue copying layers
            skip = true
          end
        end
      }

      t.close
      #t.unlink does not work, maybe because of writing from external process?
      f.close      
    end # fix_export

    # currently only writes temporary file
    def write_temp

      # check if it's possible to write IFC files
      unless Sketchup.version_number > 14000000
        raise "You need at least SketchUp 2014 to create IFC-files"
      end
      unless Sketchup.is_pro?
        raise "You need SketchUp PRO to create IFC-files"
      end

      # Export model to temporary IFC file
      model = Sketchup.active_model
      file = Tempfile.new(['IfcExport-', '.ifc'])
      show_summary = true

      unless model.export file.path , show_summary
        raise "Unable to write temporary IFC-file"
      end

      # return the temp file
      file

    end # def write_temp

    # guids = Hash: sketchup guids[comonentinstance]
    # ifc_objects = ifc objects Hash: guid[row]
    # su_components = sketchup objects without matching GUID Hash: row[componentdefinition]
    def create_nlsfb_classifications( su_components )
      # (!) check if nlsfb scheme is loaded!
      
      model = Sketchup.active_model
      classification = String.new
      classification_list = Hash.new
      
      # add official NL-SfB
      @row += 1
      classification << "#" + @row.to_s + " = IFCCLASSIFICATION('BIM Loket','2005',$,'NL-SfB 2005, tabel 1'); \n"
      classification_row = @row

      # add NL-SfB as unicode hack to make vico load the classification
      @row += 1
      classification << "#" + @row.to_s + " = IFCCLASSIFICATION('http://www.csiorg.net/uniformat','1998',$,'Uniformat'); \n"
      classification_row_vico = @row
      
      su_components.each do | row, definition |
      
        type = definition.get_attribute "AppliedSchemaTypes", "NL-SfB 2005, tabel 1"
        if type

          code = definition.get_classification_value(["NL-SfB 2005, tabel 1", type, "Class-codenotatie"])
          tekst = definition.get_classification_value(["NL-SfB 2005, tabel 1", type, "tekst_NL-SfB"])
          
          # only create classification if component has the code and text values for the classification
          if code && tekst
            code_tekst = code + "','" + tekst
            if classification_list[code_tekst]
              classification_list[code_tekst] << row
            else
              classification_list[code_tekst] = [row]
            end
          end
        end
      end
      
      classification_list.each do | code_tekst, classified_list |
      
        @row += 1
        classification << "#" + @row.to_s + " = IFCCLASSIFICATIONREFERENCE($,'" + code_tekst + "',#" + classification_row.to_s + "); \n"
        
        row_next = @row + 1
        classification << "#" + row_next.to_s + " = IFCRELASSOCIATESCLASSIFICATION('" + new_guid + "',#2,$,$,(#" +  classified_list.join(', #') + "),#" + @row.to_s + ");\n"
        
        @row = row_next
        
        # vico hack
        @row += 1
        classification << "#" + @row.to_s + " = IFCCLASSIFICATIONREFERENCE('http://www.csiorg.net/uniformat','" + code_tekst + "',#" + classification_row_vico.to_s + "); \n"
        
        row_next = @row + 1
        classification << "#" + row_next.to_s + " = IFCRELASSOCIATESCLASSIFICATION('" + new_guid + "',#2,'Uniformat Classification',$,(#" +  classified_list.join(', #') + "),#" + @row.to_s + ");\n"
        
        @row = row_next
      end
      return classification
    end # def create_nlsfb_classifications

    def create_materials(hash)
      materials = String.new
      material_list = Hash.new
      associatesmaterial_list = Hash.new
      
      hash.each do | record, instance |
        material = instance.material
        if material
          
          #check if material exists
          unless material_list[instance.material.display_name]
            @row += 1
            materials << "#" + @row.to_s + " = IFCMATERIAL('" + instance.material.display_name + "'); \n"
            material_list[instance.material.display_name] = @row
          end
          material_row = material_list[instance.material.display_name]
          
          if associatesmaterial_list[material_row]
            associatesmaterial_list[material_row] << record
          else
            associatesmaterial_list[material_row] = [record]
          end
        end
      end
        
      associatesmaterial_list.each do | material_row, objects_list |
        @row += 1
        materials << "#" + @row.to_s + " = IFCRELASSOCIATESMATERIAL('" + new_guid + "',#2,$,$,(#" +  objects_list.join(', #') + "),#" + material_row.to_s + ");\n"
      end
      return materials
    end # def create_materials

    def create_layers( representations, rows )
      model = Sketchup.active_model
      layers = String.new
      layer_list = Hash.new
      
      representations.each do |object_row, row|
        if rows[object_row]
          layer = rows[object_row].layer
          if layer_list[layer.name]
            layer_list[layer.name] << row
          else
            layer_list[layer.name] = [row]
          end
        end
      end
      
      layer_list.each do | layer_name, representations_list |
        @row += 1
        layers << "#" + @row.to_s + " = IFCPRESENTATIONLAYERASSIGNMENT('" + layer_name + "',$,(#" +  representations_list.join(', #') + "),$); \n"
      end
      return layers
    end # def create_layers
    
  end # module IfcManager
end # module BimTools
