module PetZGoldCoin::petz_gold_coin {
    use aptos_framework::coin;
    use std::option;
    use std::signer;
    use aptos_framework::coin::{BurnCapability};
    use std::string::utf8;
    use aptos_std::math64;

    struct PetZGoldCoin {}


    const OWNER:address = @PetZGoldCoin;
    const TOTAL_COINS: u64 = 100000000;

    const INVALID_OWNER:u64 = 1;

    struct BurnCap<phantom CoinType> has key {
        burn_cap:BurnCapability<CoinType>
    }


    fun init_module(sender: &signer) {

        let sender_address = signer::address_of(sender);
        let (burn_cap, freeze_cap, mint_cap) =  coin::initialize<PetZGoldCoin>(
            sender,
            utf8(b"PetZ Gold Coin"),
            utf8(b"PGC"),
            8,
            true,
        );

        if(!coin::is_account_registered<PetZGoldCoin>(sender_address)){
          coin::register<PetZGoldCoin>(sender);
        };

        move_to(sender,BurnCap{
            burn_cap
        });

        let _total_amount_mint = TOTAL_COINS * math64::pow(10,8);
        let supply = coin::supply<PetZGoldCoin>();
        assert!(option::is_some(&supply), 1);
        let coins =  coin::mint(_total_amount_mint,&mint_cap);
        coin::deposit(sender_address,coins);
        coin::destroy_mint_cap(mint_cap);
        coin::destroy_freeze_cap(freeze_cap);
    }

    public entry fun burn_coin(sender:&signer, amount:u64) acquires BurnCap {
        let sender_address = signer::address_of(sender);
        assert!(sender_address == OWNER, INVALID_OWNER);
        let amount_burn = amount * math64::pow(10,8);
        let burn_cap = borrow_global_mut<BurnCap<PetZGoldCoin>>(sender_address);
        let coins = coin::withdraw<PetZGoldCoin>(sender,amount_burn);
        coin::burn(coins,&burn_cap.burn_cap);
    }

}
