import { HexString,AptosClient, AptosAccount, FaucetClient,TxnBuilderTypes,BCS} from "aptos";
const {
  AccountAddress,
  TypeTagStruct,
  EntryFunction,
  StructTag,
  TransactionPayloadEntryFunction,
  RawTransaction,
  ChainId,
} = TxnBuilderTypes;


const NODE_URL = "https://fullnode.testnet.aptoslabs.com/v1";
const FAUCET_URL = "https://faucet.devnet.aptoslabs.com";

const client = new AptosClient(NODE_URL);
const faucetClient = new FaucetClient(NODE_URL, FAUCET_URL);
var enc = new TextEncoder(); 

// This private key is only for test purpose do not use this in mainnet
const alice = new AptosAccount(HexString.ensure("0x1111111111111111111111111111111111111111111111111111111111111111").toUint8Array());
;
// This private key is only for test purpose do not use this in mainnet
const bob = new AptosAccount(HexString.ensure("0x2111111111111111111111111111111111111111111111111111111111111111").toUint8Array());

console.log("Alice Address: "+alice.address())
console.log("Bob Address: "+bob.address())

const pid ="0x511f963111905e2ae9cf79b00a9b9fa237dc6962e87018af3023615d7853d8fd"

function makeid(length) {
  var result           = '';
  var characters       = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxy';
  var charactersLength = characters.length;
  for ( var i = 0; i < length; i++ ) {
      result += characters.charAt(Math.floor(Math.random() * charactersLength));
  }
  return result;
}
const delay = (delayInms) => {
  return new Promise(resolve => setTimeout(resolve, delayInms));
}

describe("whitelist", () => {
  // it("Merkle Mint", async () => {
  //       const date = Math.floor(new Date().getTime() / 1000)
  //       const create_candy_machine = {
  //         type: "entry_function_payload",
  //         function: pid+"::candymachine::init_candy",
  //         type_arguments: [],
  //         arguments: [
  //           "Mokshya", // collection name
  //           "This is the description of test collection", // collection description
  //           "https://mokshya.io/nft/",  // collection 
  //           alice.address(),
  //           "1000",
  //           "42",
  //           date+10,
  //           date+15,
  //           "1",
  //           "1",
  //           "2000",
  //           [false,false,false],
  //           [false,false,false,false,false],
  //           0,
  //           false,
  //           ""+makeid(5),
  //           false
  //       ]
  //       };
  //       let txnRequest = await client.generateTransaction(alice.address(), create_candy_machine);
  //       let bcsTxn = AptosClient.generateBCSTransaction(alice, txnRequest);
  //       let transactionRes = await client.submitSignedBCSTransaction(bcsTxn);
  //       console.log("Candy Machine created: "+transactionRes.hash)
  //     })
      it("Mint", async () => {
        const mint_token = {
          type: "entry_function_payload",
          function: pid+"::candymachine::mint_script",
          type_arguments: [],
          arguments: [
            "0x1ef083efe4fe41a088aa2da78ddd9f953850bd4d9a2590fa0b5b33b048634eab"
        ]
        };
        let txnRequest = await client.generateTransaction(bob.address(), mint_token);
        let bcsTxn = AptosClient.generateBCSTransaction(bob, txnRequest);
        let transactionRes = await client.submitSignedBCSTransaction(bcsTxn);
        console.log("Token Minted "+transactionRes.hash)
      })
  })