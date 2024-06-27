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
    const EUSERNAME_ALREADY_EXISTS: u64 = 4;
    const EEMAIL_ALREADY_EXISTS: u64 = 5;

    struct UserRegistry has key {
        usernames: Table<String, address>,
        emails: Table<String, address>,
    }

    /// User profile struct
    struct UserProfile has key, copy, store {
        name: String,
        email: String,
        username: String,
        phone: String,
        birthday: String,
        gender: String,
        bio: String,
        user_addr: String,
        social: String,
        location: String,
        created_at: u64,
        profile_image_url: String,
   //     invitation_code: Option<String>,
    }


    /// Login history entry
    struct LoginHistory has copy, drop, store {
        timestamp: u64,
        ip_address: vector<u8>,
        device: String
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
        collection_id: address,
        token_id: address,
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

    /// Initialize user resources
    public entry fun initialize_user(account: &signer) {
        let account_addr = signer::address_of(account);

        if (!exists<Energy>(account_addr)) {
            move_to(account, Energy {
                energy: 100,
                last_claimed: timestamp::now_seconds(),
            });
        };

        if (!exists<UserExperience>(account_addr)) {
            move_to(account, UserExperience {
                experience: 0,
                level: 1,
            });
        };

        if (!exists<ReferralReward>(account_addr)) {
            move_to(account, ReferralReward {
                referrer: option::none(),
                referrals: table::new(),
                energy_reward: 0,
                experience_reward: 0,
                pgc_reward: 0,
                psc_reward: 0
            });
        };
    }

    /// Sign up for user data struct
    public entry fun create_profile(account: &signer, 
        name: String, 
        email: String, 
        username: String,
        phone: String,
        birthday: String,
        gender: String,
        bio: String,
        user_addr: String,
        social: String,
        location: String,
        profile_image_url: String) acquires UserRegistry {
        let account_addr = signer::address_of(account);

        // Check if UserRegistry exists, if not, create it
        if (!exists<UserRegistry>(@petz_user)) {
            move_to(account, UserRegistry {
                usernames: table::new(),
                emails: table::new(),
            });
        };

        let user_registry = borrow_global_mut<UserRegistry>(@petz_user);
        
        // Check if the username or email already exists
        assert!(is_username_available(user_registry,username), error::already_exists(EUSERNAME_ALREADY_EXISTS));
        assert!(is_email_available(user_registry,email), error::already_exists(EEMAIL_ALREADY_EXISTS));
        
        // Add the new username and email to the registry
        table::add(&mut user_registry.usernames, username, account_addr);
        table::add(&mut user_registry.emails, email, account_addr);

        assert!(!exists<UserData>(account_addr), error::already_exists(EUSER_ALREADY_EXISTS));

        let profile = UserProfile {
            name,
            email,
            username,
            phone,
            birthday,
            gender,
            bio,
            user_addr,
            social,
            location,
            created_at: timestamp::now_seconds(),
            profile_image_url,
        };

        move_to(account, UserData {
            profile,
            login_history: table::new(),
            login_history_events: account::new_event_handle<LoginHistory>(account),
        });

        // Initialize user resources
        //initialize_user(account);
    }

    /// Update user profile
    public entry fun update_profile(
        account: &signer, 
        name: String, 
        email: String, 
        username: String,
        phone: String,
        birthday: String,
        gender: String,
        bio: String,
        user_addr: String,
        social: String,
        location: String,
		profile_image_url: String) acquires UserData, UserRegistry {
        let account_addr = signer::address_of(account);
        assert!(exists<UserData>(account_addr), error::not_found(EUSER_NOT_FOUND));

        let user_data = borrow_global_mut<UserData>(account_addr);
        let old_username = user_data.profile.username;
        let old_email = user_data.profile.email;
        
        let user_registry = borrow_global_mut<UserRegistry>(@petz_user);
        
        // Check and update username if changed
        if (old_username != username) {
            assert!(is_username_available(user_registry,username), error::already_exists(EUSERNAME_ALREADY_EXISTS));
            table::remove(&mut user_registry.usernames, old_username);
            table::add(&mut user_registry.usernames, username, account_addr);
        };

        // Check and update email if changed
        if (old_email != email) {
            assert!(is_email_available(user_registry,email), error::already_exists(EEMAIL_ALREADY_EXISTS));
            table::remove(&mut user_registry.emails, old_email);
            table::add(&mut user_registry.emails, email, account_addr);
        };

        user_data.profile.name = name;
        user_data.profile.email = email;
        user_data.profile.username = username;
        user_data.profile.phone = phone;
        user_data.profile.birthday = birthday;
        user_data.profile.gender = gender;
        user_data.profile.bio = bio;
        user_data.profile.user_addr = user_addr;
        user_data.profile.social = social;
        user_data.profile.location = location;
		user_data.profile.profile_image_url = profile_image_url;
    }

    /// Record login history
    public entry fun record_login(account: &signer, ip_address: vector<u8>, device: String) acquires UserData {
        let account_addr = signer::address_of(account);
        assert!(exists<UserData>(account_addr), error::not_found(EUSER_NOT_FOUND));

        let user_data = borrow_global_mut<UserData>(account_addr);
        let timestamp = timestamp::now_seconds();
        let login_history_entry = LoginHistory { timestamp, ip_address, device };

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
        
        // Initialize user resources if they don't exist
        if (!exists<Energy>(account_addr)) {
            initialize_user(account);
        };

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
    public entry fun select_nft(account: &signer, collection_id: address, token_id: address) acquires NFTCollection {
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
        
        // Initialize user resources if they don't exist
        if (!exists<UserExperience>(account_addr)) {
            initialize_user(account);
        };

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

    /// Earn PGC reward via referral link
    public entry fun claim_referral_reward(account: &signer, referrer_addr: address) acquires ReferralReward {
        let account_addr = signer::address_of(account);
        
        // Initialize user resources if they don't exist
        if (!exists<ReferralReward>(account_addr)) {
            initialize_user(account);
        };

        // Ensure the referrer exists
        assert!(exists<ReferralReward>(referrer_addr), error::not_found(EUSER_NOT_FOUND));

        {
            // Ensure the user hasn't already been referred
            let referral_reward = borrow_global_mut<ReferralReward>(account_addr);
            assert!(option::is_none(&referral_reward.referrer), error::invalid_state(EREFERRED_BY_SOMEONE_ELSE));

            // Set the referrer
            referral_reward.referrer = option::some(referrer_addr);

            // Award PGC to the new user
            referral_reward.pgc_reward = referral_reward.pgc_reward + 5; // Adjust the reward amount as needed
        };

        {
            // Add the new user to the referrer's referrals and award PGC reward
            let referrer_reward = borrow_global_mut<ReferralReward>(referrer_addr);
            table::add(&mut referrer_reward.referrals, account_addr, true);

            // Award PGC reward to the referrer
            referrer_reward.pgc_reward = referrer_reward.pgc_reward + 10; // Adjust the reward amount as needed
        };
    }

    // ... (other functions remain the same)

    #[view]
    public fun get_referral_reward(account_addr: address): u64 acquires ReferralReward {
        assert!(exists<ReferralReward>(account_addr), error::not_found(EUSER_NOT_FOUND));
        borrow_global<ReferralReward>(account_addr).pgc_reward
    }

    // Helper functions should also include the acquires annotation
    public fun is_username_available(user_registry: &UserRegistry, username: String): bool {
        !table::contains(&user_registry.usernames, username)
    }

    public fun is_email_available(user_registry: &UserRegistry, email: String): bool {
        !table::contains(&user_registry.emails, email)
    }
    
/*     #[view]
    public fun get_invitation_code(account_addr: address): Option<String> acquires UserData {
        assert!(exists<UserData>(account_addr), error::not_found(EUSER_NOT_FOUND));
        borrow_global<UserData>(account_addr).profile.invitation_code
    } */

}