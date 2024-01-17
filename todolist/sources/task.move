module tasklist_addr::tasklist {
    struct Task {
        id: u64,
        description: String,
        deadline: Time,
        reward: u64, // APT amount
        status: bool, // true for completed
        creator: address,
    }

    struct User {
        address: address,
        reputation: u64,
        completedTasks: Vec<u64>, // IDs of completed tasks
    }

    function createTask(description: String, deadline: Time, reward: u64): u64 {
        let task = Task {
            id: getNextTaskId(),
            description,
            deadline,
            reward,
            status: false,
            creator: signer,
        };
        // Mint reward and transfer to creator account
        transfer(signer, &{amount: reward, token: APT});
        // Store task data
        insert<Task>(task);
        return task.id;
        }

    function completeTask(taskId: u64): bool {
        let mut task = get<Task>(taskId);
        if task.status || task.deadline < getCurrentTime() {
            return false;
        }
        task.status = true;
        update<Task>(task);
        // Transfer reward to user and update reputation
        transfer(&signer, &{amount: task.reward, token: APT});
        let mut user = get<User>(signer);
        user.completedTasks.push(taskId);
        user.reputation += task.reward;
        update<User>(user);
        return true;
    }

    function getTaskInfo(taskId: u64): Task? {
        return get<Task>(taskId);
    }

    function getUserTasks(user: address): Vec<u64> {
        let mut user = get<User>(user);
        return user.completedTasks;
    }

    function withdrawReward(): bool {
        let mut user = get<User>(signer);
        // Calculate total pending rewards
        let mut reward = 0;
        for taskId in user.completedTasks {
            reward += get<Task>(taskId).reward;
        }
        if reward > 0 {
            transfer(&signer, &{amount: reward, token: APT});
            user.completedTasks = []; // Reset reward pool
            update<User>(user);
            return true;
        }
        return false;
    }

    function updateTask(taskId: u64, description: String, deadline: Time, reward: u64): bool {
        let mut task = get<Task>(taskId);
        if task.status || task.deadline < getCurrentTime() || task.creator != signer {
            return false; // Cannot update completed tasks, expired tasks, or tasks created by others
        }
        task.description = description;
        task.deadline = deadline;
        task.reward = reward;
        update<Task>(task);
        return true;
    }

    function deleteTask(taskId: u64): bool {
        let mut task = get<Task>(taskId);
        if task.status || task.deadline < getCurrentTime() || task.creator != signer {
            return false; // Cannot delete completed tasks, expired tasks, or tasks created by others
        }
        // Refund reward to creator if task is not completed
        if !task.status {
            transfer(task.creator, &{amount: task.reward, token: APT});
        }
        remove<Task>(taskId);
        return true;
    }
    
}