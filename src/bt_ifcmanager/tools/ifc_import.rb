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
        faces = edge.faces
        if faces.length == 2
          if faces[0].normal.samedirection?(faces[1].normal)
            delete << edge
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
    if Sketchup.active_model.classifications["IFC 2x3"]
      definitions = model.definitions
      i = 0
      while i < definitions.length
        definition = definitions[i]
        ifc_type = definition.get_attribute("AppliedSchemaTypes", "IFC 2x3")
        if ifc_type
          layers = model.layers
          unless layers[ifc_type]
            layers.add(ifc_type)
          end
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
  def explode_ifc_files(model)
    entities = model.entities
    i = 0
    while i < entities.length
      instance = entities[i]
      if instance.is_a?(Sketchup::ComponentInstance)
        if instance.definition.name.end_with?(".ifc")
          instance.explode
        end
      end
      i += 1
    end
  end

  # Explode all IfcProjects
  #
  # @param [Sketchup::Model]
  #
  def explode_ifc_projects(model)
    entities = model.entities
    j = 0
    while j < entities.length
      instance = entities[j]
      if instance.is_a?(Sketchup::ComponentInstance)
        if instance.definition.get_attribute("AppliedSchemaTypes", "IFC 2x3") == "IfcProject"
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
    if Sketchup.active_model.classifications["IFC 2x3"]
      definitions = model.definitions
      i = 0
      while i < definitions.length
        definition = definitions[i]
        ifc_type = definition.get_attribute("AppliedSchemaTypes", "IFC 2x3")
        if ifc_type
          instances = definition.instances
          j = 0
          while j < instances.length
            instance = instances[j]
            unless instance.name == ""
              name = instance.name.delete_prefix(ifc_type << " - ")
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
  def ifc_cleanup(model)
    model.start_operation('IFC Cleanup', true)
    merge_faces(model.entities)
    explode_ifc_files(model)
    explode_ifc_projects(model)
    ifc_type_to_layer(model)
    improve_definition_names(model)
    model.definitions.purge_unused
    model.commit_operation
  end

  # Import IFC model + cleanup
  #
  def ifc_import()
    default_path = File.join(ENV['HOME'], 'Desktop')
    Sketchup.file_new
    model = Sketchup.active_model
    model.start_operation('IFC Import', true)
    import_path = UI.openpanel("Open IFC File", default_path, "IFC Files|*.ifc;*.ifcZIP||")
    model.import(import_path, false)
    import_dir = File.dirname(import_path)
    import_file = File.basename(import_path, ".*") << ".skp"
    model.definitions.purge_unused
    model.commit_operation
    ifc_cleanup(model)
  end
end