{-# LANGUAGE OverloadedStrings #-}

module O2I.ArchiMate.Profile.Internal.Fixture
  ( graphDraftWithUnrelatedElements
  , graphDraftWithSelfLoop
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import qualified O2I.ArchiMate.Profile.Draft as Draft

graphDraftWithUnrelatedElements :: Int -> Draft.ProfileDraft
graphDraftWithUnrelatedElements noiseCount =
  modelDraft
    (Draft.childRecordMember strategy
       : map (Draft.childRecordMember . unrelatedElement) [1 .. noiseCount]
       ++ [Draft.childRecordMember scopeView])
  where
    strategy =
      element
        "strategy"
        "Grouping"
        [ property "strategy-type" "o2i.type" "Strategy"
        , property "strategy-commitment" "o2i.commitment" "asserted"
        ]
    unrelatedElement ordinal =
      element ("noise-" <> Text.pack (show ordinal)) "Grouping" []
    scopeView = simpleView "main-view" "strategy"

graphDraftWithSelfLoop :: Draft.ProfileDraft
graphDraftWithSelfLoop =
  modelDraft
    [ Draft.childRecordMember strategy
    , Draft.childRecordMember selfLoop
    , Draft.childRecordMember scopeView
    ]
  where
    strategy = element "strategy" "Grouping" []
    selfLoop =
      relationship
        "self-loop"
        "AssociationRelationship"
        True
        "relates-to"
        "strategy"
        "strategy"
    scopeView = simpleView "main-view" "strategy"

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
element identifier archiMateType members =
  Draft.elementDraft
    (identity identifier)
    (location identifier)
    (Draft.typeFieldMember
       [text archiMateType (identifier <> "-type-field")]
       (location (identifier <> "-type-field"))
       : members)

relationship ::
     Text -> Text -> Bool -> Text -> Text -> Text -> Draft.RelationshipDraft
relationship identifier archiMateType directed label source target =
  Draft.relationshipDraft
    (identity identifier)
    (location identifier)
    [ Draft.typeFieldMember
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

simpleView :: Text -> Text -> Draft.ViewDraft
simpleView identifier target =
  Draft.viewDraft
    (identity identifier)
    (location identifier)
    [ Draft.nameFieldMember
        [text "Main" (identifier <> "-name")]
        (location (identifier <> "-name"))
    , Draft.childRecordMember
        (Draft.viewNodeDraft
           (identity (target <> "-node"))
           (location (target <> "-node"))
           [ Draft.referenceMember
               (Draft.viewNodeElementReference
                  (identity target)
                  (location (target <> "-node-element")))
           ])
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

text :: Text -> Text -> Draft.DraftScalar
text value source = Draft.draftTextScalar value (location source)

location :: Text -> Draft.DraftLocation
location subject =
  Draft.draftLocation
    (Draft.draftSourcePath
       (Draft.draftPathStep (Draft.draftNativeName Nothing subject) 0)
       [])
    Nothing
