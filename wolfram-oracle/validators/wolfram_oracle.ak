use aiken/collection/list.{has, any}
use aiken/interval.{entirely_after, includes, entirely_before}
use cardano/transaction.{Transaction, OutputReference, TransactionId, Input}
use marlowe.{ExpectedRedeemerStructure, MarloweInput}
use oracle.{Datum, Redeemer, Execute, Reclaim}

fn check_input_presence(
  input: Input,
  datumTxId: TransactionId,
  datumTxIdx: Int,
) {
  let Input { output_reference, .. } = input
  let OutputReference { transaction_id, output_index } = output_reference

  let same_txId = datumTxId == transaction_id
  let same_txIdIxd = datumTxIdx == output_index

  same_txId? && same_txIdIxd?
}

fn validate_execute(datum: Option<Datum>, ctx: Transaction){
  // unpack datum and ctx
  expect Some(Datum{ choiceName, marloweTxId, marloweTxIdx, deadline, ..}) = datum
  let Transaction {inputs, redeemers, validity_range, ..} = ctx

  // before deadline condition
  let must_be_before_deadline = includes(entirely_before(deadline), validity_range)
  // Marlowe input exists condition
  let marlowe_utxo_present = any(inputs, fn(x){ check_input_presence(x, marloweTxId, marloweTxIdx)})

  must_be_before_deadline? && marlowe_utxo_present?
}

// Reclaim endpoint function
fn validate_reclaim(datum: Option<Datum>, ctx: Transaction) -> Bool {
  expect Some(Datum { beneficiary, deadline, .. }) = datum
  let must_be_signed = has(ctx.extra_signatories, beneficiary)
  let posix_to_infinity_interval = entirely_after(deadline)
  let must_be_after_deadline = includes(posix_to_infinity_interval, ctx.validity_range)

  must_be_signed? && must_be_after_deadline?
}

// Validator main structure.
validator oracle_validator {
  spend(
    datum: Option<Datum>,
    redeemer: Redeemer,
    _own_ref: OutputReference,
    ctx: Transaction,
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
