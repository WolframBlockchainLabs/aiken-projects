// using only primitive datatypes
pub type ChoiceId {
  ChoiceId(ByteArray, Data)
}

pub type InputContent {
  IChoice(ChoiceId, Data)
}

pub type MarloweInput {
  NormalInput(InputContent)
  MerkleizedInput(InputContent, Data, Data)
}

pub type ExpectedRedeemerStructure =
  List<MarloweInput>
