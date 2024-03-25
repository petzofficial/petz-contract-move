module petz_user::user {
    use std::error;
    use std::signer;
    use aptos_framework::account;
    use aptos_std::table::{Self, Table};
    use aptos_std::event::{Self, EventHandle};
    use aptos_std::timestamp;
    use aptos_std::option::{Self, Option}; // Import the Option type
    use std::string::String;

    /// Error codes
    const EUSER_NOT_FOUND: u64 = 0;
    const EUSER_ALREADY_EXISTS: u64 = 1;
    const EENERGY_ALREADY_CLAIMED: u64 = 2;
    const EREFERRED_BY_SOMEONE_ELSE: u64 = 3;

    /// User profile struct
    struct UserProfile has key, copy, store {
        name: String,
        email: String,
        username: String,
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

    /// User experience struct
    struct UserExperience has key {
        experience: u64,
        level: u64,
    }

    /// NFT struct
    struct NFT has copy, drop, store {
        collection_id: u64,
        token_id: u64,
    }

    /// NFT collection struct
    struct NFTCollection has key {
        selected_nft: Option<NFT>,
    }

    /// Referral reward struct
    struct ReferralReward has key {
        referrer: Option<address>,
        referrals: Table<address, bool>,
        energy_reward: u64,
        experience_reward: u64,
        pgc_reward: u64,
        psc_reward: u64
    }

    /// Sign up for user data struct
    public entry fun signup(account: &signer, name: String, email: String, username: String) {
        let account_addr = signer::address_of(account);
        assert!(!exists<UserData>(account_addr), error::already_exists(EUSER_ALREADY_EXISTS));

        let profile = UserProfile {
            name,
            email,
            username,
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

        move_to(account, UserExperience {
            experience: 0,
            level: 1,
        });

        move_to(account, ReferralReward {
            referrer: option::none(),
            referrals: table::new(),
            energy_reward: 0,
            experience_reward: 0,
            pgc_reward: 0,
            psc_reward: 0
        });
    }

    /// Update user profile
    public entry fun update_profile(account: &signer, name: String, email: String, username: String) acquires UserData {
        let account_addr = signer::address_of(account);
        assert!(exists<UserData>(account_addr), error::not_found(EUSER_NOT_FOUND));

        let user_data = borrow_global_mut<UserData>(account_addr);
        user_data.profile.name = name;
        user_data.profile.email = email;
        user_data.profile.username = username;
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

    /// Select an NFT
    public entry fun select_nft(account: &signer, collection_id: u64, token_id: u64) acquires NFTCollection {
        let account_addr = signer::address_of(account);
        if (!exists<NFTCollection>(account_addr)) {
            move_to(account, NFTCollection { selected_nft: option::none() });
        };

        let nft_collection = borrow_global_mut<NFTCollection>(account_addr);
        let nft = NFT { collection_id, token_id };
        nft_collection.selected_nft = option::some(nft);
    }

    #[view]
    public fun get_selected_nft(account_addr: address): Option<NFT> acquires NFTCollection {
        assert!(exists<NFTCollection>(account_addr), error::not_found(EUSER_NOT_FOUND));
        borrow_global<NFTCollection>(account_addr).selected_nft
    }

    /// Gain experience
    public entry fun gain_experience(account: &signer, experience_points: u64) acquires UserExperience {
        let account_addr = signer::address_of(account);
        assert!(exists<UserExperience>(account_addr), error::not_found(EUSER_NOT_FOUND));

        let user_experience = borrow_global_mut<UserExperience>(account_addr);
        user_experience.experience = user_experience.experience + experience_points;

        // Check if the user has leveled up
        let new_level = user_experience.level;
        while (user_experience.experience >= 100 * new_level) {
            user_experience.experience = user_experience.experience - (100 * new_level);
            new_level = new_level + 1;
        };
        user_experience.level = new_level;
    }

    #[view]
    public fun get_user_experience(account_addr: address): (u64, u64) acquires UserExperience {
        assert!(exists<UserExperience>(account_addr), error::not_found(EUSER_NOT_FOUND));
        let user_experience = borrow_global<UserExperience>(account_addr);
        (user_experience.experience, user_experience.level)
    }

    /// Set referrer
    public entry fun set_referrer(account: &signer, referrer_addr: address) acquires ReferralReward {
        let account_addr = signer::address_of(account);
        assert!(exists<ReferralReward>(account_addr), error::not_found(EUSER_NOT_FOUND));

        let referral_reward = borrow_global_mut<ReferralReward>(account_addr);
        referral_reward.referrer = option::some(referrer_addr);
    }

    /// Refer a new user
    public entry fun refer_user(account: &signer, new_user_addr: address) acquires ReferralReward, Energy, UserExperience {
        let account_addr = signer::address_of(account);
        assert!(exists<ReferralReward>(account_addr), error::not_found(EUSER_NOT_FOUND));

        let referral_reward = borrow_global_mut<ReferralReward>(account_addr);
        assert!(option::is_none(&referral_reward.referrer), error::invalid_state(EREFERRED_BY_SOMEONE_ELSE));

        table::add(&mut referral_reward.referrals, new_user_addr, true);

        // Award energy and experience rewards
        let energy = borrow_global_mut<Energy>(account_addr);
        energy.energy = energy.energy + referral_reward.energy_reward;

        let user_experience = borrow_global_mut<UserExperience>(account_addr);
        gain_experience(account, referral_reward.experience_reward);
    }

    #[view]
    public fun get_referrer(account_addr: address): Option<address> acquires ReferralReward {
        assert!(exists<ReferralReward>(account_addr), error::not_found(EUSER_NOT_FOUND));
        borrow_global<ReferralReward>(account_addr).referrer
    }

}