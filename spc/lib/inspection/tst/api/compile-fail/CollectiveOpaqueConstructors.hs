module CollectiveOpaqueConstructors where

import qualified O2I.Inspection.Import as Import
import qualified O2I.Inspection.Report as Report

forgedImportedCollectiveClaim :: Import.ImportedCollectiveClaim
forgedImportedCollectiveClaim =
  Import.ImportedCollectiveClaim undefined undefined undefined

forgedSemanticAssessment :: Report.InspectionSemanticAssessment
forgedSemanticAssessment =
  Report.InspectionSemanticAssessment undefined undefined
