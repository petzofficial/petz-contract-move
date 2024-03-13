module petz_user::user {
    use std::error;
    use std::signer;
    use aptos_framework::account;
    use aptos_std::table::{Self, Table};
    use aptos_std::event::{Self, EventHandle};
    use aptos_std::timestamp;

    /// Error codes
    const EUSER_NOT_FOUND: u64 = 0;
    const EUSER_ALREADY_EXISTS: u64 = 1;
    const EENERGY_ALREADY_CLAIMED: u64 = 2;

    /// User profile struct
    struct UserProfile has key, copy, store {
        name: vector<u8>,
        email: vector<u8>,
        created_at: u64,
    }

    /// Login history entry
    struct LoginHistory has copy, drop, store {
        timestamp: u64,
        ip_address: vector<u8>,
    }

    /// Energy struct
    struct Energy has key {
        energy: u64,
        last_claimed: u64,
    }

    /// User data struct
    struct UserData has key {
        profile: UserProfile,
        login_history: Table<u64, LoginHistory>,
        login_history_events: EventHandle<LoginHistory>,
    }

    /// Initialize user data struct
    public entry fun initialize(account: &signer) {
        let account_addr = signer::address_of(account);
        assert!(!exists<UserData>(account_addr), error::already_exists(EUSER_ALREADY_EXISTS));

        let profile = UserProfile {
            name: b"",
            email: b"",
            created_at: timestamp::now_seconds(),
        };

        move_to(account, UserData {
            profile,
            login_history: table::new(),
            login_history_events: account::new_event_handle<LoginHistory>(account),
        });

        move_to(account, Energy {
            energy: 100,
            last_claimed: timestamp::now_seconds(),
        });
    }

    /// Update user profile
    public entry fun update_profile(account: &signer, name: vector<u8>, email: vector<u8>) acquires UserData {
        let account_addr = signer::address_of(account);
        assert!(exists<UserData>(account_addr), error::not_found(EUSER_NOT_FOUND));

        let user_data = borrow_global_mut<UserData>(account_addr);
        user_data.profile.name = name;
        user_data.profile.email = email;
    }

    /// Record login history
    public entry fun record_login(account: &signer, ip_address: vector<u8>) acquires UserData {
        let account_addr = signer::address_of(account);
        assert!(exists<UserData>(account_addr), error::not_found(EUSER_NOT_FOUND));

        let user_data = borrow_global_mut<UserData>(account_addr);
        let timestamp = timestamp::now_seconds();
        let login_history_entry = LoginHistory { timestamp, ip_address };

        table::add(&mut user_data.login_history, timestamp, login_history_entry);
        event::emit_event(&mut user_data.login_history_events, login_history_entry);
    }

    #[view]
    public fun get_profile(account_addr: address): UserProfile acquires UserData {
        assert!(exists<UserData>(account_addr), error::not_found(EUSER_NOT_FOUND));
        borrow_global<UserData>(account_addr).profile
    }

    /// Claim daily energy
    public entry fun claim_energy(account: &signer) acquires Energy {
        let account_addr = signer::address_of(account);
        assert!(exists<Energy>(account_addr), error::not_found(EUSER_NOT_FOUND));

        let energy = borrow_global_mut<Energy>(account_addr);
        let current_time = timestamp::now_seconds();
        let last_claimed = energy.last_claimed;
        let one_day_seconds = 86400;

        assert!(current_time - last_claimed >= one_day_seconds, error::already_exists(EENERGY_ALREADY_CLAIMED));

        energy.energy = 100;
        energy.last_claimed = current_time;
    }

    #[view]
    public fun get_energy(account_addr: address): u64 acquires Energy {
        assert!(exists<Energy>(account_addr), error::not_found(EUSER_NOT_FOUND));
        borrow_global<Energy>(account_addr).energy
    }

    /// Reduce energy based on time spent
    public entry fun reduce_energy_by_time(account: &signer, duration_seconds: u64) acquires Energy {
        let account_addr = signer::address_of(account);
        assert!(exists<Energy>(account_addr), error::not_found(EUSER_NOT_FOUND));

        let energy = borrow_global_mut<Energy>(account_addr);
        let energy_to_reduce = duration_seconds / 60; // 1 energy per minute

        assert!(energy.energy >= energy_to_reduce, error::out_of_range(0));

        energy.energy = energy.energy - energy_to_reduce;
    }

}