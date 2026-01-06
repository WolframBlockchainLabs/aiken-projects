use aiken/collection/list.{has, any}
use aiken/crypto.{VerificationKeyHash}
use aiken/interval.{entirely_after, includes, entirely_before}
use cardano/assets.{from_lovelace}
use cardano/transaction.{Transaction, OutputReference, TransactionId, Input}

use mocktail.{
  complete, invalid_hereafter, mock_script_address, mocktail_tx, tx_in,
}
use mocktail/virgin_key_hash.{mock_pub_key_hash}
use mocktail/virgin_output_reference.{mock_tx_hash, mock_utxo_ref}

//use marlowe.{ExpectedRedeemerStructure, MarloweInput}
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
  expect Some(Datum{ marloweTxId, marloweTxIdx, deadline, ..}) = datum
  let Transaction {inputs, validity_range, ..} = ctx

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

fn make_test_datum(
  marlowe_tx_id: transaction.TransactionId,
  marlowe_tx_idx: Int,
  choice_name: ByteArray,
  data_tag: ByteArray,
  deadline: Int,
  beneficiary: VerificationKeyHash,
) -> Datum {
  Datum {
    marloweTxId: marlowe_tx_id,
    marloweTxIdx: marlowe_tx_idx,
    choiceName: choice_name,
    dataTag: data_tag,
    deadline,
    beneficiary,
  }
}

// fn oracle_datum() {
//   Datum {
//     marloweTxId: #"485001df613ed20cab1063d5280a315ac648eec7dc26ce0850b279674aa35e1d",
//     marloweTxIdx: 0,
//     choiceName: "ADA/USD",
//     dataTag: "ADA/USD",
//     deadline: 150,
//     beneficiary: #"00000000000000000000000000000000000000000000000000000000",
//   }
// }

test oracle_validator_Execute() {
  let marlowe_tx_id = mock_tx_hash(0)
  let marlowe_tx_idx = 0
  let deadline = 1000000

  // Unix timestamp
  let datum =
    make_test_datum(
      marlowe_tx_id: marlowe_tx_id,
      marlowe_tx_idx: marlowe_tx_idx,
      choice_name: "price_feed",
      data_tag: "oracle_data",
      deadline: deadline,
      beneficiary: mock_pub_key_hash(0),
    )

  let tx =
    mocktail_tx()
      // Add the Marlowe input that the validator is checking for
      |> tx_in(
          True,
          marlowe_tx_id,
          marlowe_tx_idx,
          from_lovelace(20000000),
          mock_script_address(0, None),
        )
      // Set validity range BEFORE the deadline (deadline - 1)
      |> invalid_hereafter(True, deadline - 1)
      |> complete()

  let redeemer = Execute
  let own_ref = mock_utxo_ref(1, 0)
  oracle_validator.spend(Some(datum), redeemer, own_ref, tx)
}

test oracle_validator_Reclaim() {
  let datum =
    Datum {
      marloweTxId: #"485001df613ed20cab1063d5280a315ac648eec7dc26ce0850b279674aa35e1d",
      marloweTxIdx: 0,
      choiceName: "ADA/USD",
      dataTag: "ADA/USD",
      deadline: 150,
      beneficiary: #"00000000000000000000000000000000000000000000000000000000",
    }
  let placeholder_utxo =
    transaction.OutputReference { transaction_id: "", output_index: 0 }

  let redeemer = Reclaim

  let ctx =
    transaction.Transaction {
      ..transaction.placeholder,
      // I have to construct this interval :v
      validity_range: interval.between(170, 180),
      extra_signatories: [datum.beneficiary],
    }

  oracle_validator.spend(Some(datum), redeemer, placeholder_utxo, ctx)
}