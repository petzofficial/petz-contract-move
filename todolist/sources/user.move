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


}