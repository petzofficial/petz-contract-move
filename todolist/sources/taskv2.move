module pomodoro_task_management::task {
    use std::error;
    use std::signer;
    use std::vector;
    use aptos_std::table::{Self, Table};
    use aptos_std::coin;

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
    const MAX_TASK_NAME_LENGTH: u64 = 100;
    const MAX_DESCRIPTION_LENGTH: u64 = 500;

    /// Task struct
    struct Task has copy, drop, store {
        task_id: vector<u8>,
        task_name: vector<u8>,
        description: vector<u8>,
        due_date: u64, // Unix timestamp
        priority: u8,
        cycle_count: u64,
        total_time_spent: u64,
        owner: address,
        is_completed: bool,
    }

    /// Task manager struct
    struct TaskManager has key {
        tasks: Table<vector<u8>, Task>,
    }

    /// Initialize task manager for an account
    public entry fun init_task_manager(account: &signer) {
        let account_addr = signer::address_of(account);
        if (!exists<TaskManager>(account_addr)) {
            move_to(account, TaskManager { tasks: table::new() });
            coin::register<PetZGoldCoin>(account);
            coin::register<PetZSilverCoin>(account);
        } else {
            error::already_exists(ETASK_ALREADY_EXISTS);
        }
    }

    /// Add a new task
    public entry fun add_task(
        account: &signer,
        task_id: vector<u8>,
        task_name: vector<u8>,
        description: vector<u8>,
        due_date: u64,
        priority: u8,
    ) acquires TaskManager {
        let account_addr = signer::address_of(account);
        assert!(!exists<TaskManager>(account_addr), error::not_found(ENOT_TASK_OWNER));
        assert!(!table::contains(&borrow_global<TaskManager>(account_addr).tasks, task_id), error::already_exists(ETASK_ALREADY_EXISTS));
        assert!(vector::length(&task_name) <= MAX_TASK_NAME_LENGTH, error::invalid_argument(ETASK_ALREADY_EXISTS));
        assert!(vector::length(&description) <= MAX_DESCRIPTION_LENGTH, error::invalid_argument(ETASK_ALREADY_EXISTS));
        assert!(priority >= PRIORITY_LOW && priority <= PRIORITY_HIGH, error::invalid_argument(ETASK_ALREADY_EXISTS));

        table::add(
            &mut borrow_global_mut<TaskManager>(account_addr).tasks,
            task_id,
            Task {
                task_id,
                task_name,
                description,
                due_date,
                priority,
                cycle_count: 0,
                total_time_spent: 0,
                owner: account_addr,
                is_completed: false,
            },
        );
    }

    /// Update an existing task
    public entry fun update_task(
        account: &signer,
        task_id: vector<u8>,
        task_name: vector<u8>,
        description: vector<u8>,
        due_date: u64,
        priority: u8,
    ) acquires TaskManager {
        let account_addr = signer::address_of(account);
        assert!(exists<TaskManager>(account_addr), error::not_found(ENOT_TASK_OWNER));
        assert!(table::contains(&borrow_global<TaskManager>(account_addr).tasks, task_id), error::not_found(ETASK_NOT_FOUND));
        assert!(vector::length(&task_name) <= MAX_TASK_NAME_LENGTH, error::invalid_argument(ETASK_ALREADY_EXISTS));
        assert!(vector::length(&description) <= MAX_DESCRIPTION_LENGTH, error::invalid_argument(ETASK_ALREADY_EXISTS));
        assert!(priority >= PRIORITY_LOW && priority <= PRIORITY_HIGH, error::invalid_argument(ETASK_ALREADY_EXISTS));

        let task = table::borrow_mut(&mut borrow_global_mut<TaskManager>(account_addr).tasks, task_id);
        assert!(task.owner == account_addr, error::permission_denied(ENOT_TASK_OWNER));

        task.task_name = task_name;
        task.description = description;
        task.due_date = due_date;
        task.priority = priority;
    }

    /// Complete a task and receive rewards
    public entry fun complete_task(account: &signer, task_id: vector<u8>) acquires TaskManager {
        let account_addr = signer::address_of(account);
        assert!(exists<TaskManager>(account_addr), error::not_found(ENOT_TASK_OWNER));
        assert!(table::contains(&borrow_global<TaskManager>(account_addr).tasks, task_id), error::not_found(ETASK_NOT_FOUND));

        let task = table::borrow_mut(&mut borrow_global_mut<TaskManager>(account_addr).tasks, task_id);
        assert!(task.owner == account_addr, error::permission_denied(ENOT_TASK_OWNER));
        assert!(!task.is_completed, error::already_exists(ETASK_ALREADY_EXISTS));

        task.is_completed = true;

        // Calculate and distribute rewards
        let total_reward = task.total_time_spent * REWARD_RATE_PER_SECOND;
        let developer_fee_gold = (total_reward * DEVELOPER_FEE_PERCENTAGE) / 100;
        let developer_fee_silver = developer_fee_gold;

        coin::deposit(account, coin::mint<PetZGoldCoin>(account_addr, total_reward - developer_fee_gold));
        coin::deposit(account, coin::mint<PetZSilverCoin>(account_addr, total_reward - developer_fee_silver));
    }

    /// Delete a task
    public entry fun delete_task(account: &signer, task_id: vector<u8>) acquires TaskManager {
        let account_addr = signer::address_of(account);
        assert!(exists<TaskManager>(account_addr), error::not_found(ENOT_TASK_OWNER));
        assert!(table::contains(&borrow_global<TaskManager>(account_addr).tasks, task_id), error::not_found(ETASK_NOT_FOUND));

        let task = table::borrow(&borrow_global<TaskManager>(account_addr).tasks, task_id);
        assert!(task.owner == account_addr, error::permission_denied(ENOT_TASK_OWNER));

        table::remove(&mut borrow_global_mut<TaskManager>(account_addr).tasks, task_id);
    }

    /// Get a task by ID
    public fun get_task(account: &signer, task_id: vector<u8>): Task acquires TaskManager {
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

    /// Get all tasks for an account
    public fun get_all_tasks(account: &signer): vector<Task> acquires TaskManager {
        let account_addr = signer::address_of(account);
        assert!(exists<TaskManager>(account_addr), error::not_found(ENOT_TASK_OWNER));

        let tasks = &borrow_global<TaskManager>(account_addr).tasks;
        let task_vec = vector::empty();

        table::for_each_entry(tasks, |_, task| {
            vector::push_back(&mut task_vec, *task);
        });

        task_vec
    }

    /// Complete a Pomodoro cycle for a task
    public entry fun complete_cycle(account: &signer, task_id: vector<u8>, cycle_duration: u64) acquires TaskManager {
        let account_addr = signer::address_of(account);
        assert!(exists<TaskManager>(account_addr), error::not_found(ENOT_TASK_OWNER));
        assert!(table::contains(&borrow_global<TaskManager>(account_addr).tasks, task_id), error::not_found(ETASK_NOT_FOUND));

        let task = table::borrow_mut(&mut borrow_global_mut<TaskManager>(account_addr).tasks, task_id);
        assert!(task.owner == account_addr, error::permission_denied(ENOT_TASK_OWNER));

        task.cycle_count = task.cycle_count + 1;
        task.total_time_spent = task.total_time_spent + cycle_duration;
    }

    /// Coin types for rewards
    struct PetZGoldCoin {}
    struct PetZSilverCoin {}
}