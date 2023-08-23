module PetzSilverCoin::petz_silver_coin {
    use aptos_framework::coin;

    struct PetzSilverCoin {}

    fun init_module(sender: &signer) {
        aptos_framework::managed_coin::initialize<PetzSilverCoin>(
            sender,
            b"PetZ Silver Coin",
            b"PSC",
            6,
            false,
        );
    }

    public entry fun register(account: &signer) {
        aptos_framework::managed_coin::register<PetzSilverCoin>(account)
    }

    public entry fun mint(account: &signer, dst_addr: address, amount: u64) {
        aptos_framework::managed_coin::mint<PetzSilverCoin>(account, dst_addr, amount);
    }

    public entry fun burn(account: &signer, amount: u64) {
        aptos_framework::managed_coin::burn<PetzSilverCoin>(account, amount);
    }

    public entry fun transfer(from: &signer, to: address, amount: u64,) {
        coin::transfer<PetzSilverCoin>(from, to, amount);
    }
}
