module thl_coin::thl_coin {
    use std::string;
    use std::signer;
    use std::option;

    use aptos_framework::coin::{Self, Coin, BurnCapability, FreezeCapability, MintCapability};

    use thl_coin::package;
    use thala_manager::manager;
    
    const ERR_UNAUTHORIZED: u64 = 0;
    const ERR_PACKAGE_UNINITIALIZED: u64 = 1;
    const ERR_MANAGER_UNINITIALIZED: u64 = 2;
    const ERR_EXCEED_MAX_SUPPLY: u64 = 3;

    const MAX_SUPPLY: u128 = 10000000000000000; // 100 million THL

    /// Fee manager can burn THL coins
    const FEE_MANAGER_ROLE: vector<u8> = b"fee_manager";

    // THL coin type
    struct THL {}

    struct Capabilities has key {
        burn_capability: BurnCapability<THL>,
        freeze_capability: FreezeCapability<THL>,
        mint_capability: MintCapability<THL>,
    }

    public entry fun initialize(deployer: &signer) {
        assert!(signer::address_of(deployer) == @thl_coin_deployer, ERR_UNAUTHORIZED);

        // Key dependencies
        assert!(package::initialized(), ERR_PACKAGE_UNINITIALIZED);
        assert!(manager::initialized(), ERR_MANAGER_UNINITIALIZED);

        let resource_account_signer = package::resource_account_signer();
        let (burn_capability, freeze_capability, mint_capability) = coin::initialize<THL>(
            &resource_account_signer,
            string::utf8(b"Thala Token"),
            string::utf8(b"THL"),
            8,
            true,
        );

        move_to(&resource_account_signer, Capabilities { burn_capability, freeze_capability, mint_capability });
    }

    public entry fun register(account: &signer) {
        coin::register<THL>(account);
    }

    public entry fun mint(manager: &signer, recipient: address, amount: u64) acquires Capabilities {
        assert!(manager::is_authorized(manager), ERR_UNAUTHORIZED);
        let coin = mint_internal(amount);
        coin::deposit(recipient, coin);
    }

    public fun burn(manager: &signer, coin: Coin<THL>) acquires Capabilities {
        assert!(manager::is_authorized(manager) || manager::is_role_member(signer::address_of(manager), FEE_MANAGER_ROLE), ERR_UNAUTHORIZED);
        let cap = borrow_global<Capabilities>(package::resource_account_address());
        coin::burn(coin, &cap.burn_capability)
    }

    public fun initialized(): bool {
        exists<Capabilities>(package::resource_account_address())
    }

    // Internal

    fun mint_internal(amount: u64): Coin<THL> acquires Capabilities {
        assert!(*option::borrow(&coin::supply<THL>()) + (amount as u128) <= MAX_SUPPLY, ERR_EXCEED_MAX_SUPPLY);
        let cap = borrow_global<Capabilities>(package::resource_account_address());
        coin::mint(amount, &cap.mint_capability)
    }

    #[test_only] /// Mint coins for testing purpose, without checking the supply limit
    public fun mint_for_test(manager: &signer, recipient: address, amount: u64) acquires Capabilities {
        assert!(manager::is_authorized(manager), ERR_UNAUTHORIZED);
        let cap = borrow_global<Capabilities>(package::resource_account_address());
        coin::deposit(recipient, coin::mint(amount, &cap.mint_capability));
    }

    #[test_only]
    public fun initialize_for_test() {
        package::init_for_test();

        let deployer = aptos_framework::account::create_signer_for_test(@thl_coin_deployer);
        initialize(&deployer);
    }
}
