module task_management::task {
    use std::error;
    use std::signer;
    use std::string::String;
    use aptos_std::table::{Self, Table};
    use aptos_framework::event;
    use aptos_framework::account;
    use aptos_framework::timestamp;
   // use task_management::petz_gold_coin;
    
    //use std::hash;
    use aptos_framework::coin::{Self, Coin, MintCapability};

    /// Error codes
    const ETASK_PRIORITY_ERROR: u64 = 0;
    const ETASK_NOT_FOUND: u64 = 1;
    const ENOT_TASK_OWNER: u64 = 2;
    /// Account does not have mint capability
    const ENOT_CAPABILITIES: u64 = 3;
    const ETASK_STATUS_ERROR: u64 = 4;

    /// Reward parameters
    const DEVELOPER_FEE_PERCENTAGE: u64 = 5; // 5%
    const REWARD_RATE_PER_SECOND: u64 = 1; // 1 coin per second spent on the task

    /// Task priority levels
    const PRIORITY_LOW: u8 = 1;
    const PRIORITY_MEDIUM: u8 = 2;
    const PRIORITY_HIGH: u8 = 3;

    /// Maximum length for task name and description
    //const MAX_TASK_NAME_LENGTH: u64 = 100;
    //const MAX_DESCRIPTION_LENGTH: u64 = 500;

    
    //struct CoinType has key {}

    struct MintCapStore <phantom CoinType > has key {
        mint_cap: MintCapability<CoinType>,
    }

    struct CapStore<CapType: store + copy> has key, store {
        cap: CapType,
    }


    /// Task struct
    struct Task has copy, drop, store {
        task_id: u64,
        task_name: String,
        description: String,
        create_date: u64, // Unix timestamp
        complete_date: u64, // Unix timestamp
        due_date: u64, // Unix timestamp
        priority: u8,
        cycle_count: u64,
        total_time_spent: u64,
        owner: address,
       // status: u8,
        fee: u64,
        pgc_reward: u64,
        psc_reward: u64
    }

    /// Task manager struct
    struct TaskManager has key {
        tasks: Table<u64, Task>,
        set_task_event: event::EventHandle<Task>,
        task_counter: u64
    }

  
    struct Pool<phantom R> has key {
        reward_coins: Coin<R>,
    }



    public entry fun add_task <CoinType> (
        account: &signer,
//        task_id: u64,
        task_name: String,
        description: String,
//        create_date: u64,
        due_date: u64,
        priority: u8,
    ) acquires TaskManager {
        let account_addr = signer::address_of(account);

        if (!exists<TaskManager>(account_addr)) {
            move_to(account, TaskManager { 
                tasks: table::new(),
                set_task_event: account::new_event_handle<Task>(account),
                task_counter: 0
            });
          
        };
        if (!coin::is_account_registered<CoinType>(account_addr)) {
                coin::register<CoinType>(account);
        };

          // coin::register<PetZSilverCoin>(account);
       
        //assert!(!table::contains(&borrow_global<TaskManager>(account_addr).tasks, task_id), error::already_exists(ETASK_ALREADY_EXISTS));
        //assert!(vector::length(&task_name) <= MAX_TASK_NAME_LENGTH, error::invalid_argument(ETASK_ALREADY_EXISTS));
        //assert!(vector::length(&description) <= MAX_DESCRIPTION_LENGTH, error::invalid_argument(ETASK_ALREADY_EXISTS));
        assert!(priority >= PRIORITY_LOW && priority <= PRIORITY_HIGH, error::invalid_argument(ETASK_PRIORITY_ERROR));
        let task_manager = borrow_global_mut<TaskManager>(account_addr);
        let counter = task_manager.task_counter + 1;
        let timestamp_seconds = timestamp::now_seconds();
        //let current_time = timestamp_seconds;
        //let timestamp_bytes = timestamp_seconds.to_le_bytes();
        let unique_id = counter;

        let new_task = Task {
            task_id: unique_id,
            task_name,
            description,
            create_date: timestamp_seconds,
            complete_date: 0,
            due_date,
            priority,
            cycle_count: 0,
            total_time_spent: 0,
            owner: account_addr,
        //    status: 0, //0 pending, 1 in-progress, 2 completed
            fee: 0,
            pgc_reward: 0,
            psc_reward: 0
        };

        task_manager.task_counter = counter;

        let task_manager_mut = borrow_global_mut<TaskManager>(account_addr);
        table::add(&mut task_manager_mut.tasks, unique_id, new_task);

        // Borrow the event handle separately
        let event_handle_mut = &mut task_manager_mut.set_task_event;
        event::emit_event<Task>(event_handle_mut, new_task);
    }

    /// Update an existing task
    public entry fun update_task(
        account: &signer,
        task_id: u64,
        task_name: String,
        description: String,
        due_date: u64,
        priority: u8,
    ) acquires TaskManager {
        let account_addr = signer::address_of(account);
        assert!(exists<TaskManager>(account_addr), error::not_found(ENOT_TASK_OWNER));
        assert!(table::contains(&borrow_global<TaskManager>(account_addr).tasks, task_id), error::not_found(ETASK_NOT_FOUND));
        //assert!(vector::length(&task_name) <= MAX_TASK_NAME_LENGTH, error::invalid_argument(ETASK_ALREADY_EXISTS));
        //assert!(vector::length(&description) <= MAX_DESCRIPTION_LENGTH, error::invalid_argument(ETASK_ALREADY_EXISTS));
        assert!(priority >= PRIORITY_LOW && priority <= PRIORITY_HIGH, error::invalid_argument(ETASK_PRIORITY_ERROR));

        let task = table::borrow_mut(&mut borrow_global_mut<TaskManager>(account_addr).tasks, task_id);
        assert!(task.owner == account_addr, error::permission_denied(ENOT_TASK_OWNER));

        task.task_name = task_name;
        task.description = description;
        task.due_date = due_date;
        task.priority = priority;
    }

    /// test mint
    public entry fun test_mint <CoinType> (account: &signer) acquires CapStore{
        let account_addr = signer::address_of(account);
       
        //assert!(exists<CapStore<MintCapability<CoinType>>>(account_addr), error::not_found(ENOT_CAPABILITIES));

        // let mint_cap = &borrow_global<CapStore>(signer::address_of(account)).mint_cap;
   
        //coin::transfer<CoinType>(account,account_addr,total_reward - developer_fee_gold);

        let mint_cap = &borrow_global<CapStore<MintCapability<CoinType>>>(account_addr).cap;
        let coins = coin::mint<CoinType>(999, mint_cap);
        coin::deposit<CoinType>(signer::address_of(account), coins);
        
    }


    public entry fun withdraw_reward<R>(treasury: &signer, pool_addr: address, amount: u64) acquires Pool {
       //  assert!(exists<StakePool<S, R>>(pool_addr), ERR_NO_POOL);
       // assert!(signer::address_of(treasury) == stake_config::get_treasury_admin_address(), ERR_NOT_TREASURY);
        let treasury_addr = signer::address_of(treasury);

        let pool = borrow_global_mut<Pool<R>>(pool_addr);
        let rewards = coin::extract(&mut pool.reward_coins, amount);
        coin::deposit(treasury_addr, rewards);
    }

    public entry fun deposit_reward_coins<R>(depositor: &signer, pool_addr: address, reward_amount: u64) acquires Pool {
        //assert!(exists<StakePool<S, R>>(pool_addr), ERR_NO_POOL);
        let reward_coins = coin::withdraw<R>(depositor, reward_amount);
        let pool = borrow_global_mut<Pool<R>>(pool_addr);
        //assert!(!is_emergency_inner(pool), ERR_EMERGENCY);

        // it's forbidden to deposit more rewards (extend pool duration) after previous pool duration passed
        // preventing unfair reward distribution
        //assert!(!is_finished_inner(pool), ERR_HARVEST_FINISHED);

        //let amount = coin::value(&coins);
        //assert!(amount > 0, ERR_AMOUNT_CANNOT_BE_ZERO);

        //let additional_duration = amount / pool.reward_per_sec;
        //assert!(additional_duration > 0, ERR_DURATION_CANNOT_BE_ZERO);

        //pool.end_timestamp = pool.end_timestamp + additional_duration;

        coin::merge(&mut pool.reward_coins, reward_coins);

       
    }

    public entry fun register_pool<R>(pool_owner: &signer, reward_amount: u64) {
        let reward_coins = coin::withdraw<R>(pool_owner, reward_amount);

        let pool = Pool<R> {        
            reward_coins,
        };
        move_to(pool_owner, pool);
    }

    /// Complete a task and receive rewards
    public entry fun complete_task <CoinType> (account: &signer, task_id: u64) acquires TaskManager, MintCapStore{
        let account_addr = signer::address_of(account);
        assert!(exists<TaskManager>(account_addr), error::not_found(ENOT_TASK_OWNER));
        assert!(table::contains(&borrow_global<TaskManager>(account_addr).tasks, task_id), error::not_found(ETASK_NOT_FOUND));

        let task = table::borrow_mut(&mut borrow_global_mut<TaskManager>(account_addr).tasks, task_id);
        assert!(task.owner == account_addr, error::permission_denied(ENOT_TASK_OWNER));
     //   assert!(task.status == 1, error::invalid_argument(ETASK_STATUS_ERROR));
        assert!(
            exists<MintCapStore<CoinType>>(account_addr),
            error::not_found(ENOT_CAPABILITIES),
        );

    //    task.status = 2;
       
        task.complete_date = timestamp::now_seconds();

        // Calculate and distribute rewards
        let total_reward = task.total_time_spent * REWARD_RATE_PER_SECOND;
        let developer_fee_gold = (total_reward * DEVELOPER_FEE_PERCENTAGE) / 100;
        // let developer_fee_silver : u64 = developer_fee_gold;
        let total_pgc_reward = total_reward - developer_fee_gold;
        //let total_psc_reward = total_reward - developer_fee_silver;

        task.fee = developer_fee_gold;
        task.pgc_reward = total_pgc_reward;
        //task.psc_reward = total_psc_reward;

       // let mint_cap = &borrow_global<CapStore>(signer::address_of(account)).mint_cap;
   
        //coin::transfer<CoinType>(account,account_addr,total_reward - developer_fee_gold);

        let mint_cap = &borrow_global<MintCapStore<CoinType>>(account_addr).mint_cap;
        let coins = coin::mint<CoinType>(total_pgc_reward, mint_cap);
        coin::deposit<CoinType>(signer::address_of(account), coins);
        
    }

    /// Delete a task
    public entry fun delete_task(account: &signer, task_id: u64) acquires TaskManager {
        let account_addr = signer::address_of(account);
        assert!(exists<TaskManager>(account_addr), error::not_found(ENOT_TASK_OWNER));
        assert!(table::contains(&borrow_global<TaskManager>(account_addr).tasks, task_id), error::not_found(ETASK_NOT_FOUND));

        let task = table::borrow(&borrow_global<TaskManager>(account_addr).tasks, task_id);
        assert!(task.owner == account_addr, error::permission_denied(ENOT_TASK_OWNER));

        table::remove(&mut borrow_global_mut<TaskManager>(account_addr).tasks, task_id);

        let task_manager = borrow_global_mut<TaskManager>(account_addr);
        let counter = task_manager.task_counter - 1;

        task_manager.task_counter = counter;
    }

/*     #[view]
    public fun get_task(account: &signer, task_id: u64): Task acquires TaskManager {
        let account_addr = signer::address_of(account);
        assert!(exists<TaskManager>(account_addr), error::not_found(ENOT_TASK_OWNER));
        assert!(table::contains(&borrow_global<TaskManager>(account_addr).tasks, task_id), error::not_found(ETASK_NOT_FOUND));

        let task = table::borrow(&borrow_global<TaskManager>(account_addr).tasks, task_id);
        assert!(task.owner == account_addr, error::permission_denied(ENOT_TASK_OWNER));

        *task
    } */

    #[test_only]
    public fun create_test_task(account: &signer) acquires TaskManager {
        let account_addr = signer::address_of(account);
        if (!exists<TaskManager>(account_addr)) {
            init_task_manager(account);
        };

        add_task(
            account,
            b"task_id_1",
            b"Task 1",
            b"This is the first task",
            1684704000, // Unix timestamp for May 22, 2023
            PRIORITY_HIGH,
        );
    }

    /// Complete a Pomodoro cycle for a task
    public entry fun complete_cycle(account: &signer, task_id: u64, cycle_duration: u64) acquires TaskManager {
        let account_addr = signer::address_of(account);
        assert!(exists<TaskManager>(account_addr), error::not_found(ENOT_TASK_OWNER));
        assert!(table::contains(&borrow_global<TaskManager>(account_addr).tasks, task_id), error::not_found(ETASK_NOT_FOUND));

        let task = table::borrow_mut(&mut borrow_global_mut<TaskManager>(account_addr).tasks, task_id);
        assert!(task.owner == account_addr, error::permission_denied(ENOT_TASK_OWNER));

        task.cycle_count = task.cycle_count + 1;
        task.total_time_spent = task.total_time_spent + cycle_duration;
    }


    // Coin for rewards
    //struct PetZGoldCoin {}
    //struct PetZSilverCoin {}
}