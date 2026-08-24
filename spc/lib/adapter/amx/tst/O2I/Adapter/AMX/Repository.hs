{-# LANGUAGE OverloadedStrings #-}

-- | Repository-level execution of the real AMX/Profile/Core boundary.
module O2I.Adapter.AMX.Repository
  ( CandidateView(..)
  , allCandidateViews
  , candidateViewName
  , validateCandidateViewCoverage
  , checkRepositoryModel
  ) where

import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Adapter.AMX (amxAdapter)
import qualified O2I.ArchiMate.Profile as ProfileContract
import O2I.ArchiMate.Profile.Draft (draftScalarText)
import qualified O2I.ArchiMate.Profile.Notation as Notation
import qualified O2I.ArchiMate.Profile.Projection as Projection
import O2I.ArchiMate.Profile.Resolution
  ( compiledProfileDescriptor
  , profileDescriptorReference
  )
import O2I.Operation.Acquisition
  ( AcquiredModelSource
  , acquireSource
  , acquiredModelSource
  , fileInput
  )
import O2I.Operation.Adapter
  ( AdapterCollection
  , adapterDescriptorId
  , adapterIdText
  , selectedAdapterDescriptor
  )
import O2I.Operation.Adapter.Authoring (compileAdapterCollection)
import O2I.Operation.Diagnostic.Owner (withModelStructureAssessment)
import O2I.Operation.Diagnostic.Owner.Source
  ( assessOwnerSemantics
  , foldSupplementalOwnerBinding
  , withAdmittedOwnerSupplementalInputs
  , withBoundAdmittedOwnerSupplementalInputs
  )
import O2I.Operation.Failure (preparationFailureCode)
import O2I.Operation.Preparation (withPreparedSelectedView)
import O2I.Operation.Profile
  ( ProfileInventory
  , compileProfileInventory
  , foldProfileInventoryCompilation
  , resolvedProfileReference
  )
import O2I.Operation.Provenance
  ( SourceRole(ModelRole)
  , mkSourceReference
  , sourceOrdinal
  )
import O2I.Operation.Request (validationRequest)
import O2I.Operation.View (SelectedView, selectedViewDescriptor, viewByName)
import qualified O2I.Semantics as Semantics
import qualified O2I.Structure as Structure

-- | The closed repository Candidate-View verification surface.
data CandidateView
  = Contextualization
  | CollectiveStrategyRealization
  | NeedQualificationProposal
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Every focused Candidate View required by the current repository model.
allCandidateViews :: NonEmpty CandidateView
allCandidateViews =
  Contextualization
    :| [CollectiveStrategyRealization, NeedQualificationProposal]

-- | Exact persisted View name selected in the native AMX model.
candidateViewName :: CandidateView -> Text
candidateViewName candidate =
  case candidate of
    Contextualization -> "O2I Syntax - Contextualization"
    CollectiveStrategyRealization ->
      "O2I Syntax - Collective Strategy Realization"
    NeedQualificationProposal -> "O2I Syntax - Need Qualification Proposal"

-- | Reject an incomplete or duplicated execution result inventory.
validateCandidateViewCoverage ::
     [CandidateView] -> Either (NonEmpty CandidateView) ()
validateCandidateViewCoverage observed =
  case NonEmpty.nonEmpty missingOrDuplicated of
    Nothing -> Right ()
    Just defects -> Left defects
  where
    required = NonEmpty.toList allCandidateViews
    missingOrDuplicated =
      [ candidate
      | candidate <- required
      , length (filter (== candidate) observed) /= 1
      ]

-- | Decode and assess every required View from one real repository model.
checkRepositoryModel :: FilePath -> IO (Either Text ())
checkRepositoryModel modelPath =
  case mkSourceReference "repository:mdl/o2i.archimate" of
    Left _ ->
      pure (Left "cannot construct the repository model source reference")
    Right sourceReference ->
      case fileInput sourceReference modelPath of
        Left _ -> pure (Left "cannot construct the repository model input")
        Right input -> do
          acquired <- acquireSource ModelRole (sourceOrdinal 0) input
          case acquired of
            Left _ -> pure (Left "cannot acquire the repository model")
            Right source ->
              case acquiredModelSource source of
                Nothing ->
                  pure (Left "repository model lost its model source role")
                Just model -> runModel model

runModel :: AcquiredModelSource -> IO (Either Text ())
runModel model =
  case amxAdapter of
    Left defects ->
      pure
        (Left
           ("static AMX adapter compilation failed with "
              <> count defects
              <> " defect(s)"))
    Right adapter ->
      case compileAdapterCollection (adapter :| []) of
        Left defects ->
          pure
            (Left
               ("static AMX adapter inventory compilation failed with "
                  <> count defects
                  <> " defect(s)"))
        Right adapters ->
          foldProfileInventoryCompilation
            (\defects ->
               pure
                 (Left
                    ("compiled Profile inventory failed with "
                       <> count defects
                       <> " defect(s)")))
            (runViews adapters model)
            (compileProfileInventory ProfileContract.compiledProfileInventory)

runViews ::
     AdapterCollection
  -> AcquiredModelSource
  -> ProfileInventory
  -> IO (Either Text ())
runViews adapters model profiles =
  pure
    (case traverse
            (checkCandidateView adapters profiles model)
            (NonEmpty.toList allCandidateViews) of
       Left failure -> Left failure
       Right checked ->
         case validateCandidateViewCoverage checked of
           Left defects ->
             Left
               ("Candidate View coverage is incomplete or duplicated: "
                  <> Text.intercalate
                       ", "
                       (map candidateViewName (NonEmpty.toList defects)))
           Right () -> Right ())

checkCandidateView ::
     AdapterCollection
  -> ProfileInventory
  -> AcquiredModelSource
  -> CandidateView
  -> Either Text CandidateView
checkCandidateView adapters profiles model candidate =
  withPreparedSelectedView
    adapters
    profiles
    Nothing
    (validationRequest (viewByName viewName) [])
    model
    (Left . viewFailure . ("preparation failed at " <>) . preparationFailureCode)
    (\authority selected resolved _ _ selectedView universe _ ->
       if adapterIdText
            (adapterDescriptorId (selectedAdapterDescriptor selected))
            /= "amx"
         then Left (viewFailure "AMX adapter was not selected")
         else if resolvedProfileReference resolved
                   /= profileDescriptorReference compiledProfileDescriptor
                then Left (viewFailure "compiled Profile binding differs")
                else if selectedViewName selectedView /= [viewName]
                       then Left (viewFailure "selected View identity differs")
                       else checkNotation authority universe)
  where
    viewName = candidateViewName candidate
    viewFailure message = viewName <> ": " <> message
    checkNotation authority universe =
      Notation.foldStageResult
        (\issues ->
           Left
             (viewFailure ("Notation rejected " <> count issues <> " issue(s)")))
        (checkProjection authority)
        (Notation.notationConformance
           (Notation.assessArchiMateNotation universe))
    checkProjection authority conformant =
      Projection.foldProfileProjectionAssessment
        (\defects ->
           Left
             (viewFailure
                ("Profile contract failed with "
                   <> count defects
                   <> " defect(s)")))
        (\defects ->
           Left
             (viewFailure
                ("Profile rejected: "
                   <> Text.intercalate
                        ", "
                        (map
                           Projection.profileDiagnosticRuleId
                           (NonEmpty.toList defects)))))
        (checkQualificationProjection authority)
        (Projection.assessSelectedView conformant)
    checkQualificationProjection authority projection =
      if length (Projection.profileQualificationProposals projection)
           /= expectedProposalCount candidate
        then Left (viewFailure "qualification proposal projection differs")
        else withAdmittedOwnerSupplementalInputs
               authority
               []
               (\defects ->
                  Left
                    (viewFailure
                       ("supplemental provenance failed with "
                          <> count defects
                          <> " defect(s)")))
               (\defects ->
                  Left
                    (viewFailure
                       ("supplemental input failed with "
                          <> count defects
                          <> " defect(s)")))
               (checkStructureProjection authority projection)
    checkStructureProjection authority projection admitted =
      withModelStructureAssessment
        authority
        projection
        (\defects ->
           Left
             (viewFailure
                ("Core identity index failed with "
                   <> count defects
                   <> " defect(s)")))
        (\defects ->
           Left
             (viewFailure
                ("Core selected-View scope failed with "
                   <> count defects
                   <> " defect(s)")))
        (\defects ->
           Left
             (viewFailure
                ("Core Structure input failed with "
                   <> count defects
                   <> " defect(s)")))
        (checkStructure admitted)
    checkStructure admitted scope assessment =
      Structure.foldStructureAssessment
        (\defects ->
           Left
             (viewFailure
                ("Core Structure rejected " <> count defects <> " defect(s)")))
        (checkSemantics scope admitted)
        assessment
    checkSemantics scope admitted graph =
      withBoundAdmittedOwnerSupplementalInputs
        scope
        graph
        admitted
        (foldSupplementalOwnerBinding $ \bound _ ->
           Semantics.foldSemanticAssessment
             (\defects ->
                Left
                  (viewFailure
                     ("Core Semantics rejected "
                        <> count defects
                        <> " defect(s)")))
             (Left (viewFailure "Core Semantics is unavailable"))
             (const (Right candidate))
             (assessOwnerSemantics graph bound))

selectedViewName :: SelectedView document -> [Text]
selectedViewName selectedView =
  concatMap
    (map draftScalarText . Notation.canonicalFieldScalars)
    (Notation.canonicalViewNameFields (selectedViewDescriptor selectedView))

expectedProposalCount :: CandidateView -> Int
expectedProposalCount candidate =
  case candidate of
    NeedQualificationProposal -> 1
    Contextualization -> 0
    CollectiveStrategyRealization -> 0

count :: NonEmpty value -> Text
count = Text.pack . show . NonEmpty.length
