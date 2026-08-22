{-# LANGUAGE OverloadedStrings #-}

-- | Public-source scenarios shared by owner conformance and contract tests.
module O2I.ArchiMate.Profile.Conformance.Source
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
  , qualificationBatchDraft
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
  , qualificationContextualizedDraft
  , graphPropertyDefinitionDraft
  , qualificationPropertyDefinitionDraft
  , collectiveClosedDraft
  , collectiveOpenDraft
  , collectiveChainDraft
  , collectiveWrongCarrierDraft
  , collectiveInvalidTypeDraft
  , branchIsolationDraft
  , ownerConformanceMutationDrafts
  ) where

import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified O2I.ArchiMate.Profile.Draft as Draft

-- | Small valid Graph source in canonical member order.
validDraft :: Draft.ProfileDraft
validDraft = graphDraft False "Strategy"

-- | 'validDraft' with semantically irrelevant source order permuted.
validDraftPermuted :: Draft.ProfileDraft
validDraftPermuted = graphDraft True "Strategy"

-- | Valid source exercising the KPI carrier mapping.
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

-- | Public source for one carrier/relation applicability combination.
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

-- | Graph source with an invalid native carrier category.
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

-- | Source with an unmarked element displayed more than once.
unmarkedDisplayedDraft :: Draft.ProfileDraft
unmarkedDisplayedDraft =
  modelDraft
    [ Draft.childRecordMember (element "unmarked" "Grouping" [])
    , Draft.childRecordMember
        (simpleView "main-view" "Main" ["unmarked", "unmarked"])
    ]

-- | Source whose model identity has invalid cardinality.
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

-- | Source covering the complete closed Notation outcome vocabulary.
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

-- | Duplicate identity shared by the model root and an Element.
modelRootCrossFamilyDuplicateDraft :: Draft.ProfileDraft
modelRootCrossFamilyDuplicateDraft =
  modelDraft
    [ Draft.childRecordMember (element "model" "Grouping" [])
    , Draft.childRecordMember (simpleView "main-view" "Main" [])
    ]

-- | Duplicate identity shared by the selected View and an Element.
viewCrossFamilyDuplicateDraft :: Draft.ProfileDraft
viewCrossFamilyDuplicateDraft =
  modelDraft
    [ Draft.childRecordMember (element "main-view" "Grouping" [])
    , Draft.childRecordMember (simpleView "main-view" "Main" [])
    ]

-- | Source retaining every scalar, key, opaque, and location evidence form.
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

-- | Valid single-proposal qualification source.
qualificationDraft :: Draft.ProfileDraft
qualificationDraft = qualificationModel validQualificationReferences []

-- | A public-source workload with the requested number of independent,
-- successful qualification proposals in one selected View.
qualificationBatchDraft :: Int -> Draft.ProfileDraft
qualificationBatchDraft requestedCount =
  modelDraft
    (map Draft.childRecordMember batchElements
       <> map Draft.childRecordMember batchRelationships
       <> [Draft.childRecordMember batchView])
  where
    proposalOrdinals = [1 .. max 0 requestedCount]
    batchElements = concatMap proposalElements proposalOrdinals
    batchRelationships = concatMap proposalRelationships proposalOrdinals
    batchView =
      connectedView
        "qualification-batch-view"
        "Qualification batch"
        (concatMap proposalElementIds proposalOrdinals)
        (mapMaybe relationshipCoordinates batchRelationships)
    proposalElements ordinal =
      element
        (proposalId ordinal)
        "Assessment"
        [ Draft.elementDocumentationFieldMember
            [ text
                "A precise qualification rationale."
                (prefix ordinal <> "-documentation")
            ]
            (location (prefix ordinal <> "-documentation-field"))
        , property
            (prefix ordinal <> "-type")
            "o2i.type"
            "NeedQualificationProposal"
        , property (prefix ordinal <> "-source") "o2i.source" "source-document"
        ]
        : [ typedElement
            (targetId ordinal role)
            archiMateType
            o2iType
            commitment
          | (role, archiMateType, o2iType, commitment) <- batchTargets
          ]
    proposalRelationships ordinal =
      [ relationship
        (prefix ordinal <> "-reference-" <> role)
        "AssociationRelationship"
        True
        "references"
        (proposalId ordinal)
        (targetId ordinal role)
        [ property
            (prefix ordinal <> "-reference-" <> role <> "-role")
            "o2i.role"
            role
        ]
      | (role, _, _, _) <- batchTargets
      ]
    proposalElementIds ordinal =
      proposalId ordinal
        : [targetId ordinal role | (role, _, _, _) <- batchTargets]
    proposalId ordinal = prefix ordinal <> "-proposal"
    targetId ordinal role = prefix ordinal <> "-" <> role
    prefix ordinal = "batch-" <> Text.pack (show ordinal)
    batchTargets =
      [ ("strategy", "Grouping", "Strategy", "asserted")
      , ("need", "Grouping", "Need", "candidate")
      , ("objective", "Goal", "Objective", "asserted")
      , ("key-result", "Outcome", "KeyResult", "asserted")
      ]

-- | Qualification source with one missing reference role.
qualificationMissingRoleDraft :: Draft.ProfileDraft
qualificationMissingRoleDraft =
  qualificationModel
    (qualificationReference "proposal-strategy" "strategy" Nothing
       : drop 1 validQualificationReferences)
    []

-- | Qualification source with one unknown reference role.
qualificationWrongRoleDraft :: Draft.ProfileDraft
qualificationWrongRoleDraft =
  qualificationModel
    (qualificationReference "proposal-strategy" "strategy" (Just "unknown")
       : drop 1 validQualificationReferences)
    []

-- | Qualification source with several invalid values in one role property.
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

-- | Qualification source using a non-Association reference.
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

-- | Qualification source whose reference points toward the proposal.
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

-- | Source placing qualification-role metadata outside a proposal reference.
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

-- | Qualification marker placed on the wrong native carrier.
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

-- | Assessment carrier with an invalid qualification type marker.
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

-- | Valid qualification proposal without an optional rationale.
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

-- | Qualification proposal whose rationale requires normalization.
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

-- | Qualification proposal with ambiguous rationale fields.
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

-- | Qualification proposal with a forbidden rationale scalar.
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

-- | Qualification proposal with normalized, ordered, duplicate source values.
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

-- | Qualification proposal with an additional contextualization relation.
qualificationContextualizedDraft :: Draft.ProfileDraft
qualificationContextualizedDraft =
  qualificationModel
    validQualificationReferences
    [ relationship
        "need-contextualizes-strategy"
        "CompositionRelationship"
        False
        "contextualizes"
        "need"
        "strategy"
        []
    ]

-- | Graph source using a definition-backed non-O2I property.
graphPropertyDefinitionDraft :: Draft.ProfileDraft
graphPropertyDefinitionDraft =
  modelDraft
    [ Draft.childRecordMember
        (propertyDefinition "external-definition" "external")
    , Draft.childRecordMember
        (element
           "strategy"
           "Grouping"
           [ property "strategy-type" "o2i.type" "Strategy"
           , property "strategy-commitment" "o2i.commitment" "asserted"
           , propertyByDefinition
               "strategy-external"
               "external-definition"
               "value"
           ])
    , Draft.childRecordMember (simpleView "main-view" "Main" ["strategy"])
    ]

-- | Qualification source using a definition-backed O2I source property.
qualificationPropertyDefinitionDraft :: Draft.ProfileDraft
qualificationPropertyDefinitionDraft =
  modelDraft
    (Draft.childRecordMember
       (propertyDefinition "source-definition" "o2i.source")
       : map Draft.childRecordMember (proposal : qualificationTargetsElements)
           <> map Draft.childRecordMember validQualificationReferences
           <> [ Draft.childRecordMember
                  (connectedView
                     "qualification-view"
                     "Qualification"
                     (map fst qualificationTargets <> ["proposal"])
                     (mapMaybe
                        relationshipCoordinates
                        validQualificationReferences))
              ])
  where
    proposal =
      qualificationProposal
        "Assessment"
        "NeedQualificationProposal"
        [defaultRationale]
        [ propertyByDefinition
            "proposal-source-by-definition"
            "source-definition"
            "source-document"
        ]

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
        (mapMaybe relationshipCoordinates allRelationships)

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

-- | Valid closed and open collective-strategy-realization sources.
collectiveClosedDraft, collectiveOpenDraft :: Draft.ProfileDraft
collectiveClosedDraft = collectiveModel "closed" False

collectiveOpenDraft = collectiveModel "open" False

-- | Collective source containing a forbidden Junction-to-Junction chain.
collectiveChainDraft :: Draft.ProfileDraft
collectiveChainDraft = collectiveModel "closed" True

-- | Collective marker placed on the wrong native carrier.
collectiveWrongCarrierDraft :: Draft.ProfileDraft
collectiveWrongCarrierDraft =
  collectiveCandidateDraft
    (element
       "claim"
       "Grouping"
       [property "claim-type" "o2i.type" "CollectiveStrategyRealization"])

-- | Junction carrier with an invalid collective type marker.
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

-- | One document with isolated qualification and collective selected Views.
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

-- | Public Draft mutations that exercise the remaining reachable negative
-- owner rules.  The expected observations remain catalog-derived elsewhere.
ownerConformanceMutationDrafts :: [Draft.ProfileDraft]
ownerConformanceMutationDrafts =
  [ reservedMutationDraft
  , carrierMutationDraft
      [ property "carrier-type-a" "o2i.type" "Strategy"
      , property "carrier-type-b" "o2i.type" "Strategy"
      ]
      [property "carrier-commitment" "o2i.commitment" "asserted"]
  , carrierMutationDraft
      [ propertyScalars
          "carrier-type"
          "o2i.type"
          [text "Strategy" "carrier-type-a", text "Strategy" "carrier-type-b"]
      ]
      [property "carrier-commitment" "o2i.commitment" "asserted"]
  , carrierMutationDraft
      [ propertyScalars
          "carrier-type"
          "o2i.type"
          [Draft.draftBooleanScalar True (location "carrier-type-boolean")]
      ]
      [property "carrier-commitment" "o2i.commitment" "asserted"]
  , carrierMutationDraft
      [property "carrier-type" "o2i.type" "Strategy"]
      [property "carrier-commitment" "o2i.commitment" "unknown"]
  , carrierMutationDraft
      [property "carrier-type" "o2i.type" "Strategy"]
      [ propertyScalars
          "carrier-commitment"
          "o2i.commitment"
          [ text "asserted" "carrier-commitment-a"
          , text "asserted" "carrier-commitment-b"
          ]
      ]
  , carrierMutationDraft
      [property "carrier-type" "o2i.type" "Strategy"]
      [ propertyScalars
          "carrier-commitment"
          "o2i.commitment"
          [ Draft.draftBooleanScalar
              True
              (location "carrier-commitment-boolean")
          ]
      ]
  , semanticRelationMutationDraft []
  , semanticRelationMutationDraft
      [ property "relation-commitment-a" "o2i.commitment" "asserted"
      , property "relation-commitment-b" "o2i.commitment" "asserted"
      ]
  , semanticRelationMutationDraft
      [property "relation-commitment" "o2i.commitment" "unknown"]
  , semanticRelationMutationDraft
      [ propertyScalars
          "relation-commitment"
          "o2i.commitment"
          [ text "asserted" "relation-commitment-a"
          , text "asserted" "relation-commitment-b"
          ]
      ]
  , semanticRelationMutationDraft
      [ propertyScalars
          "relation-commitment"
          "o2i.commitment"
          [ Draft.draftBooleanScalar
              True
              (location "relation-commitment-boolean")
          ]
      ]
  , collectivePropertyMutationDraft
      [property "claim-completeness" "o2i.participant-completeness" "unknown"]
  , collectivePropertyMutationDraft
      [ propertyScalars
          "claim-completeness"
          "o2i.participant-completeness"
          [ text "closed" "claim-completeness-a"
          , text "closed" "claim-completeness-b"
          ]
      ]
  , collectivePropertyMutationDraft
      [ propertyScalars
          "claim-completeness"
          "o2i.participant-completeness"
          [ Draft.draftBooleanScalar
              True
              (location "claim-completeness-boolean")
          ]
      ]
  , qualificationSourceMutationDraft
      [ propertyScalars
          "proposal-source"
          "o2i.source"
          [ text "source-a" "proposal-source-a"
          , text "source-b" "proposal-source-b"
          ]
      ]
  , qualificationSourceMutationDraft
      [ propertyScalars
          "proposal-source"
          "o2i.source"
          [Draft.draftBooleanScalar True (location "proposal-source-boolean")]
      ]
  , qualificationSourceMutationDraft
      [property "proposal-source" "o2i.source" "bad\NULsource"]
  , qualificationCommitmentDraft
  , qualificationReferenceCommitmentDraft
  , qualificationUnstableIdentityDraft
  , contextualizationMutationDraft
  , collectiveAdditionalPropertyDraft
  , collectiveSegmentMetadataDraft
  ]
    <> map
         influenceStrengthDraft
         [ "contributes-to"
         , "determines"
         , "directs"
         , "grounds"
         , "guides"
         , "indicates"
         , "orients"
         , "translates-into"
         ]

reservedMutationDraft :: Draft.ProfileDraft
reservedMutationDraft =
  carrierMutationDraft
    [ property "carrier-type" "o2i.type" "Strategy"
    , property "carrier-profile" "o2i.profile" "o2i.archimate-profile@0.3"
    , property "carrier-unknown" "o2i.unknown" "value"
    ]
    [property "carrier-commitment" "o2i.commitment" "asserted"]

carrierMutationDraft ::
     [Draft.DraftMember Draft.ElementRole]
  -> [Draft.DraftMember Draft.ElementRole]
  -> Draft.ProfileDraft
carrierMutationDraft typeMembers commitmentMembers =
  modelDraft
    [ Draft.childRecordMember
        (element "carrier" "Grouping" (typeMembers <> commitmentMembers))
    , Draft.childRecordMember (simpleView "carrier-view" "Carrier" ["carrier"])
    ]

semanticRelationMutationDraft ::
     [Draft.DraftMember Draft.RelationshipRole] -> Draft.ProfileDraft
semanticRelationMutationDraft members =
  modelDraft
    [ Draft.childRecordMember
        (typedElement "source" "Grouping" "Strategy" "asserted")
    , Draft.childRecordMember
        (typedElement "target" "Grouping" "Need" "candidate")
    , Draft.childRecordMember
        (relationship
           "relation"
           "AssociationRelationship"
           True
           "qualifies"
           "source"
           "target"
           members)
    , Draft.childRecordMember
        (connectedView
           "relation-view"
           "Relation"
           ["source", "target"]
           [("relation", "source", "target")])
    ]

collectivePropertyMutationDraft ::
     [Draft.DraftMember Draft.ElementRole] -> Draft.ProfileDraft
collectivePropertyMutationDraft completenessMembers =
  collectiveMutationDraft
    ([ property "claim-type" "o2i.type" "CollectiveStrategyRealization"
     , property "claim-commitment" "o2i.commitment" "asserted"
     ]
       <> completenessMembers)
    []

qualificationSourceMutationDraft ::
     [Draft.DraftMember Draft.ElementRole] -> Draft.ProfileDraft
qualificationSourceMutationDraft sources =
  qualificationModelWithProposal
    (qualificationProposal
       "Assessment"
       "NeedQualificationProposal"
       [defaultRationale]
       sources)
    validQualificationReferences
    []

qualificationCommitmentDraft :: Draft.ProfileDraft
qualificationCommitmentDraft =
  qualificationModelWithProposal
    (qualificationProposal
       "Assessment"
       "NeedQualificationProposal"
       [defaultRationale]
       [ property "proposal-source" "o2i.source" "source-document"
       , property "proposal-commitment" "o2i.commitment" "asserted"
       ])
    validQualificationReferences
    []

qualificationReferenceCommitmentDraft :: Draft.ProfileDraft
qualificationReferenceCommitmentDraft =
  qualificationModel
    (relationship
       "proposal-strategy"
       "AssociationRelationship"
       True
       "references"
       "proposal"
       "strategy"
       [ property "proposal-strategy-role" "o2i.role" "strategy"
       , property "proposal-strategy-commitment" "o2i.commitment" "asserted"
       ]
       : drop 1 validQualificationReferences)
    []

qualificationUnstableIdentityDraft :: Draft.ProfileDraft
qualificationUnstableIdentityDraft =
  qualificationModelWithProposal
    (elementWithIdentity
       (Draft.draftIdentity [])
       "proposal"
       "Assessment"
       [ defaultRationale
       , property "proposal-type" "o2i.type" "NeedQualificationProposal"
       , property "proposal-source" "o2i.source" "source-document"
       ])
    validQualificationReferences
    []

contextualizationMutationDraft :: Draft.ProfileDraft
contextualizationMutationDraft =
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
           [ property "contextualizes-commitment" "o2i.commitment" "unknown"
           , property "contextualizes-source" "o2i.source" "source-document"
           ])
    , Draft.childRecordMember
        (connectedView
           "context-view"
           "Context"
           ["measure", "kpi"]
           [("contextualizes", "measure", "kpi")])
    ]

collectiveAdditionalPropertyDraft :: Draft.ProfileDraft
collectiveAdditionalPropertyDraft =
  collectiveMutationDraft
    [ property "claim-type" "o2i.type" "CollectiveStrategyRealization"
    , property "claim-commitment" "o2i.commitment" "asserted"
    , property "claim-completeness" "o2i.participant-completeness" "closed"
    , property "claim-source" "o2i.source" "source-document"
    ]
    []

collectiveSegmentMetadataDraft :: Draft.ProfileDraft
collectiveSegmentMetadataDraft =
  collectiveMutationDraft
    [ property "claim-type" "o2i.type" "CollectiveStrategyRealization"
    , property "claim-commitment" "o2i.commitment" "asserted"
    , property "claim-completeness" "o2i.participant-completeness" "closed"
    ]
    [property "segment-commitment" "o2i.commitment" "asserted"]

collectiveMutationDraft ::
     [Draft.DraftMember Draft.ElementRole]
  -> [Draft.DraftMember Draft.RelationshipRole]
  -> Draft.ProfileDraft
collectiveMutationDraft claimMembers segmentMembers =
  modelDraft
    [ Draft.childRecordMember
        (typedElement "participant" "Grouping" "Strategy" "asserted")
    , Draft.childRecordMember (element "claim" "AndJunction" claimMembers)
    , Draft.childRecordMember
        (relationship
           "segment"
           "RealizationRelationship"
           False
           "realizes"
           "participant"
           "claim"
           segmentMembers)
    , Draft.childRecordMember
        (simpleView "collective-view" "Collective" ["claim"])
    ]

influenceStrengthDraft :: Text -> Draft.ProfileDraft
influenceStrengthDraft label =
  modelDraft
    [ Draft.childRecordMember
        (typedElement "source" "Grouping" "Strategy" "asserted")
    , Draft.childRecordMember
        (typedElement "target" "Grouping" "Strategy" "asserted")
    , Draft.childRecordMember
        (relationship
           "influence"
           "InfluenceRelationship"
           False
           label
           "source"
           "target"
           [ property "influence-commitment" "o2i.commitment" "asserted"
           , Draft.influenceStrengthFieldMember
               [text "strong" "influence-strength"]
               (location "influence-strength-field")
           ])
    , Draft.childRecordMember
        (connectedView
           "influence-view"
           "Influence"
           ["source", "target"]
           [("influence", "source", "target")])
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

relationshipCoordinates :: Draft.RelationshipDraft -> Maybe (Text, Text, Text)
relationshipCoordinates relation =
  (,,)
    <$> singleIdentity (Draft.draftRecordIdentity relation)
    <*> referenceIdentity "source" relation
    <*> referenceIdentity "target" relation

referenceIdentity :: Text -> Draft.RelationshipDraft -> Maybe Text
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
                  then maybe
                         []
                         pure
                         (singleIdentity
                            (Draft.draftReferenceIdentity reference))
                  else [])
             (const [])
             (const [])
             member
       ] of
    [target] -> Just target
    _ -> Nothing

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
  propertyScalars identifier key [text value (identifier <> "-value")]

propertyScalars ::
     Text -> Text -> [Draft.DraftScalar] -> Draft.DraftMember ownerRole
propertyScalars identifier key values =
  Draft.propertyMember
    (Draft.draftProperty
       (Draft.directPropertyKey [text key (identifier <> "-key")])
       values
       (location identifier)
       [])

propertyDefinition :: Text -> Text -> Draft.PropertyDefinitionDraft
propertyDefinition identifier key =
  Draft.propertyDefinitionDraft
    (identity identifier)
    (location identifier)
    [ Draft.nameFieldMember
        [text key (identifier <> "-name")]
        (location (identifier <> "-name-field"))
    ]

propertyByDefinition :: Text -> Text -> Text -> Draft.DraftMember ownerRole
propertyByDefinition identifier definition value =
  Draft.propertyMember
    (Draft.draftProperty
       (Draft.propertyDefinitionKey
          (Draft.propertyDefinitionReference
             (identity definition)
             (location (identifier <> "-definition"))))
       [text value (identifier <> "-value")]
       (location identifier)
       [])

identity :: Text -> Draft.DraftIdentity recordRole
identity value = Draft.draftIdentity [text value (value <> "-identity")]

singleIdentity :: Draft.DraftIdentity recordRole -> Maybe Text
singleIdentity identityEvidence =
  case Draft.foldDraftIdentity (map Draft.draftScalarText) identityEvidence of
    [value] -> Just value
    _ -> Nothing

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
