module pomodoro_task_management::task {
    use std::signer;
    use std::error;
    use std::vector;
    use aptos_std::table::{Self, Table};
    use aptos_std::coin;

    const ENOT_TASK_OWNER: u64 = 1;
    const ETASK_ALREADY_EXISTS: u64 = 2;
    const DEVELOPER_FEE_PERCENTAGE: u64 = 5; // 5%

    struct Task has key {
        task_id: vector<u8>,
        task_name: vector<u8>,
        description: vector<u8>,
        date: u64,
        priority: u8,
        cycle_count: u64,
        total_time_spent: u64,
        owner: address,
        status: bool,
    }

    struct TaskManager has key {
        tasks: Table<vector<u8>, Task>,
    }

    public fun init_task_manager(account: &signer) {
        move_to(account, TaskManager { tasks: table::new() });

        // Initialize PetZ Gold Coin and PetZ Silver Coin resources for the account
        coin::register<PetZGoldCoin>(account);
        coin::register<PetZSilverCoin>(account);
    }

    public fun add_task(
        account: &signer,
        task_id: vector<u8>,
        task_name: vector<u8>,
        description: vector<u8>,
        date: u64,
        priority: u8,
    ) acquires TaskManager {
        let account_addr = signer::address_of(account);
        assert!(
            !table::contains(&borrow_global<TaskManager>(account_addr).tasks, task_id),
            error::already_exists(ETASK_ALREADY_EXISTS)
        );

        table::add(
            &mut borrow_global_mut<TaskManager>(account_addr).tasks,
            task_id,
            Task {
                task_id,
                task_name,
                description,
                date,
                priority,
                cycle_count: 0,
                total_time_spent: 0,
                owner: account_addr,
                status: false,
            },
        );
    }

    public fun update_task(
        account: &signer,
        task_id: vector<u8>,
        task_name: vector<u8>,
        description: vector<u8>,
        date: u64,
        priority: u8,
    ) acquires TaskManager {
        let account_addr = signer::address_of(account);
        assert!(table::contains(&borrow_global<TaskManager>(account_addr).tasks, task_id), error::not_found(ENOT_TASK_OWNER));

        let task = table::borrow_mut(&mut borrow_global_mut<TaskManager>(account_addr).tasks, task_id);
        assert!(task.owner == account_addr, error::permission_denied(ENOT_TASK_OWNER));

        task.task_name = task_name;
        task.description = description;
        task.date = date;
        task.priority = priority;
    }

    public fun complete_task(account: &signer, task_id: vector<u8>) acquires TaskManager {
        let account_addr = signer::address_of(account);
        assert!(table::contains(&borrow_global<TaskManager>(account_addr).tasks, task_id), error::not_found(ENOT_TASK_OWNER));

        let task = table::borrow_mut(&mut borrow_global_mut<TaskManager>(account_addr).tasks, task_id);
        assert!(task.owner == account_addr, error::permission_denied(ENOT_TASK_OWNER));

        task.status = true;

        // Calculate reward amounts based on total time spent
        let reward_gold = task.total_time_spent;
        let reward_silver = task.total_time_spent;
        let developer_fee_gold = (reward_gold * DEVELOPER_FEE_PERCENTAGE) / 100;
        let developer_fee_silver = (reward_silver * DEVELOPER_FEE_PERCENTAGE) / 100;

        coin::deposit(account, coin::mint<PetZGoldCoin>(account_addr, reward_gold - developer_fee_gold));
        coin::deposit(account, coin::mint<PetZSilverCoin>(account_addr, reward_silver - developer_fee_silver));
    }

    public fun delete_task(account: &signer, task_id: vector<u8>) acquires TaskManager {
            let account_addr = signer::address_of(account);
            assert!(table::contains(&borrow_global<TaskManager>(account_addr).tasks, task_id), error::not_found(ENOT_TASK_OWNER));

            let task = table::borrow(&borrow_global<TaskManager>(account_addr).tasks, task_id);
            assert!(task.owner == account_addr, error::permission_denied(ENOT_TASK_OWNER));

            table::remove(&mut borrow_global_mut<TaskManager>(account_addr).tasks, task_id);
    }

    public fun get_task(account: &signer, task_id: vector<u8>): Task acquires TaskManager {
        let account_addr = signer::address_of(account);
        assert!(table::contains(&borrow_global<TaskManager>(account_addr).tasks, task_id), error::not_found(ENOT_TASK_OWNER));

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
            1,
        );
    }

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


    // Coin types for rewards
    struct PetZGoldCoin {}
    struct PetZSilverCoin {}
}