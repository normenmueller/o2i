module SupplementalInputEvidenceConstruction where

import O2I.Semantics.Input

forgeInvalidUtf8 :: SupplementalInvalidUtf8Evidence
forgeInvalidUtf8 = SupplementalInvalidUtf8Evidence undefined

forgeInvalidJson :: SupplementalInvalidJsonSyntaxEvidence
forgeInvalidJson = SupplementalInvalidJsonSyntaxEvidence undefined

forgeDuplicate :: SupplementalDuplicateObjectMemberEvidence
forgeDuplicate = SupplementalDuplicateObjectMemberEvidence undefined undefined

forgeTopLevel :: SupplementalTopLevelObjectRequiredEvidence
forgeTopLevel =
  SupplementalTopLevelObjectRequiredEvidence undefined undefined undefined

forgeTypeMember :: SupplementalTypeMemberInvalidEvidence
forgeTypeMember =
  SupplementalTypeMemberInvalidEvidence undefined undefined undefined

forgePayloadType :: SupplementalPayloadTypeNotAdmittedEvidence
forgePayloadType =
  SupplementalPayloadTypeNotAdmittedEvidence undefined undefined undefined

forgeRequiredMember :: SupplementalRequiredMemberMissingEvidence
forgeRequiredMember =
  SupplementalRequiredMemberMissingEvidence undefined undefined undefined

forgeUnknownMember :: SupplementalUnknownMemberEvidence
forgeUnknownMember =
  SupplementalUnknownMemberEvidence undefined undefined undefined

forgeValueKind :: SupplementalValueKindInvalidEvidence
forgeValueKind =
  SupplementalValueKindInvalidEvidence undefined undefined undefined

forgeScalarGrammar :: SupplementalScalarGrammarInvalidEvidence
forgeScalarGrammar =
  SupplementalScalarGrammarInvalidEvidence undefined undefined undefined

forgeArrayCardinality :: SupplementalArrayCardinalityInvalidEvidence
forgeArrayCardinality =
  SupplementalArrayCardinalityInvalidEvidence undefined undefined undefined

forgeArrayDistinctness :: SupplementalArrayDistinctnessInvalidEvidence
forgeArrayDistinctness =
  SupplementalArrayDistinctnessInvalidEvidence undefined undefined undefined

forgeSubjectCardinality :: SupplementalSubjectCardinalityInvalidEvidence
forgeSubjectCardinality =
  SupplementalSubjectCardinalityInvalidEvidence
    undefined
    undefined
    undefined
    undefined

forgeIdentityUnknown :: SupplementalIdentityUnknownEvidence
forgeIdentityUnknown =
  SupplementalIdentityUnknownEvidence undefined undefined undefined

forgeIdentityAmbiguous :: SupplementalIdentityAmbiguousEvidence
forgeIdentityAmbiguous =
  SupplementalIdentityAmbiguousEvidence undefined undefined undefined

forgeIdentityWrongType :: SupplementalIdentityWrongTypeEvidence
forgeIdentityWrongType =
  SupplementalIdentityWrongTypeEvidence undefined undefined undefined

forgeIdentityOutOfView :: SupplementalIdentityOutOfSelectedViewEvidence
forgeIdentityOutOfView =
  SupplementalIdentityOutOfSelectedViewEvidence undefined undefined undefined

forgeUnicodeScalar :: SupplementalModelIdentityUnicodeScalarInvalidEvidence
forgeUnicodeScalar =
  SupplementalModelIdentityUnicodeScalarInvalidEvidence
    undefined
    undefined
    undefined
    undefined

forgeNul :: SupplementalModelIdentityContainsNulEvidence
forgeNul =
  SupplementalModelIdentityContainsNulEvidence
    undefined
    undefined
    undefined
    undefined
