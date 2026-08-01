module MappingRecordUpdates where

import qualified O2I.ArchiMate.Profile as Profile

rewriteRelationMapping ::
     Profile.ArchiMateRelationMapping -> Profile.ArchiMateRelationMapping
rewriteRelationMapping mapping =
  mapping
    { Profile.relationMappingCode = Profile.relationMappingCode mapping
    , Profile.relationMappingName = Profile.relationMappingName mapping
    , Profile.relationMappingLabel = Profile.relationMappingLabel mapping
    , Profile.relationMappingSource = Profile.relationMappingSource mapping
    , Profile.relationMappingTarget = Profile.relationMappingTarget mapping
    , Profile.relationMappingRepresentation =
        Profile.relationMappingRepresentation mapping
    }

rewriteRelationshipRepresentation ::
     Profile.ArchiMateRelationshipRepresentation
  -> Profile.ArchiMateRelationshipRepresentation
rewriteRelationshipRepresentation representation =
  representation
    { Profile.relationshipTypeName = Profile.relationshipTypeName representation
    , Profile.relationshipDirected = Profile.relationshipDirected representation
    }

rewriteContextualization ::
     Profile.ContextualizationContract -> Profile.ContextualizationContract
rewriteContextualization contextualization =
  contextualization
    { Profile.contextualizationRepresentation =
        Profile.contextualizationRepresentation contextualization
    , Profile.contextualizationLabel =
        Profile.contextualizationLabel contextualization
    }
