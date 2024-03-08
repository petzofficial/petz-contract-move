module task_management::task {
    use std::error;
    use std::signer;
    use std::string::String;
    use aptos_std::table::{Self, Table};
    use aptos_framework::event;
    use aptos_framework::account;
    use aptos_framework::timestamp;
    //use std::hash;
    //use aptos_std::coin;

    /// Error codes
    const ETASK_ALREADY_EXISTS: u64 = 0;
    const ETASK_NOT_FOUND: u64 = 1;
    const ENOT_TASK_OWNER: u64 = 2;

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
        status: u8,
    }

    /// Task manager struct
    struct TaskManager has key {
        tasks: Table<u64, Task>,
        set_task_event: event::EventHandle<Task>,
  //      task_counter: u64
    }


    public entry fun add_task(
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
               // task_counter: 0
            });
           // coin::register<PetZGoldCoin>(account);
           // coin::register<PetZSilverCoin>(account);
        };

        //assert!(!table::contains(&borrow_global<TaskManager>(account_addr).tasks, task_id), error::already_exists(ETASK_ALREADY_EXISTS));
        //assert!(vector::length(&task_name) <= MAX_TASK_NAME_LENGTH, error::invalid_argument(ETASK_ALREADY_EXISTS));
        //assert!(vector::length(&description) <= MAX_DESCRIPTION_LENGTH, error::invalid_argument(ETASK_ALREADY_EXISTS));
        assert!(priority >= PRIORITY_LOW && priority <= PRIORITY_HIGH, error::invalid_argument(ETASK_ALREADY_EXISTS));
        //let task_manager = borrow_global_mut<TaskManager>(account_addr);
      
        let timestamp_seconds = timestamp::now_seconds();
        let current_time = timestamp_seconds;
        //let timestamp_bytes = timestamp_seconds.to_le_bytes();
        let unique_id = timestamp_seconds;

        let new_task = Task {
            task_id: unique_id,
            task_name,
            description,
            create_date: current_time,
            complete_date: 0,
            due_date,
            priority,
            cycle_count: 0,
            total_time_spent: 0,
            owner: account_addr,
            status: 0, //0 pending, 1 in-progress, 2 completed
        };

        table::add(
            &mut borrow_global_mut<TaskManager>(account_addr).tasks,
            unique_id,
            new_task,
        );

        //task_manager.task_counter = task_manager.task_counter + 1;

        event::emit_event<Task>(
            &mut borrow_global_mut<TaskManager>(account_addr).set_task_event,
            new_task,
        );
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
        //assert!(table::contains(&borrow_global<TaskManager>(account_addr).tasks, task_id), error::not_found(ETASK_NOT_FOUND));
        //assert!(vector::length(&task_name) <= MAX_TASK_NAME_LENGTH, error::invalid_argument(ETASK_ALREADY_EXISTS));
        //assert!(vector::length(&description) <= MAX_DESCRIPTION_LENGTH, error::invalid_argument(ETASK_ALREADY_EXISTS));
        assert!(priority >= PRIORITY_LOW && priority <= PRIORITY_HIGH, error::invalid_argument(ETASK_ALREADY_EXISTS));

        let task = table::borrow_mut(&mut borrow_global_mut<TaskManager>(account_addr).tasks, task_id);
        assert!(task.owner == account_addr, error::permission_denied(ENOT_TASK_OWNER));

        task.task_name = task_name;
        task.description = description;
        task.due_date = due_date;
        task.priority = priority;
    }

    /// Complete a task and receive rewards
    public entry fun complete_task(account: &signer, task_id: u64) acquires TaskManager {
        let account_addr = signer::address_of(account);
        assert!(exists<TaskManager>(account_addr), error::not_found(ENOT_TASK_OWNER));
        assert!(table::contains(&borrow_global<TaskManager>(account_addr).tasks, task_id), error::not_found(ETASK_NOT_FOUND));

        let task = table::borrow_mut(&mut borrow_global_mut<TaskManager>(account_addr).tasks, task_id);
        assert!(task.owner == account_addr, error::permission_denied(ENOT_TASK_OWNER));
        assert!(task.status == 1, error::already_exists(ETASK_ALREADY_EXISTS));

        task.status = 2;
        task.complete_date = timestamp::now_seconds();

        // Calculate and distribute rewards
       // let total_reward = task.total_time_spent * REWARD_RATE_PER_SECOND;
       // let developer_fee_gold = (total_reward * DEVELOPER_FEE_PERCENTAGE) / 100;
       // let developer_fee_silver = developer_fee_gold;

       // coin::deposit(account, coin::mint<PetZGoldCoin>(account_addr, total_reward - developer_fee_gold));
       // coin::deposit(account, coin::mint<PetZSilverCoin>(account_addr, total_reward - developer_fee_silver));
    }

    /// Delete a task
    public entry fun delete_task(account: &signer, task_id: u64) acquires TaskManager {
        let account_addr = signer::address_of(account);
        assert!(exists<TaskManager>(account_addr), error::not_found(ENOT_TASK_OWNER));
        assert!(table::contains(&borrow_global<TaskManager>(account_addr).tasks, task_id), error::not_found(ETASK_NOT_FOUND));

        let task = table::borrow(&borrow_global<TaskManager>(account_addr).tasks, task_id);
        assert!(task.owner == account_addr, error::permission_denied(ENOT_TASK_OWNER));

        table::remove(&mut borrow_global_mut<TaskManager>(account_addr).tasks, task_id);
    }

    #[view]
    public fun get_task(account: &signer, task_id: u64): Task acquires TaskManager {
        let account_addr = signer::address_of(account);
        assert!(exists<TaskManager>(account_addr), error::not_found(ENOT_TASK_OWNER));
        assert!(table::contains(&borrow_global<TaskManager>(account_addr).tasks, task_id), error::not_found(ETASK_NOT_FOUND));

        let task = table::borrow(&borrow_global<TaskManager>(account_addr).tasks, task_id);
        assert!(task.owner == account_addr, error::permission_denied(ENOT_TASK_OWNER));

        *task
    }

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