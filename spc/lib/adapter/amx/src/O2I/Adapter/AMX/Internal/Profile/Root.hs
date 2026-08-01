{-# LANGUAGE OverloadedStrings #-}

-- | Execution of the direct AMX model-root profile contract.
module O2I.Adapter.AMX.Internal.Profile.Root
  ( projectRootProfile
  ) where

import Data.List.NonEmpty (NonEmpty((:|)))
import Data.Text (Text)
import O2I.Adapter.AMX.Internal.Defect
import O2I.Adapter.AMX.Internal.Profile.Property
import O2I.Adapter.AMX.Internal.Types
import O2I.ArchiMate.Profile
import O2I.Inspection.Cardinality
import O2I.Inspection.Profile
import O2I.Inspection.Provenance

-- | Execute the complete typed policy for direct model-root O2I metadata.
projectRootProfile ::
     AMXDocument
  -> ( RootProjection SourcePosition AMXProfileDefect
     , [DeferredProfileDefect SourcePosition AMXProfileDefect])
projectRootProfile document = (root, legacyDefects)
  where
    model = amxDocumentRoot document
    metadata = contractMetadata profileContract
    profileKey = modelProfileKey metadata
    expectedVersion =
      profileVersionText (contractProfileVersion profileContract)
    profileProperties = directProperties profileKey model
    profileValues = map (propertyValue . fst) profileProperties
    observed = observedProfile profileValues
    rootDefects =
      cardinalityDefects
        model
        profileKey
        (modelProfileCardinality metadata)
        profileProperties
        ++ versionDefects profileKey expectedVersion profileProperties
        ++ additionalPropertyDefects
             model
             profileKey
             (modelAdditionalO2IProperties metadata)
    root =
      case nonEmpty rootDefects of
        Just defects -> RootUnprojectable observed defects
        Nothing ->
          RootProjectable
            observed
            (resolveProfileVersion (contractProfileVersion profileContract))
    legacyDefects =
      [ DeferredProfileDefect
        { defectApplicability = GlobalProfileDefect
        , deferredDefect =
            Located
              (propertyLocation "version" property)
              (LegacyRootVersionProperty (propertyValue property))
        }
      | (property, _) <- directProperties "version" model
      ]

observedProfile :: [Text] -> ObservedO2IProfile
observedProfile values =
  case values of
    [] -> NoO2IProfile
    [value] -> OneO2IProfile value
    first:second:rest -> MultipleO2IProfiles (atLeastTwo first second rest)

cardinalityDefects ::
     AMXElement
  -> Text
  -> Cardinality
  -> [(AMXElement, Text)]
  -> [Located SourcePosition AMXProfileDefect]
cardinalityDefects model profileKey cardinality properties
  | cardinalityAccepts cardinality (length properties) = []
  | otherwise =
    case properties of
      [] -> [Located (amxElementLocation model) MissingO2IProfile]
      first:rest ->
        [ Located
            (propertyLocation profileKey (fst first))
            (DuplicateO2IProfile
               (propertyValue (fst first) :| map (propertyValue . fst) rest))
        ]

versionDefects ::
     Text
  -> Text
  -> [(AMXElement, Text)]
  -> [Located SourcePosition AMXProfileDefect]
versionDefects profileKey expectedVersion properties =
  [ Located
    (propertyLocation profileKey property)
    (UnsupportedO2IProfile (propertyValue property))
  | (property, _) <- properties
  , propertyValue property /= expectedVersion
  ]

additionalPropertyDefects ::
     AMXElement
  -> Text
  -> Requirement
  -> [Located SourcePosition AMXProfileDefect]
additionalPropertyDefects model profileKey requirement
  | requirementIsForbidden requirement =
    [ Located (propertyLocation key property) (UnsupportedO2IRootProperty key)
    | (property, key, _) <- o2iProperties model
    , key /= profileKey
    ]
  | otherwise = []

nonEmpty :: [value] -> Maybe (NonEmpty value)
nonEmpty values =
  case values of
    [] -> Nothing
    first:rest -> Just (first :| rest)
