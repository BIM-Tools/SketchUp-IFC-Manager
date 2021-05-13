#       settings.rb
#
#       Copyright (C) 2020 Jan Brouwer <jan@brewsky.nl>
#
#       This program is free software: you can redistribute it and/or modify
#       it under the terms of the GNU General Public License as published by
#       the Free Software Foundation, either version 3 of the License, or
#       (at your option) any later version.
#
#       This program is distributed in the hope that it will be useful,
#       but WITHOUT ANY WARRANTY; without even the implied warranty of
#       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#       GNU General Public License for more details.
#
#       You should have received a copy of the GNU General Public License
#       along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Object for reading and writing plugin settings.
#
# project
#  project/site/building/storeys
#  location
# export:
#   ifc_entities:        false, # include IFC entity types given in array, like ["IfcWindow", "IfcDoor"], false means all
#   hidden:              false, # include hidden sketchup objects
#   attributes:          [],    # include specific attribute dictionaries given in array as IfcPropertySets, like ['SU_DefinitionSet', 'SU_InstanceSet'], false means all
#   classifications:     true,  # add all SketchUp classifications
#   layers:              true,  # create IfcPresentationLayerAssignments
#   materials:           true,  # create IfcMaterials
#   colors:              true,  # create IfcStyledItems
#   fast_guid:           false, # create simplified guids
#   dynamic_attributes:  false, # export dynamic component data
#   open_file:           false, # open created file in given/default application
#   mapped_items:        true
# load:
#   classifications:     [],    # ["NL-SfB 2005, tabel 1", "DIN 276-1"]
#   default_materials:   false  # {'beton'=>[142, 142, 142],'hout'=>[129, 90, 35],'staal'=>[198, 198, 198],'gips'=>[255, 255, 255],'zink'=>[198, 198, 198],'hsb'=>[204, 161, 0],'metselwerk'=>[102, 51, 0],'steen'=>[142, 142, 142],'zetwerk'=>[198, 198, 198],'tegel'=>[255, 255, 255],'aluminium'=>[198, 198, 198],'kunststof'=>[255, 255, 255],'rvs'=>[198, 198, 198],'pannen'=>[30, 30, 30],'bitumen'=>[30, 30, 30],'epdm'=>[30, 30, 30],'isolatie'=>[255, 255, 50],'kalkzandsteen'=>[255, 255, 255],'metalstud'=>[198, 198, 198],'gibo'=>[255, 255, 255],'glas'=>[204, 255, 255],'multiplex'=>[255, 216, 101],'cementdekvloer'=>[198, 198, 198]}

require 'yaml'
require "cgi"

module BimTools::IfcManager
  module Settings
    extend self
    attr_accessor :visible
    attr_reader :classifications, :common_psets
    @template_materials = false
    @common_psets = true
    @settings_file = File.join(PLUGIN_PATH, "settings.yml")
    @classifications = Hash.new
    # @css = File.join(PLUGIN_PATH_CSS, 'sketchup.css')
    @css_bootstrap = File.join(PLUGIN_PATH_CSS, 'bootstrap.min.css')
    @css_core = File.join(PLUGIN_PATH_CSS, 'dialog.css')
    @css_settings = File.join(PLUGIN_PATH_CSS, 'settings.css')
    @js_bootstrap = File.join(PLUGIN_PATH, 'js', 'bootstrap.min.js')
    @js_jquery = File.join(PLUGIN_PATH, 'js', 'jquery.min.js')

    def load()
      begin
        @options = YAML.load(File.read(@settings_file))
      rescue
        message = "Default settings loaded.\r\nUnable to load settings from:\r\n'#{@settings_file}'"
        puts message
        notification = UI::Notification.new(IFCMANAGER_EXTENSION, message)
        notification.show
      end
  
      # load classification schemes from settings
      read_classifications()
      load_classifications()
      load_materials()

      # Load export options from settings
      if @options[:export]
        @export_hidden =             CheckboxOption.new("hidden", "Export hidden objects", @options[:export][:hidden])
        @export_classifications =    CheckboxOption.new("classifications", "Export classifications", @options[:export][:classifications])
        @export_layers =             CheckboxOption.new("layers", "Export tags/layers as IFC layers", @options[:export][:layers])
        @export_materials =          CheckboxOption.new("materials", "Export materials", @options[:export][:materials])
        @export_colors =             CheckboxOption.new("colors", "Export colors", @options[:export][:colors])
        @export_geometry =           CheckboxOption.new("geometry", "Export geometry", @options[:export][:geometry])
        @export_fast_guid =          CheckboxOption.new("fast_guid", "Improve export speed by using fake GUID's", @options[:export][:fast_guid])
        @export_dynamic_attributes = CheckboxOption.new("dynamic_attributes", "Export dynamic attributes", @options[:export][:dynamic_attributes])
        # @export_mapped_items =       CheckboxOption.new("mapped_items", "Export IFC mapped items", @options[:export][:mapped_items]),
      end
    end # def load

    def save()
      @options[:load][:classifications]      = @classifications
      @options[:load][:template_materials]   = @template_materials
      @options[:properties][:common_psets]   = @common_psets
      @options[:export][:hidden]             = @export_hidden.value
      @options[:export][:classifications]    = @export_classifications.value
      @options[:export][:layers]             = @export_layers.value
      @options[:export][:materials]          = @export_materials.value
      @options[:export][:colors]             = @export_colors.value
      @options[:export][:geometry]           = @export_geometry.value
      @options[:export][:fast_guid]          = @export_fast_guid.value
      @options[:export][:dynamic_attributes] = @export_dynamic_attributes.value
      # @options[:export][:mapped_items]       = @export_mapped_items.value
      File.open(@settings_file, "w") { |file| file.write(@options.to_yaml) }
      if BimTools::IfcManager::PropertiesWindow.window && BimTools::IfcManager::PropertiesWindow.window.visible?
        PropertiesWindow.close
        PropertiesWindow.create
        BimTools::IfcManager::PropertiesWindow.show
      else
        PropertiesWindow.create
      end
      load()
    end # def save

    def set_classification(classification_name)
      @classifications[classification_name] = true
      unless @options[:load][:classifications].key? classification_name
        @options[:load][:classifications][classification_name] = true
      end
    end

    def unset_classification(classification_name)
      @classifications[classification_name] = false
      if @options[:load][:classifications].include? classification_name
        @options[:load][:classifications][classification_name] = false
      end
    end

    def read_classifications()
      @classifications = Hash.new
      if @options[:load][:classifications].is_a? Hash
        @options[:load][:classifications].each_pair do |classification_name, load|
          if(load == true || load == false)
            @classifications[classification_name] = load
          end
        end
      end
    end

    def get_classifications()
      return @classifications
    end

    def load_classifications()
      model = Sketchup.active_model
      model.start_operation("Load IFC Manager classifications", true)
      Settings.classifications.each_pair do | classification_name, classification_active |
        if classification_active
          unless model.classifications[classification_name]
            classifications = model.classifications
            file = File.join(PLUGIN_PATH_CLASSIFICATIONS, classification_name + ".skc")
            
            # If not in plugin lib folder then check support files
            unless file
              file = Sketchup.find_support_file(classification + ".skc", "Classifications")
            end
            if file
              classifications.load_schema(file) if !file.nil?
            else
              message = "Unable to load classification:\r\n'#{classification_name}'"
              puts message
              notification = UI::Notification.new(IFCMANAGER_EXTENSION, message)
              notification.show
            end
          end
        end
      end
      
      # also check if IFC2X3 is loaded
      unless Sketchup.active_model.classifications["IFC 2x3"]
        c = Sketchup.active_model.classifications
        file = Sketchup.find_support_file('IFC 2x3.skc', 'Classifications')
        c.load_schema(file) if !file.nil?
      end
      model.commit_operation
    end # def load_classifications

    # @return [Hash] List of materials
    def materials
      if(@options[:load][:template_materials] && @options[:material_list].is_a?(Hash))
        @template_materials = true
        return @options[:material_list]
      else
        return false
      end
    end

    # creates new material for every material in Settings
    # unless a material with this name already exists
    def load_materials()
      model = Sketchup.active_model
      if Settings.materials
        model.start_operation("Load IFC Manager template materials", true)
        Settings.materials.each do | name, color|
          unless Sketchup.active_model.materials[ name ]
            material = Sketchup.active_model.materials.add( name )
            material.color = color
          end
        end
        model.commit_operation
      end
    end # end def load_materials

    # @return [Hash] List of export options
    def export
      if @options[:export].is_a? Hash
        return @options[:export]
      else
        return {}
      end
    end

    ### settings dialog methods ###

    def toggle
      if @dialog && @dialog.visible?
        @dialog.close
      else
        create_dialog()
      end
    end

    def create_dialog()

      @dialog = UI::HtmlDialog.new(
      {
        :dialog_title => "IFC Manager Settings",
        :scrollable => true,
        :resizable => true,
        :width => 320,
        :height => 480,
        :left => 200,
        :top => 200,
        :style => UI::HtmlDialog::STYLE_UTILITY
      })
      set_html()
      @dialog.add_action_callback("save_settings") { |action_context, s_form_data|
        update_classifications = []
        @template_materials               = false
        @common_psets                     = false
        @export_hidden.value              = false
        @export_classifications.value     = false
        @export_layers.value              = false
        @export_materials.value           = false
        @export_colors.value              = false
        @export_geometry.value            = false
        @export_fast_guid.value           = false
        @export_dynamic_attributes.value  = false
        # @export_mapped_items.value        = false

        a_form_data = CGI.unescape(s_form_data).split('&')
        a_form_data.each do |s_setting|
          a_setting = s_setting.split('=')
                    
          if a_setting[0] == "template_materials"
            @template_materials = true
          elsif a_setting[0] == "common_psets"
            @common_psets = true
          elsif a_setting[0] == "hidden"
            @export_hidden.value = true
          elsif a_setting[0] == "classifications"
            @export_classifications.value = true
          elsif a_setting[0] == "layers"
            @export_layers.value = true
          elsif a_setting[0] == "materials"
            @export_materials.value = true
          elsif a_setting[0] == "colors"
            @export_colors.value = true
          elsif a_setting[0] == "geometry"
            @export_geometry.value = true
          elsif a_setting[0] == "fast_guid"
            @export_fast_guid.value = true
          elsif a_setting[0] == "dynamic_attributes"
            @export_dynamic_attributes.value = true
          elsif a_setting[0] == "mapped_items"
            @export_mapped_items.value = true
          else
            update_classifications << a_setting[1]
          end
        end
        @classifications.each_key do |classification_name|
          if update_classifications.include? classification_name
            self.set_classification(classification_name)
          else
            self.unset_classification(classification_name)
          end
        end
        self.save()
      }
      @dialog.show
    end # create_dialog
    def set_html()
      html = <<HTML
<head>
  <link rel='stylesheet' type='text/css' href='#{@css_bootstrap}'>
  <link rel='stylesheet' type='text/css' href='#{@css_core}'>
  <link rel='stylesheet' type='text/css' href='#{@css_settings}'>
  <script type='text/javascript' src='#{@js_jquery}'></script>
  <script type='text/javascript' src='#{ @js_bootstrap}'></script>
  <script>
    $(document).ready(function(){
      $( 'form' ).on( 'submit', function( event ) {
        event.preventDefault();
        sketchup.save_settings($( this ).serialize());
      });
    });
  </script>
</head>
<body>
  <div class='container'>
    <form>
      <div class='form-group'>
        <h1>Classification systems</h1>
HTML
      @classifications.each_pair do |classification_name, load|
        if load
          checked = " checked"
        else
          checked = ""
        end
        html << "         <div class=\"col-md-12 row\"><label class=\"check-inline\"><input type=\"checkbox\" name=\"classification\" value=\"#{classification_name}\"#{checked}> #{classification_name}</label></div>\n"
      end

      # Export settings
      html << "      </div>\n"
      html << "      <div class='form-group'>\n"
      html << "        <h1>Export</h1>"
      html << @export_hidden.html()
      html << @export_classifications.html()
      html << @export_layers.html()
      html << @export_materials.html()
      html << @export_colors.html()
      html << @export_geometry.html()
      html << @export_fast_guid.html()
      html << @export_dynamic_attributes.html()
      # html << @export_mapped_items.html()
      html << "      </div>\n"

      # Default materials
      if @template_materials
        materials_checked = " checked"
      else
        materials_checked = ""
      end

      if @common_psets
        common_psets_checked = "checked"
      else
        common_psets_checked = ""
      end

      footer = <<HTML
      <div class='form-group'>
        <h1>Load default materials</h1>
        <div class="col-md-12 row">
          <label class=\"check-inline\"><input type=\"checkbox\" name=\"template_materials\" value=\"template_materials\"#{materials_checked}> Template materials</label>
        </div>
      </div>
      <div class='form-group'>
        <h1>Property sets</h1>
        <div class="col-md-12 row">
          <label class=\"check-inline\"><input type=\"checkbox\" name=\"common_psets\" value=\"common_psets\" #{common_psets_checked}> Common PropertySets</label>
        </div>
      </div>
      <br>
      <div class="form-group row">
        <div class="col-sm-12">
          <button type="submit" class="btn btn-outline-secondary">Save</button>
        </div>
      </div>
    </form>
  </div></body>
HTML
      html << footer
      @dialog.set_html( html )
    end

    class CheckboxOption
      attr_accessor :value
      def initialize(name, title, initial_value)
        @name = name
        @title = title
        @value = initial_value
      end
      def html()
        if @value
          checked = " checked"
        else
          checked = ""
        end
        return <<HTML
        <div class="col-md-12 row">
          <label class="check-inline"><input type="checkbox" name="#{@name}" value="#{@name}"#{checked}> #{@title}</label>
        </div>
HTML
      end
    end
  end
end
