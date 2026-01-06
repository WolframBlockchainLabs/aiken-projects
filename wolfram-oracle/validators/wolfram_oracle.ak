use cardano/address.{Credential}
use cardano/assets.{PolicyId}
use cardano/certificate.{Certificate}
use cardano/governance.{ProposalProcedure, Voter}
use cardano/transaction.{OutputReference, Transaction}
use marlowe.{ExpectedRedeemerStructure, Input}
use oracle.{Datum, Redeemer, Execute, Reclaim}

// Validator main structure.
validator oracle_validator {
  spend(
    datum: Option<Datum>,
    redeemer: Redeemer,
    _own_ref: transaction.OutputReference,
    ctx: transaction.Transaction,
  ) {
    when redeemer is {
      Execute -> validate_execute(datum, ctx)
      Reclaim -> validate_reclaim(datum, ctx)
    }
  }

  else(_) {
    fail
  }
}
