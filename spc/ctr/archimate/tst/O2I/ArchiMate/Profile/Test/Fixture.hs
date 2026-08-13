{-# LANGUAGE OverloadedStrings #-}

-- | Observation-complete Draft fixtures for the Profile contract tests.
module O2I.ArchiMate.Profile.Test.Fixture
  ( validDraft
  , validDraftPermuted
  , validKpiDraft
  , relationApplicabilityDraft
  , invalidCarrierDraft
  , unmarkedDisplayedDraft
  , malformedIdentityDraft
  , notationOutcomeDraft
  , modelRootCrossFamilyDuplicateDraft
  , viewCrossFamilyDuplicateDraft
  , retentionDraft
  , qualificationDraft
  , qualificationMissingRoleDraft
  , qualificationWrongRoleDraft
  , qualificationMultipleInvalidRoleValuesDraft
  , qualificationWrongRelationshipDraft
  , qualificationWrongDirectionDraft
  , qualificationNonProposalRoleDraft
  , qualificationWrongCarrierDraft
  , qualificationInvalidTypeDraft
  , qualificationNoRationaleDraft
  , qualificationNormalizedRationaleDraft
  , qualificationMultipleRationaleDraft
  , qualificationInvalidRationaleDraft
  , qualificationNormalizedSourcesDraft
  , collectiveClosedDraft
  , collectiveOpenDraft
  , collectiveChainDraft
  , collectiveWrongCarrierDraft
  , collectiveInvalidTypeDraft
  , branchIsolationDraft
  ) where

import Data.Text (Text)
import qualified O2I.ArchiMate.Profile.Draft as Draft

validDraft :: Draft.ProfileDraft
validDraft = graphDraft False "Strategy"

validDraftPermuted :: Draft.ProfileDraft
validDraftPermuted = graphDraft True "Strategy"

validKpiDraft :: Draft.ProfileDraft
validKpiDraft =
  modelDraft
    [ Draft.childRecordMember
        (typedElement "measure" "Grouping" "Measure" "asserted")
    , Draft.childRecordMember (typedElement "kpi" "Assessment" "KPI" "asserted")
    , Draft.childRecordMember
        (relationship
           "contextualizes"
           "CompositionRelationship"
           False
           "contextualizes"
           "measure"
           "kpi"
           [property "contextualizes-commitment" "o2i.commitment" "asserted"])
    , Draft.childRecordMember
        (connectedView
           "kpi-view"
           "KPI"
           ["measure", "kpi"]
           [("contextualizes", "measure", "kpi")])
    ]

relationApplicabilityDraft ::
     Text -> Bool -> Text -> Text -> Text -> Text -> Text -> Draft.ProfileDraft
relationApplicabilityDraft relationshipType directed label sourceElement sourceType targetElement targetType =
  modelDraft
    [ Draft.childRecordMember
        (typedElement "source" sourceElement sourceType "asserted")
    , Draft.childRecordMember
        (typedElement "target" targetElement targetType "asserted")
    , Draft.childRecordMember
        (relationship
           "relation"
           relationshipType
           directed
           label
           "source"
           "target"
           [property "relation-commitment" "o2i.commitment" "asserted"])
    , Draft.childRecordMember
        (connectedView
           "relation-view"
           "Relation"
           ["source", "target"]
           [("relation", "source", "target")])
    ]

invalidCarrierDraft :: Draft.ProfileDraft
invalidCarrierDraft = graphDraft False "Driver"

graphDraft :: Bool -> Text -> Draft.ProfileDraft
graphDraft permuted strategyType =
  modelDraft
    (order
       [ Draft.childRecordMember strategy
       , Draft.childRecordMember need
       , Draft.childRecordMember qualifies
       , Draft.childRecordMember mainView
       ])
  where
    order =
      if permuted
        then reverse
        else id
    strategy =
      element
        "strategy"
        "Grouping"
        (order
           [ property "strategy-type" "o2i.type" strategyType
           , property "strategy-commitment" "o2i.commitment" "asserted"
           ])
    need =
      element
        "need"
        "Grouping"
        (order
           [ property "need-type" "o2i.type" "Need"
           , property "need-commitment" "o2i.commitment" "candidate"
           ])
    qualifies =
      relationship
        "qualifies"
        "AssociationRelationship"
        True
        "qualifies"
        "strategy"
        "need"
        [property "qualifies-commitment" "o2i.commitment" "asserted"]
    mainView = simpleView "main-view" "Main" ["strategy"]

unmarkedDisplayedDraft :: Draft.ProfileDraft
unmarkedDisplayedDraft =
  modelDraft
    [ Draft.childRecordMember (element "unmarked" "Grouping" [])
    , Draft.childRecordMember
        (simpleView "main-view" "Main" ["unmarked", "unmarked"])
    ]

malformedIdentityDraft :: Draft.ProfileDraft
malformedIdentityDraft =
  Draft.profileDraft
    (Draft.modelRootDraft
       (Draft.draftIdentity
          [text "model-a" "model-identity-a", text "model-b" "model-identity-b"])
       (location "model")
       [Draft.opaqueMember opaqueEvidence])
  where
    opaqueEvidence =
      Draft.draftOpaqueEvidence
        Draft.opaqueChild
        (Draft.draftNativeName Nothing "extension")
        [text "retained" "extension-value"]
        (location "extension")

notationOutcomeDraft :: Draft.ProfileDraft
notationOutcomeDraft =
  modelDraft
    [ Draft.childRecordMember
        (elementWithIdentity (Draft.draftIdentity []) "missing" "Grouping" [])
    , Draft.childRecordMember
        (elementWithIdentity
           (Draft.draftIdentity [text "a" "multiple-a", text "b" "multiple-b"])
           "multiple"
           "Grouping"
           [])
    , Draft.childRecordMember
        (elementWithIdentity
           (Draft.draftIdentity
              [Draft.draftBooleanScalar True (location "invalid-boolean")])
           "invalid-boolean"
           "Grouping"
           [])
    , Draft.childRecordMember
        (elementWithIdentity
           (Draft.draftIdentity [text "" "invalid-empty"])
           "invalid-empty"
           "Grouping"
           [])
    , Draft.childRecordMember
        (elementWithIdentity
           (Draft.draftIdentity [text "bad\NULidentity" "invalid-u0000"])
           "invalid-u0000"
           "Grouping"
           [])
    , Draft.childRecordMember
        (elementWithIdentity
           (Draft.draftIdentity [text "\xD800" "invalid-surrogate"])
           "invalid-surrogate"
           "Grouping"
           [])
    , Draft.childRecordMember (element "resolved-target" "Grouping" [])
    , Draft.childRecordMember (element "duplicate-target" "Grouping" [])
    , Draft.childRecordMember (element "duplicate-target" "Grouping" [])
    , Draft.childRecordMember
        (simpleView "wrong-family-target" "Wrong family" [])
    , Draft.childRecordMember
        (viewNodeWithIdentity "reference-invalid" (Draft.draftIdentity []))
    , Draft.childRecordMember (viewNode "reference-missing" "absent-target")
    , Draft.childRecordMember
        (viewNode "reference-wrong-family" "wrong-family-target")
    , Draft.childRecordMember
        (viewNode "reference-ambiguous" "duplicate-target")
    , Draft.childRecordMember (viewNode "reference-resolved" "resolved-target")
    ]

modelRootCrossFamilyDuplicateDraft :: Draft.ProfileDraft
modelRootCrossFamilyDuplicateDraft =
  modelDraft
    [ Draft.childRecordMember (element "model" "Grouping" [])
    , Draft.childRecordMember (simpleView "main-view" "Main" [])
    ]

viewCrossFamilyDuplicateDraft :: Draft.ProfileDraft
viewCrossFamilyDuplicateDraft =
  modelDraft
    [ Draft.childRecordMember (element "main-view" "Grouping" [])
    , Draft.childRecordMember (simpleView "main-view" "Main" [])
    ]

retentionDraft :: Draft.ProfileDraft
retentionDraft =
  modelDraft
    [Draft.childRecordMember definition, Draft.childRecordMember retained]
  where
    definition =
      Draft.propertyDefinitionDraft
        (identity "definition")
        (spannedLocation "definition" 3 5 8 13)
        [ Draft.nameFieldMember
            [text "external-key" "definition-name"]
            (location "definition-name-field")
        ]
    retained =
      element
        "retained"
        "Grouping"
        [ Draft.nameFieldMember retainedScalars (location "retained-name")
        , Draft.propertyMember retainedProperty
        , Draft.opaqueMember childOpaque
        ]
    retainedProperty =
      Draft.draftProperty
        (Draft.propertyDefinitionKey
           (Draft.propertyDefinitionReference
              (identity "definition")
              (spannedLocation "property-key-reference" 11 2 11 12)))
        retainedScalars
        (spannedLocation "property" 10 1 12 20)
        [attributeOpaque]
    retainedScalars =
      [ text "text" "scalar-text"
      , Draft.draftBooleanScalar True (location "scalar-boolean")
      , Draft.draftNumberScalar "12.50" (location "scalar-number")
      , Draft.draftNativeNameScalar
          (Draft.draftNativeName (Just "urn:test") "name")
          (location "scalar-native-name")
      , Draft.draftOtherScalar "json" "{\"a\":1}" (location "scalar-other")
      ]
    attributeOpaque =
      Draft.draftOpaqueEvidence
        Draft.opaqueAttribute
        (Draft.draftNativeName (Just "urn:test") "flag")
        [text "opaque-attribute" "opaque-attribute-value"]
        (spannedLocation "opaque-attribute" 10 3 10 19)
    childOpaque =
      Draft.draftOpaqueEvidence
        Draft.opaqueChild
        (Draft.draftNativeName Nothing "extension")
        [text "opaque-child" "opaque-child-value"]
        (spannedLocation "opaque-child" 13 1 14 7)

qualificationDraft :: Draft.ProfileDraft
qualificationDraft = qualificationModel validQualificationReferences []

qualificationMissingRoleDraft :: Draft.ProfileDraft
qualificationMissingRoleDraft =
  qualificationModel
    (qualificationReference "proposal-strategy" "strategy" Nothing
       : drop 1 validQualificationReferences)
    []

qualificationWrongRoleDraft :: Draft.ProfileDraft
qualificationWrongRoleDraft =
  qualificationModel
    (qualificationReference "proposal-strategy" "strategy" (Just "unknown")
       : drop 1 validQualificationReferences)
    []

qualificationMultipleInvalidRoleValuesDraft :: Draft.ProfileDraft
qualificationMultipleInvalidRoleValuesDraft =
  qualificationModel
    (relationship
       "proposal-strategy"
       "AssociationRelationship"
       True
       "references"
       "proposal"
       "strategy"
       [ Draft.propertyMember
           (Draft.draftProperty
              (Draft.directPropertyKey
                 [text "o2i.role" "proposal-strategy-role-key"])
              [ Draft.draftBooleanScalar
                  True
                  (location "proposal-strategy-role-boolean")
              , text "unknown" "proposal-strategy-role-unknown"
              ]
              (location "proposal-strategy-role")
              [])
       ]
       : drop 1 validQualificationReferences)
    []

qualificationWrongRelationshipDraft :: Draft.ProfileDraft
qualificationWrongRelationshipDraft =
  qualificationModel
    (relationship
       "proposal-strategy"
       "CompositionRelationship"
       True
       "references"
       "proposal"
       "strategy"
       [property "proposal-strategy-role" "o2i.role" "strategy"]
       : drop 1 validQualificationReferences)
    []

qualificationWrongDirectionDraft :: Draft.ProfileDraft
qualificationWrongDirectionDraft =
  qualificationModel
    (relationship
       "proposal-strategy"
       "AssociationRelationship"
       True
       "references"
       "strategy"
       "proposal"
       [property "proposal-strategy-role" "o2i.role" "strategy"]
       : drop 1 validQualificationReferences)
    []

qualificationNonProposalRoleDraft :: Draft.ProfileDraft
qualificationNonProposalRoleDraft =
  qualificationModel
    validQualificationReferences
    [ relationship
        "unrelated-role"
        "AssociationRelationship"
        True
        "references"
        "strategy"
        "need"
        [property "unrelated-role-property" "o2i.role" "strategy"]
    ]

qualificationWrongCarrierDraft :: Draft.ProfileDraft
qualificationWrongCarrierDraft =
  qualificationModelWithProposal
    (qualificationProposal
       "Grouping"
       "NeedQualificationProposal"
       [defaultRationale]
       [property "proposal-source" "o2i.source" "source-document"])
    validQualificationReferences
    []

qualificationInvalidTypeDraft :: Draft.ProfileDraft
qualificationInvalidTypeDraft =
  qualificationModelWithProposal
    (qualificationProposal
       "Assessment"
       "NotAQualificationProposal"
       [defaultRationale]
       [property "proposal-source" "o2i.source" "source-document"])
    validQualificationReferences
    []

qualificationNoRationaleDraft :: Draft.ProfileDraft
qualificationNoRationaleDraft =
  qualificationModelWithProposal
    (qualificationProposal
       "Assessment"
       "NeedQualificationProposal"
       []
       [property "proposal-source" "o2i.source" "source-document"])
    validQualificationReferences
    []

qualificationNormalizedRationaleDraft :: Draft.ProfileDraft
qualificationNormalizedRationaleDraft =
  qualificationModelWithProposal
    (qualificationProposal
       "Assessment"
       "NeedQualificationProposal"
       [ Draft.elementDocumentationFieldMember
           [text " \tCafe\x0301\r\nLine 2\r \t" "proposal-documentation"]
           (location "proposal-documentation-field")
       ]
       [property "proposal-source" "o2i.source" "source-document"])
    validQualificationReferences
    []

qualificationMultipleRationaleDraft :: Draft.ProfileDraft
qualificationMultipleRationaleDraft =
  qualificationModelWithProposal
    (qualificationProposal
       "Assessment"
       "NeedQualificationProposal"
       [ defaultRationale
       , Draft.elementDocumentationFieldMember
           [text "A second rationale." "proposal-documentation-2"]
           (location "proposal-documentation-field-2")
       ]
       [property "proposal-source" "o2i.source" "source-document"])
    validQualificationReferences
    []

qualificationInvalidRationaleDraft :: Draft.ProfileDraft
qualificationInvalidRationaleDraft =
  qualificationModelWithProposal
    (qualificationProposal
       "Assessment"
       "NeedQualificationProposal"
       [ Draft.elementDocumentationFieldMember
           [text "invalid\NULrationale" "proposal-documentation"]
           (location "proposal-documentation-field")
       ]
       [property "proposal-source" "o2i.source" "source-document"])
    validQualificationReferences
    []

qualificationNormalizedSourcesDraft :: Draft.ProfileDraft
qualificationNormalizedSourcesDraft =
  qualificationModelWithProposal
    (qualificationProposal
       "Assessment"
       "NeedQualificationProposal"
       [defaultRationale]
       [ property "proposal-source-z" "o2i.source" " z-source "
       , property "proposal-source-a-1" "o2i.source" "a-source"
       , property "proposal-source-a-2" "o2i.source" "a-source"
       , property "proposal-source-nfc" "o2i.source" "e\x0301-source"
       ])
    validQualificationReferences
    []

qualificationModel ::
     [Draft.RelationshipDraft]
  -> [Draft.RelationshipDraft]
  -> Draft.ProfileDraft
qualificationModel references extras =
  qualificationModelWithProposal defaultQualificationProposal references extras

qualificationModelWithProposal ::
     Draft.ElementDraft
  -> [Draft.RelationshipDraft]
  -> [Draft.RelationshipDraft]
  -> Draft.ProfileDraft
qualificationModelWithProposal proposal references extras =
  modelDraft
    (map Draft.childRecordMember (proposal : qualificationTargetsElements)
       <> map Draft.childRecordMember allRelationships
       <> [Draft.childRecordMember qualificationView])
  where
    allRelationships = references <> extras
    qualificationView =
      connectedView
        "qualification-view"
        "Qualification"
        (map fst qualificationTargets <> ["proposal"])
        [ (identifier, source, target)
        | relation <- allRelationships
        , let (identifier, source, target) = relationshipCoordinates relation
        ]

qualificationElements :: [Draft.ElementDraft]
qualificationElements =
  defaultQualificationProposal : qualificationTargetsElements

defaultQualificationProposal :: Draft.ElementDraft
defaultQualificationProposal =
  qualificationProposal
    "Assessment"
    "NeedQualificationProposal"
    [defaultRationale]
    [property "proposal-source" "o2i.source" "source-document"]

defaultRationale :: Draft.DraftMember Draft.ElementRole
defaultRationale =
  Draft.elementDocumentationFieldMember
    [text "A precise qualification rationale." "proposal-documentation"]
    (location "proposal-documentation-field")

qualificationProposal ::
     Text
  -> Text
  -> [Draft.DraftMember Draft.ElementRole]
  -> [Draft.DraftMember Draft.ElementRole]
  -> Draft.ElementDraft
qualificationProposal archiMateType o2iType rationale sources =
  element
    "proposal"
    archiMateType
    (rationale <> [property "proposal-type" "o2i.type" o2iType] <> sources)

qualificationTargetsElements :: [Draft.ElementDraft]
qualificationTargetsElements =
  [ typedElement "strategy" "Grouping" "Strategy" "asserted"
  , typedElement "need" "Grouping" "Need" "candidate"
  , typedElement "objective" "Goal" "Objective" "asserted"
  , typedElement "key-result" "Outcome" "KeyResult" "asserted"
  ]

qualificationTargets :: [(Text, Text)]
qualificationTargets =
  [ ("strategy", "strategy")
  , ("need", "need")
  , ("objective", "objective")
  , ("key-result", "key-result")
  ]

validQualificationReferences :: [Draft.RelationshipDraft]
validQualificationReferences =
  [ qualificationReference "proposal-strategy" "strategy" (Just "strategy")
  , qualificationReference "proposal-need" "need" (Just "need")
  , qualificationReference "proposal-objective" "objective" (Just "objective")
  , qualificationReference
      "proposal-key-result"
      "key-result"
      (Just "key-result")
  ]

qualificationReference :: Text -> Text -> Maybe Text -> Draft.RelationshipDraft
qualificationReference identifier target role =
  relationship
    identifier
    "AssociationRelationship"
    True
    "references"
    "proposal"
    target
    (case role of
       Nothing -> []
       Just value -> [property (identifier <> "-role") "o2i.role" value])

collectiveClosedDraft, collectiveOpenDraft :: Draft.ProfileDraft
collectiveClosedDraft = collectiveModel "closed" False

collectiveOpenDraft = collectiveModel "open" False

collectiveChainDraft :: Draft.ProfileDraft
collectiveChainDraft = collectiveModel "closed" True

collectiveWrongCarrierDraft :: Draft.ProfileDraft
collectiveWrongCarrierDraft =
  collectiveCandidateDraft
    (element
       "claim"
       "Grouping"
       [property "claim-type" "o2i.type" "CollectiveStrategyRealization"])

collectiveInvalidTypeDraft :: Draft.ProfileDraft
collectiveInvalidTypeDraft =
  collectiveCandidateDraft
    (element
       "claim"
       "AndJunction"
       [ property "claim-type" "o2i.type" "NotACollectiveRealization"
       , property "claim-commitment" "o2i.commitment" "asserted"
       , property "claim-completeness" "o2i.participant-completeness" "closed"
       ])

collectiveCandidateDraft :: Draft.ElementDraft -> Draft.ProfileDraft
collectiveCandidateDraft claim =
  modelDraft
    [ Draft.childRecordMember claim
    , Draft.childRecordMember
        (simpleView "collective-view" "Collective" ["claim"])
    ]

collectiveModel :: Text -> Bool -> Draft.ProfileDraft
collectiveModel completeness includeChain =
  modelDraft
    (map Draft.childRecordMember elements
       <> map Draft.childRecordMember segments
       <> [Draft.childRecordMember scopeView])
  where
    elements =
      [ typedElement "contributor-a" "Grouping" "Strategy" "asserted"
      , typedElement "contributor-b" "Grouping" "Strategy" "asserted"
      , typedElement "target" "Grouping" "Strategy" "asserted"
      , collectiveClaim "claim" completeness
      ]
        <> [collectiveClaim "other-claim" completeness | includeChain]
    segments =
      [ collectiveSegment "incoming-a" "contributor-a" "claim"
      , collectiveSegment "incoming-b" "contributor-b" "claim"
      , collectiveSegment "outgoing" "claim" "target"
      ]
        <> [ collectiveSegment "junction-chain" "claim" "other-claim"
           | includeChain
           ]
    scopeView = simpleView "collective-view" "Collective" ["claim"]

branchIsolationDraft :: Draft.ProfileDraft
branchIsolationDraft =
  modelDraft
    (map Draft.childRecordMember qualificationElements
       <> map Draft.childRecordMember validQualificationReferences
       <> map Draft.childRecordMember collectiveElements
       <> map Draft.childRecordMember collectiveSegments
       <> [ Draft.childRecordMember
              (simpleView "qualification-only" "Qualification only" ["proposal"])
          , Draft.childRecordMember
              (simpleView "collective-only" "Collective only" ["claim"])
          ])
  where
    collectiveElements =
      [ typedElement "contributor-a" "Grouping" "Strategy" "asserted"
      , typedElement "contributor-b" "Grouping" "Strategy" "asserted"
      , typedElement "target" "Grouping" "Strategy" "asserted"
      , collectiveClaim "claim" "closed"
      ]
    collectiveSegments =
      [ collectiveSegment "incoming-a" "contributor-a" "claim"
      , collectiveSegment "incoming-b" "contributor-b" "claim"
      , collectiveSegment "outgoing" "claim" "target"
      ]

collectiveClaim :: Text -> Text -> Draft.ElementDraft
collectiveClaim identifier completeness =
  element
    identifier
    "AndJunction"
    [ property
        (identifier <> "-type")
        "o2i.type"
        "CollectiveStrategyRealization"
    , property (identifier <> "-commitment") "o2i.commitment" "asserted"
    , property
        (identifier <> "-completeness")
        "o2i.participant-completeness"
        completeness
    ]

collectiveSegment :: Text -> Text -> Text -> Draft.RelationshipDraft
collectiveSegment identifier source target =
  relationship
    identifier
    "RealizationRelationship"
    False
    "realizes"
    source
    target
    []

typedElement :: Text -> Text -> Text -> Text -> Draft.ElementDraft
typedElement identifier archiMateType o2iType commitment =
  element
    identifier
    archiMateType
    [ property (identifier <> "-type") "o2i.type" o2iType
    , property (identifier <> "-commitment") "o2i.commitment" commitment
    ]

modelDraft :: [Draft.DraftMember Draft.ModelRootRole] -> Draft.ProfileDraft
modelDraft members =
  Draft.profileDraft
    (Draft.modelRootDraft
       (identity "model")
       (location "model")
       (property "model-profile" "o2i.profile" "o2i.archimate-profile@0.3"
          : members))

element ::
     Text -> Text -> [Draft.DraftMember Draft.ElementRole] -> Draft.ElementDraft
element identifier archiMateType =
  elementWithIdentity (identity identifier) identifier archiMateType

elementWithIdentity ::
     Draft.DraftIdentity Draft.ElementRole
  -> Text
  -> Text
  -> [Draft.DraftMember Draft.ElementRole]
  -> Draft.ElementDraft
elementWithIdentity identifierEvidence locationName archiMateType members =
  Draft.elementDraft
    identifierEvidence
    (location locationName)
    (Draft.typeFieldMember
       [text archiMateType (locationName <> "-type-field")]
       (location (locationName <> "-type-field"))
       : members)

relationship ::
     Text
  -> Text
  -> Bool
  -> Text
  -> Text
  -> Text
  -> [Draft.DraftMember Draft.RelationshipRole]
  -> Draft.RelationshipDraft
relationship identifier archiMateType directed label source target members =
  Draft.relationshipDraft
    (identity identifier)
    (location identifier)
    ([ Draft.typeFieldMember
         [text archiMateType (identifier <> "-type-field")]
         (location (identifier <> "-type-field"))
     , Draft.directedFieldMember
         [ Draft.draftBooleanScalar
             directed
             (location (identifier <> "-directed"))
         ]
         (location (identifier <> "-directed"))
     , Draft.nameFieldMember
         [text label (identifier <> "-name")]
         (location (identifier <> "-name"))
     , Draft.referenceMember
         (Draft.relationshipSourceReference
            (identity source)
            (location (identifier <> "-source")))
     , Draft.referenceMember
         (Draft.relationshipTargetReference
            (identity target)
            (location (identifier <> "-target")))
     ]
       <> members)

relationshipCoordinates :: Draft.RelationshipDraft -> (Text, Text, Text)
relationshipCoordinates relation =
  ( singleIdentity (Draft.draftRecordIdentity relation)
  , referenceIdentity "source" relation
  , referenceIdentity "target" relation)

referenceIdentity :: Text -> Draft.RelationshipDraft -> Text
referenceIdentity expected relation =
  case [ target
       | member <- Draft.draftRecordMembers relation
       , target <-
           Draft.foldDraftMember
             (\_ _ _ -> [])
             (const [])
             (\reference ->
                if referenceField (Draft.draftReferenceField reference)
                     == expected
                  then [singleIdentity (Draft.draftReferenceIdentity reference)]
                  else [])
             (const [])
             (const [])
             member
       ] of
    [target] -> target
    targets ->
      error ("expected one relationship endpoint, got " <> show targets)

referenceField :: Draft.DraftReferenceFieldValue -> Text
referenceField =
  Draft.foldDraftReferenceFieldValue
    "definition"
    "source"
    "target"
    "node-element"
    "connection-relationship"
    "connection-source"
    "connection-target"

simpleView :: Text -> Text -> [Text] -> Draft.ViewDraft
simpleView identifier name targets =
  Draft.viewDraft
    (identity identifier)
    (location identifier)
    (Draft.nameFieldMember
       [text name (identifier <> "-name")]
       (location (identifier <> "-name"))
       : [ Draft.childRecordMember (viewNode (target <> "-node") target)
         | target <- targets
         ])

connectedView ::
     Text -> Text -> [Text] -> [(Text, Text, Text)] -> Draft.ViewDraft
connectedView identifier name targets connections =
  Draft.viewDraft
    (identity identifier)
    (location identifier)
    (Draft.nameFieldMember
       [text name (identifier <> "-name")]
       (location (identifier <> "-name"))
       : map (Draft.childRecordMember . uncurry viewNode) nodes
           <> map (Draft.childRecordMember . connection) connections)
  where
    nodes = [(target <> "-node", target) | target <- targets]
    connection (relationshipId, source, target) =
      viewConnection
        (relationshipId <> "-connection")
        relationshipId
        (source <> "-node")
        (target <> "-node")

viewNode :: Text -> Text -> Draft.ViewNodeDraft
viewNode identifier target = viewNodeWithIdentity identifier (identity target)

viewNodeWithIdentity ::
     Text -> Draft.DraftIdentity Draft.ElementRole -> Draft.ViewNodeDraft
viewNodeWithIdentity identifier target =
  Draft.viewNodeDraft
    (identity identifier)
    (location identifier)
    [ Draft.referenceMember
        (Draft.viewNodeElementReference
           target
           (location (identifier <> "-element")))
    ]

viewConnection :: Text -> Text -> Text -> Text -> Draft.ViewConnectionDraft
viewConnection identifier relationshipId sourceNode targetNode =
  Draft.viewConnectionDraft
    (identity identifier)
    (location identifier)
    [ Draft.referenceMember
        (Draft.viewConnectionRelationshipReference
           (identity relationshipId)
           (location (identifier <> "-relationship")))
    , Draft.referenceMember
        (Draft.viewConnectionSourceReference
           (identity sourceNode)
           (location (identifier <> "-source")))
    , Draft.referenceMember
        (Draft.viewConnectionTargetReference
           (identity targetNode)
           (location (identifier <> "-target")))
    ]

property :: Text -> Text -> Text -> Draft.DraftMember ownerRole
property identifier key value =
  Draft.propertyMember
    (Draft.draftProperty
       (Draft.directPropertyKey [text key (identifier <> "-key")])
       [text value (identifier <> "-value")]
       (location identifier)
       [])

identity :: Text -> Draft.DraftIdentity recordRole
identity value = Draft.draftIdentity [text value (value <> "-identity")]

singleIdentity :: Draft.DraftIdentity recordRole -> Text
singleIdentity identityEvidence =
  case Draft.foldDraftIdentity (map Draft.draftScalarText) identityEvidence of
    [value] -> value
    values -> error ("expected one identity value, got " <> show values)

text :: Text -> Text -> Draft.DraftScalar
text value source = Draft.draftTextScalar value (location source)

location :: Text -> Draft.DraftLocation
location subject =
  Draft.draftLocation
    (Draft.draftSourcePath
       (Draft.draftPathStep (Draft.draftNativeName Nothing subject) 0)
       [])
    Nothing

spannedLocation ::
     Text -> Integer -> Integer -> Integer -> Integer -> Draft.DraftLocation
spannedLocation subject startLine startColumn endLine endColumn =
  Draft.draftLocation
    (Draft.draftSourcePath
       (Draft.draftPathStep (Draft.draftNativeName (Just "urn:test") subject) 2)
       [Draft.draftPathStep (Draft.draftNativeName Nothing "value") 0])
    (Just
       (Draft.draftSourceSpan
          (Draft.draftSourcePosition
             (fromInteger startLine)
             (fromInteger startColumn)
             (Just 101))
          (Draft.draftSourcePosition
             (fromInteger endLine)
             (fromInteger endColumn)
             (Just 202))))
