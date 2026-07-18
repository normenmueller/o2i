{-# LANGUAGE TemplateHaskell #-}

-- | External-client opacity contracts for Inspection artifacts.
module Main
  ( main
  ) where

import ApiContractTH (assertAbstractTypes)
import qualified O2I.Inspection.Import as Import
import qualified O2I.Inspection.Input as Input
import qualified O2I.Inspection.Pipeline as Pipeline
import qualified O2I.Inspection.Profile as Profile
import qualified O2I.Inspection.Provenance as Provenance
import qualified O2I.Inspection.Report as Report
import qualified O2I.Inspection.Scope as Scope

$(assertAbstractTypes
    [ "Import.ImportedGraph"
    , "Input.SourceDocument"
    , "Pipeline.StructurallyClosedModel"
    , "Pipeline.SemanticsWitness"
    , "Profile.IndexedProfileFact"
    , "Profile.ResolvedProfileProjection"
    , "Profile.ProfileIndex"
    , "Provenance.Provenance"
    , "Report.StageReports"
    , "Report.InspectionReport"
    , "Scope.SemanticallyClosedScope"
    ])

main :: IO ()
main = pure ()
