module PetzGoldCoin::petz_gold_coin {
    use aptos_framework::coin;

    struct PetzGoldCoin {}

    fun init_module(sender: &signer) {
        aptos_framework::managed_coin::initialize<PetzGoldCoin>(
            sender,
            b"PetZ Gold Coin",
            b"PGC",
            8,
            false,
        );
    }

    public entry fun register(account: &signer) {
        aptos_framework::managed_coin::register<PetzGoldCoin>(account)
    }

    public entry fun mint(account: &signer, dst_addr: address, amount: u64) {
        aptos_framework::managed_coin::mint<PetzGoldCoin>(account, dst_addr, amount);
    }

    public entry fun burn(account: &signer, amount: u64) {
        aptos_framework::managed_coin::burn<PetzGoldCoin>(account, amount);
    }

    public entry fun transfer(from: &signer, to: address, amount: u64,) {
        coin::transfer<PetzGoldCoin>(from, to, amount);
    }
}
