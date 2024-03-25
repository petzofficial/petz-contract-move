script {
    use petz_gold_coin::petz_gold_coin;
    use std::signer;

    fun main(admin: &signer, to_addr: &signer) {
        let to_address = signer::address_of(to_addr);

        // Delegate the MintCapability to the specified address
        petz_gold_coin::delegate_capability<MintCapability<PetZGoldCoin>>(
            admin,
            to_address
        );
    }
}