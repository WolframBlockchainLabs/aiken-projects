use aiken/crypto.{VerificationKeyHash}
use cardano/transaction.{TransactionId}

pub type Datum {
  marloweTxId: TransactionId,
  // So far, I'm using the previous definition of the datum.
  marloweTxIdx: Int,
  choiceName: ByteArray,
  dataTag: ByteArray,
  deadline: Int,
  // PosixTime not available in aiken. For time checks it uses Int
  beneficiary: VerificationKeyHash,
}

pub type Redeemer {
  Execute
  Reclaim
}
