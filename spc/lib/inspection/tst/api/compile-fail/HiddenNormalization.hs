module HiddenNormalization where

import qualified O2I.Inspection.Diagnostic as Diagnostic
import qualified O2I.Inspection.Report as Report

fromSpec = Diagnostic.diagnosticFromSpec

fromLocated = Diagnostic.diagnosticFromLocated

fromLocatedMany = Diagnostic.diagnosticsFromLocated

withSources = Diagnostic.diagnosticWithSupplementalSources

normalize = Diagnostic.normalizeDiagnostics

normalizeBinding = Report.nativeAdapterBinding
