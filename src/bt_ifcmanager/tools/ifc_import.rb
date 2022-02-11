# frozen_string_literal: true

module BimTools::IfcManager
  # Recursively merge all coplanar faces in the entities collection
  #
  # @param [Sketchup::Entities]
  #
  def merge_faces(entities)
    delete = []
    i = 0
    while i < entities.length
      if entities[i].is_a?(Sketchup::Group) || entities[i].is_a?(Sketchup::ComponentInstance)
        merge_faces(entities[i].definition.entities)
      elsif entities[i].is_a? Sketchup::Edge
        edge = entities[i]
        if edge.hidden?
          faces = edge.faces
          if faces.length == 2
            if faces[0].normal.samedirection?(faces[1].normal)

              # Double check if samedirection is accurate enough and faces are really on the same plane
              same_plane = false
              plane = faces[0].plane
              verts = faces[1].vertices
              k = 0
              while k < verts.length
                same_plane = verts[k].position.on_plane?(plane)
                unless same_plane
                  break
                end
                k += 1
              end
              if same_plane
                delete << edge 
              end
            end
          end
        end
      end
      i += 1
    end
    j = 0
    while j < delete.length
      delete[j].erase!
      j += 1
    end
  end

  # Create layer for every IFC entity type
  #   and assign this to entities
  #
  # @param [Sketchup::Model]
  #
  def ifc_type_to_layer(model)
    if Sketchup.active_model.classifications['IFC 2x3']
      definitions = model.definitions
      definitions.purge_unused
      i = 0
      while i < definitions.length
        definition = definitions[i]
        ifc_type = definition.get_attribute('AppliedSchemaTypes', 'IFC 2x3')
        if ifc_type
          layers = model.layers
          layers.add(ifc_type) unless layers[ifc_type]
          instances = definition.instances
          j = 0
          while j < instances.length
            instances[j].layer = ifc_type
            j += 1
          end
        end
        i += 1
      end
    end
  end

  # Explode all imported IFC models
  #
  # @param [Sketchup::Model]
  #
  # @return (Array<Sketchup:Entity>) — An array of entity objects if successful, false if unsuccessful
  def explode_ifc_files(model, ifc_file_path)
    ifc_file_name = File.basename(ifc_file_path)

    # check if previous exports with the same name are created
    next_definition_name = model.definitions.unique_name(ifc_file_name)
    unless next_definition_name.end_with?('#1') # then there probably is no older import from the same IFC in the model
      ifc_file_name = "#{ifc_file_name}##{next_definition_name[-1,1].to_i-1}"
    end

    # Explode the instances placed directly in the model
    definition = model.definitions[ifc_file_name]
    if (definition) && (definition.instances.length == 1)
      instance = definition.instances[0]
      if instance.parent.is_a?(Sketchup::Model)
        return instance.explode
      end
    else
      message = "Unable to find IFC file to explode"
      puts message
      notification = UI::Notification.new(IFCMANAGER_EXTENSION, message)
      notification.show
    end
    return false
  end

  # Explode all IfcProjects
  #
  # @param [Sketchup::Model]
  #
  def explode_ifc_projects(entities)
    j = 0
    while j < entities.length
      instance = entities[j]
      if instance.is_a?(Sketchup::ComponentInstance)
        if instance.definition.get_attribute('AppliedSchemaTypes', 'IFC 2x3') == 'IfcProject'
          instance.explode
        end
      end
      j += 1
    end
  end

  # Use IFC entity name as definition name if available
  #
  # @param [Sketchup::Model]
  #
  def improve_definition_names(model)
    if Sketchup.active_model.classifications['IFC 2x3']
      definitions = model.definitions
      i = 0
      while i < definitions.length
        definition = definitions[i]
        ifc_type = definition.get_attribute('AppliedSchemaTypes', 'IFC 2x3')
        if ifc_type
          instances = definition.instances
          j = 0
          while j < instances.length
            instance = instances[j]
            unless instance.name == ''
              name = instance.name.delete_prefix("#{ifc_type} - ")
              definition.name = definitions.unique_name(name)
            end
            j += 1
          end
        end
        i += 1
      end
    end
  end

  # Cleanup model after IFC import
  #
  # @param model [Sketchup::Model]
  #
  def ifc_cleanup(model, import_path)
    puts "Start IFC cleanup"
    model.start_operation('IFC Cleanup', true)
    merge_faces(model.entities)
    puts "Start IFC explode file and project containers"
    imported_entities = explode_ifc_files(model, import_path)
    if imported_entities
      explode_ifc_projects(imported_entities)
    end
    ifc_type_to_layer(model)
    improve_definition_names(model)
    model.commit_operation
  end

  # Import IFC model + cleanup
  #
  def ifc_import
    model = Sketchup.active_model
    default_path = File.dirname(model.path)
    unless default_path
      default_path = File.join(ENV['HOME'], 'Desktop')
    end
    import_path = UI.openpanel('Open IFC File', default_path, 'IFC Files|*.ifc;*.ifcZIP||')
    if import_path
      model.start_operation('IFC Import', true)
      model.import(import_path, false)
      model.commit_operation
      puts "IFC import complete"
      ifc_cleanup(model, import_path)
    else
      message = "No IFC file selected for import"
      puts message
      UI::Notification.new(IFCMANAGER_EXTENSION, message).show
    end
  end
end
