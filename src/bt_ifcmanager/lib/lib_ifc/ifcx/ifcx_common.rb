# frozen_string_literal: true

# ifcx_common.rb
#
# Common IFCX export settings and attribute lists for BimTools IFC Manager

module BimTools
  module IfcXCommon
    EXCLUDED_PREDEFINED_TYPES = %i[NOTDEFINED USERDEFINED].freeze
    EXCLUDED_ATTRIBUTES = %i[
      GlobalId OwnerHistory ObjectPlacement Representation
      ApplicableOccurrence HasPropertySets RepresentationMaps Tag
      ActionType
      CompositionType
      ConnectionType
      ConstructionType
      ContextType
      DefinitionType
      DurationType
      ElementType
      EventTriggerType
      InterferenceType
      ObjectType
      OperationType
      PartitioningType
      PredefinedType
      PrimaryMeasureType
      ProcessType
      ProfileType
      RecurrenceType
      RelatedConnectionType
      RelatedObjectsType
      RelatingConnectionType
      RelatingType
      RelationshipType
      RepresentationType
      ResourceType
      SecondaryMeasureType
      SectionType
      SequenceType
      SystemType
      TemplateType
      TheoryType
      TimeSeriesDataType
      UnitType
      UserDefinedEventTriggerType
      UserDefinedOperationType
      UserDefinedPartitioningType
      UserDefinedSequenceType
      UserDefinedType
    ].freeze
    # TypeIdentifier
    # UsageType
  end
end
