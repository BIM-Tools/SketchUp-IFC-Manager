# frozen_string_literal: true

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
#   ifc_entities:          false, # include IFC entity types given in array, like ["IfcWindow", "IfcDoor"], false means all
#   hidden:                false, # include hidden sketchup objects
#   attributes:            [],    # include specific attribute dictionaries given in array as IfcPropertySets, like ['SU_DefinitionSet', 'SU_InstanceSet'], false means all
#   classifications:       true,  # add all SketchUp classifications
#   layers:                true,  # create IfcPresentationLayerAssignments
#   materials:             true,  # create IfcMaterials
#   colors:                true,  # create IfcStyledItems
#   geometry:              'Brep' # ['Brep','Tessellation',false]
#   fast_guid:             false, # create simplified guids
#   dynamic_attributes:    false, # export dynamic component data
#   open_file:             false, # open created file in given/default application
#   classification_suffix: true # Add ' Classification' suffix to all classification for Revit compatibility
#   model_axes:            true   # Export using model axes instead of Sketchup internal origin
#   textures:              false  # Add textures
#   double_sided_faces:    false  # Add double sided faces
# load:
#   classifications:       [],    # ["NL-SfB 2005, tabel 1", "DIN 276-1"]
#   default_materials:     false  # {'beton'=>[142, 142, 142],'hout'=>[129, 90, 35],'staal'=>[198, 198, 198],'gips'=>[255, 255, 255],'zink'=>[198, 198, 198],'hsb'=>[204, 161, 0],'metselwerk'=>[102, 51, 0],'steen'=>[142, 142, 142],'zetwerk'=>[198, 198, 198],'tegel'=>[255, 255, 255],'aluminium'=>[198, 198, 198],'kunststof'=>[255, 255, 255],'rvs'=>[198, 198, 198],'pannen'=>[30, 30, 30],'bitumen'=>[30, 30, 30],'epdm'=>[30, 30, 30],'isolatie'=>[255, 255, 50],'kalkzandsteen'=>[255, 255, 255],'metalstud'=>[198, 198, 198],'gibo'=>[255, 255, 255],'glas'=>[204, 255, 255],'multiplex'=>[255, 216, 101],'cementdekvloer'=>[198, 198, 198]}

require 'yaml'
require 'cgi'

module BimTools
  module IfcManager
    require File.join(PLUGIN_PATH_LIB, 'skc_reader')
    module Settings
      extend self
      attr_accessor :visible,
                    :ifc_version,
                    :ifc_version_compact,
                    :ifc_module,
                    :filters

      attr_reader :ifc_classification,
                  :ifc_classifications,
                  :ifc_version_names,
                  :active_classifications,
                  :common_psets,
                  :export_classifications

      @template_materials = false
      @common_psets = true
      @settings_file = File.join(PLUGIN_PATH, 'settings.yml')
      @ifc_classifications = {}
      @ifc_version_names = []

      # classifications shown in properties window
      @active_classifications = {}

      @classifications = {}
      @css_bootstrap = File.join(PLUGIN_PATH_CSS, 'bootstrap.min.css')
      @css_core = File.join(PLUGIN_PATH_CSS, 'dialog.css')
      @css_settings = File.join(PLUGIN_PATH_CSS, 'settings.css')
      @js_bootstrap = File.join(PLUGIN_PATH, 'js', 'bootstrap.min.js')
      @js_jquery = File.join(PLUGIN_PATH, 'js', 'jquery.min.js')
      @filters = {}

      def load_settings
        begin
          @options = YAML.load(File.read(@settings_file))
        rescue StandardError
          message = "Unable to load settings from:\r\n'#{@settings_file}'\r\nDefault settings loaded."
          puts message
          UI::Notification.new(IFCMANAGER_EXTENSION, message).show
        end

        # Load export options from settings
        if @options[:export]
          @export_hidden = CheckboxOption.new(
            'hidden',
            'Export hidden objects',
            @options[:export][:hidden],
            'Everything will be exported to IFC, including those that are hidden or on a disabled tag/layer.'
          )
          @export_classifications = CheckboxOption.new(
            'classifications',
            'Export classifications',
            @options[:export][:classifications],
            'Export classifications attached to objects as IfcClassification'
          )
          @export_layers = CheckboxOption.new(
            'layers',
            'Export tags/layers as IFC layers',
            @options[:export][:layers],
            'Exports Sketchup tags/layers as IfcPresentationLayerAssignment'
          )
          @export_materials = CheckboxOption.new(
            'materials',
            'Export materials',
            @options[:export][:materials],
            'Exports the Sketchup material name as IfcMaterial'
          )
          @export_colors = CheckboxOption.new(
            'colors',
            'Export colors',
            @options[:export][:colors],
            'Exports the Sketchup material colors as colored IfcSurfaceStyles'
          )
          @export_geometry = SelectOption.new(
            'geometry',
            'Export geometry',
            @options[:export][:geometry],
            ['Brep','Tessellation','None'],
            'When \'None\' NO geometry is exported, just the model structure and metadata like classifications and properties'
          )
          @export_fast_guid = CheckboxOption.new(
            'fast_guid',
            "Improve export speed by using fake GUID's",
            @options[:export][:fast_guid],
            'This replaces the official UUID4 based GUID by a similar looking random string, not recomended but export might be a bit faster.'
          )
          @export_dynamic_attributes = CheckboxOption.new(
            'dynamic_attributes',
            'Export dynamic attributes',
            @options[:export][:dynamic_attributes],
            'Export Dynamic Component attributes as Parametric PropertySets and Quantities as described here: https://github.com/BIM-Tools/SketchUp-IFC-Manager/wiki/Parametric-Property-Sets'
          )
          @export_types = CheckboxOption.new(
            'types',
            'Export IFC Type products',
            @options[:export][:types],
            'Create IfcTypeProducts for Sketchup Components that are shared between all instance entities. This nicely matches the Sketchup Component structure and results in a somewhat smaller and cleaner IFC file.'
          )
          @export_type_properties = CheckboxOption.new(
            'type_properties',
            'Export IFC Type properties',
            @options[:export][:type_properties],
            'Attach IFC properties and classifications to the IfcTypeProduct (when enabled) instead of the Entity itself. This results in a somewhat smaller and cleaner IFC file, but support varies between tools.'
          )
          @export_textures = CheckboxOption.new(
            'textures',
            'Export textures',
            @options[:export][:textures]
          )
          @export_double_sided_faces = CheckboxOption.new(
            'double_sided_faces',
            'Export double sided faces',
            @options[:export][:double_sided_faces]
          )
          @export_classification_suffix = CheckboxOption.new(
            'classification_suffix',
            "Add 'Classification' suffix to all classifications",
            @options[:export][:classification_suffix],
            "Add ' Classification' suffix to all classification for Revit compatibility, this can help in grouping classifications in model checkers"
          )
          @export_model_axes = CheckboxOption.new(
            'model_axes',
            "Export using model axes transformation",
            @options[:export][:model_axes],
            "Export using model axes instead of Sketchup internal origin"
          )
        end

        # load classification schemes from settings
        read_ifc_classifications
        read_classifications
        load_classifications
        load_materials
        load_ifc_skc(@ifc_classification)
      end

      def save
        @options[:load][:ifc_classifications] = @ifc_classifications
        @options[:load][:classifications] = @active_classifications
        @options[:load][:template_materials] = @template_materials
        @options[:properties][:common_psets] = @common_psets
        @options[:export][:hidden] = @export_hidden.value
        @options[:export][:classifications] = @export_classifications.value
        @options[:export][:layers] = @export_layers.value
        @options[:export][:materials] = @export_materials.value
        @options[:export][:colors] = @export_colors.value
        @options[:export][:geometry] = @export_geometry.value
        @options[:export][:fast_guid] = @export_fast_guid.value
        @options[:export][:dynamic_attributes] = @export_dynamic_attributes.value
        @options[:export][:types] = @export_types.value
        @options[:export][:type_properties] = @export_type_properties.value
        @options[:export][:textures] = @export_textures.value
        @options[:export][:double_sided_faces] = @export_double_sided_faces.value
        @options[:export][:classification_suffix] = @export_classification_suffix.value
        @options[:export][:model_axes] = @export_model_axes.value
        File.open(@settings_file, 'w') { |file| file.write(@options.to_yaml) }
        PropertiesWindow.close
        @dialog.close
        load_settings
        message = 'IFC Manager settings saved'
        puts message
        UI::Notification.new(IFCMANAGER_EXTENSION, message).show
        PropertiesWindow.create
      end

      # Load skc and generate IFC classes
      # (?) First check if already loaded?
      def load_ifc_skc(ifc_classification)
        begin
          reader = SKC.new(ifc_classification)
          @filters[ifc_classification] = reader
          ifc_version = reader.name
          xsd_parser = IfcXmlParser.new(ifc_version, reader.xsd_schema)
          @ifc_version = xsd_parser.ifc_version
          @ifc_version_compact = xsd_parser.ifc_version_compact
          @ifc_module = xsd_parser.ifc_module
        rescue StandardError => e
          puts e.message
          UI::Notification.new(IFCMANAGER_EXTENSION, e.message).show
        end
      end

      # This method retrieves the name of a SketchUp Classification.
      #
      # @param skc_file_name [String] The SKC file name.
      # @return [String, nil] The name of the classification file, or nil if an error occurs.
      def get_skc_name(skc_file_name)
        begin
          reader = SKC.new(skc_file_name)
          return reader.name
        rescue StandardError
          return nil
        end
      end

      def set_ifc_classification(ifc_classification_name)
        @ifc_classification = ifc_classification_name
        @ifc_classifications[ifc_classification_name] = true
        unless @options[:load][:ifc_classifications].key? ifc_classification_name
          @options[:load][:ifc_classifications][ifc_classification_name] = true
        end
      end

      def unset_ifc_classification(ifc_classification_name)
        @ifc_classifications[ifc_classification_name] = false
        if @options[:load][:ifc_classifications].include? ifc_classification_name
          @options[:load][:ifc_classifications][ifc_classification_name] = false
        end
      end

      def read_ifc_classifications
        @ifc_classifications = {}
        @ifc_version_names = []
        if @options[:load][:ifc_classifications].is_a? Hash
          @options[:load][:ifc_classifications].each_pair do |ifc_classification_name, load|
            @ifc_classifications[ifc_classification_name] = load
            @ifc_version_names << get_skc_name(ifc_classification_name)
            if load
              @ifc_classification = ifc_classification_name
            end
          end
        end
      end

      def set_classification(classification_name)
        @active_classifications[classification_name] = true
        unless @options[:load][:classifications].key? classification_name
          @options[:load][:classifications][classification_name] = true
        end
      end

      def unset_classification(classification_name)
        @active_classifications[classification_name] = false
        if @options[:load][:classifications].include? classification_name
          @options[:load][:classifications][classification_name] = false
        end
      end

      def read_classifications
        @active_classifications = {}
        if @options[:load][:classifications].is_a? Hash
          @options[:load][:classifications].each_pair do |classification_file, load|
            if load == true
              begin
                classification = SKC.new(classification_file)
                @filters[classification_file] = classification
                @classifications[classification.name] = classification
                @active_classifications[classification_file] = load
              rescue StandardError => e
                puts e.message
                UI::Notification.new(IFCMANAGER_EXTENSION, e.message).show
              end
            elsif load == false
              @active_classifications[classification_file] = load
            end
          end
        end
      end

      def get_classifications
        @active_classifications
      end

      # Load enabled classification files from settings.yml
      #   Loads both IFC and other classifications
      #   First checks plugin classifications folder then check SketchUp support files
      def load_classifications
        model = Sketchup.active_model
        model.start_operation('Load IFC Manager classifications', true)
        classifications = Settings.ifc_classifications.merge(@active_classifications)
        classifications.each_pair do |classification_file, classification_active|
          next unless classification_active

          plugin_filepath = File.join(PLUGIN_PATH_CLASSIFICATIONS, classification_file)
          filepath = if File.file?(plugin_filepath)
                      plugin_filepath
                    else
                      Sketchup.find_support_file(classification_file, 'Classifications')
                    end
          if filepath
            model.classifications.load_schema(filepath)
          else
            message = "Unable to load classification:\r\n'#{classification_file}'"
            puts message
            UI::Notification.new(IFCMANAGER_EXTENSION, message).show
          end
        end
        model.commit_operation
      end

      # @return [Hash] List of materials
      def materials
        if @options[:load][:template_materials] && @options[:material_list].is_a?(Hash)
          @template_materials = true
          @options[:material_list]
        else
          false
        end
      end

      # creates new material for every material in Settings
      # unless a material with this name already exists
      def load_materials
        model = Sketchup.active_model
        if Settings.materials
          model.start_operation('Load IFC Manager template materials', true)
          Settings.materials.each do |name, color|
            unless Sketchup.active_model.materials[name]
              material = Sketchup.active_model.materials.add(name)
              material.color = color
            end
          end
          model.commit_operation
        end
      end

      # @return [Hash] List of export options
      def export
        if @options[:export].is_a? Hash
          @options[:export]
        else
          {}
        end
      end

      ### settings dialog methods ###

      def toggle
        if @dialog && @dialog.visible?
          @dialog.close
        else
          create_dialog
        end
      end

      def create_dialog
        @dialog = UI::HtmlDialog.new(
          {
            dialog_title: 'IFC Manager Settings',
            scrollable: true,
            resizable: true,
            width: 320,
            height: 620,
            left: 200,
            top: 200,
            style: UI::HtmlDialog::STYLE_UTILITY
          }
        )
        set_html
        @dialog.add_action_callback('save_settings') do |_action_context, s_form_data|
          update_classifications = []
          update_ifc_classifications = []
          @template_materials = false
          @common_psets = false
          @export_hidden.value = false
          @export_classifications.value = false
          @export_layers.value = false
          @export_materials.value = false
          @export_colors.value = false
          @export_geometry.value = 'Brep'
          @export_fast_guid.value = false
          @export_dynamic_attributes.value = false
          @export_types.value = false
          @export_type_properties.value = false
          @export_textures.value = false
          @export_double_sided_faces.value = false
          @export_classification_suffix.value = false
          @export_model_axes.value = false

          a_form_data = CGI.unescape(s_form_data).split('&')
          a_form_data.each do |s_setting|
            key, value = s_setting.split('=')
            case key
            when 'template_materials'
              @template_materials = true
            when 'common_psets'
              @common_psets = true
            when 'hidden'
              @export_hidden.value = true
            when 'classifications'
              @export_classifications.value = true
            when 'layers'
              @export_layers.value = true
            when 'materials'
              @export_materials.value = true
            when 'colors'
              @export_colors.value = true
            when 'geometry'
              @export_geometry.value = value
            when 'fast_guid'
              @export_fast_guid.value = true
            when 'dynamic_attributes'
              @export_dynamic_attributes.value = true
            when 'types'
              @export_types.value = true
            when 'type_properties'
              @export_type_properties.value = true
            when 'textures'
              @export_textures.value = true
            when 'double_sided_faces'
              @export_double_sided_faces.value = true
            when 'classification_suffix'
              @export_classification_suffix.value = true
            when 'model_axes'
              @export_model_axes.value = true
            when 'ifc_classification'
              update_ifc_classifications << value
            when 'classification'
              update_classifications << value
            end
          end
          @active_classifications.each_key do |classification_name|
            if update_classifications.include? classification_name
              set_classification(classification_name)
            else
              unset_classification(classification_name)
            end
          end
          @ifc_classifications.each_key do |ifc_classification|
            if update_ifc_classifications.include? ifc_classification
              set_ifc_classification(ifc_classification)
            else
              unset_ifc_classification(ifc_classification)
            end
          end
          save
        end
        @dialog.show
      end

      def set_html
        html = <<~HTML
  <head>
    <link rel='stylesheet' type='text/css' href='#{@css_bootstrap}'>
    <link rel='stylesheet' type='text/css' href='#{@css_core}'>
    <link rel='stylesheet' type='text/css' href='#{@css_settings}'>
    <script type='text/javascript' src='#{@js_jquery}'></script>
    <script type='text/javascript' src='#{@js_bootstrap}'></script>
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
        <div class='form-group' title='Set the active IFC version that will be used for exporting and classifing objects'>
          <h1>IFC version</h1>
  HTML
        html = String.new(html)
        # ifc_classifications = Sketchup.find_support_files('skc', 'Classifications').select {|path| File.basename(path).downcase.include? 'ifc' }
        @ifc_classifications.each_pair do |ifc_classification, load|
          checked = if load
                      ' checked'
                    else
                      ''
                    end
          ifc_classification_name = File.basename(ifc_classification, '.skc')
          html << "        <input type=\"radio\" id=\"#{ifc_classification_name}\" name=\"ifc_classification\" value=\"#{ifc_classification}\"#{checked}>\n"
          html << "        <label for=\"#{ifc_classification_name}\">#{ifc_classification_name}</label><br>\n"
        end
        html << "      </div>\n"
        html << "      <div class='form-group' title='Select additional classifications that will be exported to IFC as IfcClassification'>\n"
        html << "        <h1>Other classification systems</h1>\n"

        @active_classifications.each_pair do |classification, load|
          checked = if load
                      ' checked'
                    else
                      ''
                    end
          classification_name = File.basename(classification, '.skc')
          html << "        <div class=\"col-md-12 row\"><label class=\"check-inline\"><input type=\"checkbox\" name=\"classification\" value=\"#{classification}\"#{checked}> #{classification_name}</label></div>\n"
        end

        # Export settings
        html << "      </div>\n"
        html << "      <div class='form-group'>\n"
        html << "        <h1>IFC export options</h1>\n"
        html << @export_hidden.html
        html << @export_classifications.html
        html << @export_layers.html
        html << @export_materials.html
        html << @export_colors.html
        html << @export_geometry.html
        html << @export_fast_guid.html
        html << @export_dynamic_attributes.html
        html << @export_types.html
        html << @export_type_properties.html
        html << @export_textures.html
        html << @export_double_sided_faces.html
        html << @export_classification_suffix.html
        html << @export_model_axes.html
        html << "      </div>\n"

        # Default materials
        materials_checked = if @template_materials
                              ' checked'
                            else
                              ''
                            end

        common_psets_checked = if @common_psets
                                'checked'
                              else
                                ''
                              end

        footer = <<~HTML
        <div class='form-group' title=''>
          <h1>Modelling preferences</h1>
          <div class="col-md-12 row" title="Always create default materials on opening a model (editable in 'settings.yml' config file).">
            <label class=\"check-inline\"><input type=\"checkbox\" name=\"template_materials\" value=\"template_materials\"#{materials_checked}> Template materials</label>
          </div>
          <div class="col-md-12 row" title="When creating a IFC entity with the IFC Manager 'create' tools, always add the matching Common PropertySet (like PSet_WallCommon when creating an IfcWall).">
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
    </div>
  </body>
  HTML
        html << footer
        @dialog.set_html(html)
      end

      class CheckboxOption
        attr_accessor :value

        def initialize(name, title, initial_value, help = '')
          @name = name
          @title = title
          @value = initial_value
          @help = help
        end

        def html
          checked = if @value
                      ' checked'
                    else
                      ''
                    end
          "        <div class=\"col-md-12 row\" title=\"#{@help}\">
            <label class=\"check-inline\"><input type=\"checkbox\" name=\"#{@name}\" value=\"#{@name}\"#{checked}> #{@title}</label>
          </div>\n"
        end
      end
    end

    class SelectOption
      attr_accessor :value

      def initialize(name, title, initial_value, options, help = '')
        @name = name
        @title = title
        @value = initial_value
        @options = options
      end

      def html
        html_strings = []
        html_strings << "<div class=\"col-md-12 row\">\n<select name=\"#{@name}\" title=\"#{@help}\">\n"
        @options.each do |option|
          selected = if @value == option
                      ' selected'
                    else
                      ''
                    end
          html_strings << "  <option value=\"#{option}\"#{selected}>#{option}</option>\n"
        end
        html_strings << "</select>\n<label style=\"margin-left:.5em\"class=\"check-inline\">#{@name}</label>\n</div>\n"
        html_strings.join()
      end
    end
  end
end
