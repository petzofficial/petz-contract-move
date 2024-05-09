module candymachinev2::petz_candymachine{
    use std::signer;
    use std::bcs;
    use std::hash;
    use aptos_std::aptos_hash;
    use aptos_std::from_bcs;
    use std::string::{Self, String};
    use std::vector;
    use std::option::{Self, Option};
    use aptos_framework::object::{Self, ConstructorRef, Object,ExtendRef};
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::aptos_coin::AptosCoin;
    use candymachinev2::bit_vector::{Self,BitVector};
    use aptos_framework::coin::{Self};
    use aptos_framework::account;
    use aptos_framework::timestamp;
    use aptos_token_objects::aptos_token::{Self,AptosToken};
    use aptos_token_objects::royalty::{Self, Royalty};

    use aptos_token_objects::token::{Self};
    use candymachinev2::bucket_table::{Self, BucketTable};
    use candymachinev2::merkle_proof::{Self};

    const INVALID_SIGNER: u64 = 0;
    const INVALID_amount: u64 = 1;
    const CANNOT_ZERO: u64 = 2;
    const EINVALID_ROYALTY_NUMERATOR_DENOMINATOR: u64 = 3;
    const ESALE_NOT_STARTED: u64 = 4;
    const ESOLD_OUT:u64 = 5;
    const EPAUSED:u64 = 6;
    const INVALID_MUTABLE_CONFIG:u64 = 7;
    const EINVALID_MINT_TIME:u64 = 8;
    const MINT_LIMIT_EXCEED: u64 = 9;
    const INVALID_PROOF:u64 = 10;
    const WhitelistMintNotEnabled: u64 = 11;
    const AdminFee: address = @0x3ee4f7db342b58b4d3523df10f8f523ab922298f064dad6f97a2493ca8a691de;

    struct MintData has key {
        total_mints: u64,
        total_apt: u64
    }
    struct CandyMachine has key {
        collection_name: String,
        collection_description: String,
        baseuri: String,
        royalty_payee_address:address,
        royalty_points_denominator: u64,
        royalty_points_numerator: u64,
        presale_mint_time: u64,
        public_sale_mint_time: u64,
        presale_mint_price: u64,
        public_sale_mint_price: u64,
        paused: bool,
        total_supply: u64,
        minted: u64,
        token_mutate_setting:vector<bool>,
        candies:BitVector,
        public_mint_limit: u64,
        merkle_root: vector<u8>,
        is_sbt: bool,
        update_event: EventHandle<UpdateCandyEvent>,
        is_openedition:bool,
    }
    struct Whitelist has key {
        minters: BucketTable<address,u64>,
    }
    struct PublicMinters has key {
        minters: BucketTable<address, u64>,
    }
    struct ResourceInfo has key {
            source: address,
            resource_cap: account::SignerCapability
    }
    struct UpdateCandyEvent has drop, store {
        presale_mint_price: u64,
        presale_mint_time: u64,
        public_sale_mint_price: u64,
        public_sale_mint_time: u64,
        royalty_points_denominator: u64,
        royalty_points_numerator: u64,
    }
    fun init_module(account: &signer) {
        move_to(account, MintData {
            total_mints: 0,
            total_apt: 0
        })
    }
    public entry fun init_candy(
        account: &signer,
        collection_name: String,
        collection_description: String,
        baseuri: String,
        royalty_payee_address:address,
        royalty_points_denominator: u64,
        royalty_points_numerator: u64,
        presale_mint_time: u64,
        public_sale_mint_time: u64,
        presale_mint_price: u64,
        public_sale_mint_price: u64,
        total_supply:u64,
        collection_mutate_setting:vector<bool>,
        token_mutate_setting:vector<bool>,
        public_mint_limit: u64,
        is_sbt: bool,
        seeds: vector<u8>,
        is_openedition:bool,
    ){
        let constructor_ref = object::create_object_from_account(account);
        let object_signer = object::generate_signer(&constructor_ref);
        let (_resource, resource_cap) = account::create_resource_account(account, seeds);
        let resource_signer_from_cap = account::create_signer_with_capability(&resource_cap);
        move_to<ResourceInfo>(&object_signer, ResourceInfo{resource_cap: resource_cap, source: signer::address_of(account)});
        let now = aptos_framework::timestamp::now_seconds();
        assert!(vector::length(&collection_mutate_setting) == 3 && vector::length(&token_mutate_setting) == 5, INVALID_MUTABLE_CONFIG);
        assert!(royalty_points_denominator > 0, EINVALID_ROYALTY_NUMERATOR_DENOMINATOR);
        assert!(public_sale_mint_time > presale_mint_time && presale_mint_time >= now,EINVALID_MINT_TIME);
        assert!(royalty_points_numerator <= royalty_points_denominator, EINVALID_ROYALTY_NUMERATOR_DENOMINATOR);
        let supply = total_supply;
        if (is_openedition)
        {
            supply=100000000;
        };
        move_to<CandyMachine>(&object_signer, CandyMachine{
            collection_name:collection_name,
            collection_description:collection_description,
            baseuri:baseuri,
            royalty_payee_address:royalty_payee_address,
            royalty_points_denominator:royalty_points_denominator,
            royalty_points_numerator:royalty_points_numerator,
            presale_mint_time:presale_mint_time,
            public_sale_mint_time:public_sale_mint_time,
            presale_mint_price:presale_mint_price,
            public_sale_mint_price:public_sale_mint_price,
            total_supply:supply,
            minted:0,
            paused:false,
            candies:bit_vector::new(total_supply),
            token_mutate_setting:token_mutate_setting,
            public_mint_limit: public_mint_limit,
            merkle_root: vector::empty(),
            is_sbt: is_sbt,
            update_event: account::new_event_handle<UpdateCandyEvent>(&resource_signer_from_cap),
            is_openedition:is_openedition,
        });
        aptos_token::create_collection(
            &resource_signer_from_cap, 
            collection_description, 
            supply,
            collection_name,
            baseuri, 
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            royalty_points_numerator,
            royalty_points_denominator
        );
        move_to(&object_signer, PublicMinters {
                // Can use a different size of bucket table depending on how big we expect the whitelist to be.
                // Here because a global pubic minting max is optional, we are starting with a smaller size
                // bucket table.
                minters: bucket_table::new<address, u64>(4),
         });
        initialize_whitelist(object_signer)
    }
    public entry fun mint_script(
        receiver: &signer,
        candy_obj: address,
    )acquires CandyMachine,MintData,ResourceInfo,PublicMinters{
        let candy_data = borrow_global_mut<CandyMachine>(candy_obj);
        let resource_data = borrow_global<ResourceInfo>(candy_obj);
        let candy_admin = resource_data.source;
        let creator = account::create_signer_with_capability(&resource_data.resource_cap);
        let mint_price = candy_data.public_sale_mint_price;
        let now = aptos_framework::timestamp::now_seconds();
        assert!(now > candy_data.public_sale_mint_time, ESALE_NOT_STARTED);
        mint(receiver,&creator,candy_admin,candy_obj,mint_price)
    }
    public entry fun mint_script_many(
        receiver: &signer,
        candy_obj: address,
        amount: u64
    )acquires CandyMachine,MintData,ResourceInfo,PublicMinters{
        let i = 0;
        while (i < amount){
            mint_script(receiver,candy_obj);
            i=i+1
        }
    }
    public entry fun mint_from_merkle(
        receiver: &signer,
        candy_obj: address,
        proof: vector<vector<u8>>,
        mint_limit: u64,
    ) acquires MintData,CandyMachine,ResourceInfo,Whitelist,PublicMinters{
        let receiver_addr = signer::address_of(receiver);
        let candy_data = borrow_global_mut<CandyMachine>(candy_obj);
        let resource_data = borrow_global<ResourceInfo>(candy_obj);
        let creator = account::create_signer_with_capability(&resource_data.resource_cap);
        let candy_admin = resource_data.source;
        let mint_data = borrow_global_mut<MintData>(@candymachinev2);
        let now = aptos_framework::timestamp::now_seconds();
        let leafvec = bcs::to_bytes(&receiver_addr);
        vector::append(&mut leafvec,bcs::to_bytes(&mint_limit));
        let is_whitelist_mint = candy_data.presale_mint_time < now && now < candy_data.public_sale_mint_time;
        assert!(is_whitelist_mint, WhitelistMintNotEnabled);
        assert!(merkle_proof::verify(proof,candy_data.merkle_root,aptos_hash::keccak256(leafvec)),INVALID_PROOF);
        // No need to check limit if mint limit = 0, this means the minter can mint unlimited amount of tokens
        if(mint_limit != 0){
            let whitelist_data = borrow_global_mut<Whitelist>(candy_obj);
            if (!bucket_table::contains(&whitelist_data.minters, &receiver_addr)) {
                // First time minting mint limit = 0 
                bucket_table::add(&mut whitelist_data.minters, receiver_addr, 0);
            };
            let minted_nft = bucket_table::borrow_mut(&mut whitelist_data.minters, receiver_addr);
            assert!(*minted_nft != mint_limit, MINT_LIMIT_EXCEED);
            *minted_nft = *minted_nft + 1;
            mint_data.total_apt=mint_data.total_apt+candy_data.presale_mint_price;
        };
        mint(receiver,&creator,candy_admin,candy_obj,candy_data.presale_mint_price);
    }
    public entry fun mint_from_merkle_many(
        receiver: &signer,
        candy_obj: address,
        proof: vector<vector<u8>>,
        mint_limit: u64,
        amount: u64
    )acquires MintData,CandyMachine,ResourceInfo,Whitelist,PublicMinters{
        let i = 0;
        while (i < amount){
            mint_from_merkle(receiver,candy_obj,proof,mint_limit);
            i=i+1
        }
    }
    fun mint(
        receiver: &signer,
        creator: &signer,
        candy_admin: address,
        candy_obj: address,
        mint_price: u64
    )acquires CandyMachine,MintData,PublicMinters{
        let receiver_addr = signer::address_of(receiver);
        let candy_data = borrow_global_mut<CandyMachine>(candy_obj);
        let mint_data = borrow_global_mut<MintData>(@candymachinev2);
        let now = aptos_framework::timestamp::now_seconds();
        if(now > candy_data.public_sale_mint_time && candy_data.public_mint_limit != 0){
            add_public_minter(candy_data,receiver_addr,candy_obj);
            mint_data.total_apt=mint_data.total_apt+candy_data.public_sale_mint_price;
        };
        assert!(!candy_data.paused, EPAUSED);
        assert!(candy_data.minted != candy_data.total_supply, ESOLD_OUT);
        let baseuri = candy_data.baseuri;
        let token_name = candy_data.collection_name;
        if(candy_data.is_openedition)
        {
            string::append(&mut token_name,string::utf8(b" #"));
            string::append(&mut token_name,num_str(candy_data.minted));
        } else
        {
            let remaining = candy_data.total_supply - candy_data.minted;
            let random_index = pseudo_random(receiver_addr,remaining);
            let required_position=0; // the number of unset 
            let pos=0; // the mint number 
            while (required_position < random_index)
            {
            if (!bit_vector::is_index_set(&candy_data.candies, pos))
                {
                    required_position=required_position+1;

                };
            if (required_position == random_index)
                {                    
                    break
                };
                pos=pos+1;
            };
            bit_vector::set(&mut candy_data.candies,pos);
            let mint_position = pos;
            string::append(&mut baseuri,num_str(mint_position));
            string::append(&mut token_name,string::utf8(b" #"));
            string::append(&mut token_name,num_str(mint_position));
            string::append(&mut baseuri,string::utf8(b".json"));
        };

        let minted_token = aptos_token::mint_token_object(
            creator,
            candy_data.collection_name,
            candy_data.collection_description,
            token_name,
            baseuri,
            vector::empty<String>(),
            vector::empty<String>(),
            vector::empty()
        );
        object::transfer( creator, minted_token, receiver_addr);
        let fee = (300*mint_price)/10000;
        let collection_owner_price = mint_price - fee;
        coin::transfer<AptosCoin>(receiver, AdminFee, fee);
        coin::transfer<AptosCoin>(receiver, candy_admin, collection_owner_price);
        candy_data.minted=candy_data.minted+1;
        mint_data.total_mints=mint_data.total_mints+1
    }
    public entry fun set_root(account: &signer,candy_obj: address,merkle_root: vector<u8>) acquires CandyMachine,ResourceInfo{
        let account_addr = signer::address_of(account);
        let resource_data = borrow_global<ResourceInfo>(candy_obj);
        assert!(resource_data.source == account_addr, INVALID_SIGNER);
        let candy_data = borrow_global_mut<CandyMachine>(candy_obj);
        candy_data.merkle_root = merkle_root
    }
    public entry fun pause_resume_mint(
        account: &signer,
        candymachine: address,
    )acquires ResourceInfo,CandyMachine{
        let account_addr = signer::address_of(account);
        let resource_data = borrow_global<ResourceInfo>(candymachine);
        assert!(resource_data.source == account_addr, INVALID_SIGNER);
        let candy_data = borrow_global_mut<CandyMachine>(candymachine);
        if(candy_data.paused == true){
            candy_data.paused = false
        }
        else {
            candy_data.paused = true
        }
    }

    public entry fun update_wl_sale_time(
        account: &signer,
        candy_obj: address,
        presale_mint_time: u64
    )acquires CandyMachine,ResourceInfo{
        let account_addr = signer::address_of(account);
        let resource_data = borrow_global<ResourceInfo>(candy_obj);
        let now = aptos_framework::timestamp::now_seconds();
        assert!(resource_data.source == account_addr, INVALID_SIGNER);
        let candy_data = borrow_global_mut<CandyMachine>(candy_obj);
        assert!(presale_mint_time >= now,EINVALID_MINT_TIME);
        candy_data.presale_mint_time = presale_mint_time;
    }

    public entry fun update_public_sale_time(
        account: &signer,
        candy_obj: address,
        public_sale_mint_time: u64
    )acquires CandyMachine,ResourceInfo{
        let account_addr = signer::address_of(account);
        let resource_data = borrow_global<ResourceInfo>(candy_obj);
        let now = aptos_framework::timestamp::now_seconds();
        assert!(resource_data.source == account_addr, INVALID_SIGNER);
        let candy_data = borrow_global_mut<CandyMachine>(candy_obj);
        assert!(public_sale_mint_time >= now,EINVALID_MINT_TIME);
        candy_data.public_sale_mint_time = public_sale_mint_time;
    }

    public entry fun update_public_sale_price(
        account: &signer,
        candy_obj: address,
        public_sale_mint_price: u64
    )acquires CandyMachine,ResourceInfo{
        let account_addr = signer::address_of(account);
        let resource_data = borrow_global<ResourceInfo>(candy_obj);
        let now = aptos_framework::timestamp::now_seconds();
        assert!(resource_data.source == account_addr, INVALID_SIGNER);
        let candy_data = borrow_global_mut<CandyMachine>(candy_obj);
        candy_data.public_sale_mint_price = public_sale_mint_price;
    }

    public entry fun update_wl_sale_price(
        account: &signer,
        candy_obj: address,
        presale_mint_price: u64
    )acquires CandyMachine,ResourceInfo{
        let account_addr = signer::address_of(account);
        let resource_data = borrow_global<ResourceInfo>(candy_obj);
        let now = aptos_framework::timestamp::now_seconds();
        assert!(resource_data.source == account_addr, INVALID_SIGNER);
        let candy_data = borrow_global_mut<CandyMachine>(candy_obj);
        candy_data.presale_mint_price = presale_mint_price;
    }

    public entry fun update_total_supply(
        account: &signer,
        candy_obj: address,
        total_supply: u64
    )acquires CandyMachine,ResourceInfo{
        let account_addr = signer::address_of(account);
        let resource_data = borrow_global<ResourceInfo>(candy_obj);
        assert!(resource_data.source == account_addr, INVALID_SIGNER);
        let candy_data = borrow_global_mut<CandyMachine>(candy_obj);
        candy_data.total_supply =total_supply
    }

    public fun update_royalty<T: key>(
        account: &signer,
        candy_obj: address,
        collection: Object<T>,
        royalty_numerator: u64,
        royalty_denominator: u64,
        payee_address: address,
    )acquires ResourceInfo{
        let account_addr = signer::address_of(account);
        let resource_data = borrow_global<ResourceInfo>(candy_obj);
        assert!(resource_data.source == account_addr, INVALID_SIGNER);
        let resource_signer_from_cap = account::create_signer_with_capability(&resource_data.resource_cap);
        let royalty = royalty::create(royalty_numerator, royalty_denominator, payee_address);
        aptos_token::set_collection_royalties(&resource_signer_from_cap,collection,royalty)
    }
    public fun burn_token<T: key>(
        account: &signer,
        candymachine: address,
        token: Object<T>
    )acquires ResourceInfo
    {
        let account_addr = signer::address_of(account);
        let resource_data = borrow_global<ResourceInfo>(candymachine);
        assert!(resource_data.source == account_addr, INVALID_SIGNER);
        let resource_signer_from_cap = account::create_signer_with_capability(&resource_data.resource_cap);
        aptos_token::burn(&resource_signer_from_cap,token)
    }
    public fun freeze_transfer<T: key>(
        account: &signer,
        candymachine: address,
        token: Object<T>
    )acquires ResourceInfo
    {
        let account_addr = signer::address_of(account);
        let resource_data = borrow_global<ResourceInfo>(candymachine);
        assert!(resource_data.source == account_addr, INVALID_SIGNER);
        let resource_signer_from_cap = account::create_signer_with_capability(&resource_data.resource_cap);
        aptos_token::freeze_transfer(&resource_signer_from_cap,token)
    }
    public fun unfreeze_transfer<T: key>(
        account: &signer,
        candymachine: address,
        token: Object<T>
    )acquires ResourceInfo
    {
        let account_addr = signer::address_of(account);
        let resource_data = borrow_global<ResourceInfo>(candymachine);
        assert!(resource_data.source == account_addr, INVALID_SIGNER);
        let resource_signer_from_cap = account::create_signer_with_capability(&resource_data.resource_cap);
        aptos_token::unfreeze_transfer(&resource_signer_from_cap,token)
    }
    public fun set_description<T: key>(
        account: &signer,
        candymachine: address,
        token: Object<T>,
        description: String
    )acquires ResourceInfo
    {
        let account_addr = signer::address_of(account);
        let resource_data = borrow_global<ResourceInfo>(candymachine);
        assert!(resource_data.source == account_addr, INVALID_SIGNER);
        let resource_signer_from_cap = account::create_signer_with_capability(&resource_data.resource_cap);
        aptos_token::set_description(&resource_signer_from_cap,token,description)
    }
    public fun set_name<T: key>(
        account: &signer,
        candymachine: address,
        token: Object<T>,
        name: String
    )acquires ResourceInfo
    {
        let account_addr = signer::address_of(account);
        let resource_data = borrow_global<ResourceInfo>(candymachine);
        assert!(resource_data.source == account_addr, INVALID_SIGNER);
        let resource_signer_from_cap = account::create_signer_with_capability(&resource_data.resource_cap);
        aptos_token::set_description(&resource_signer_from_cap,token,name)
    }
    public fun set_uri<T: key>(
        account: &signer,
        candymachine: address,
        token: Object<T>,
        uri: String
    )acquires ResourceInfo
    {
        let account_addr = signer::address_of(account);
        let resource_data = borrow_global<ResourceInfo>(candymachine);
        assert!(resource_data.source == account_addr, INVALID_SIGNER);
        let resource_signer_from_cap = account::create_signer_with_capability(&resource_data.resource_cap);
        aptos_token::set_uri(&resource_signer_from_cap,token,uri)
    }
    fun num_str(num: u64): String
    {
        let v1 = vector::empty();
        while (num/10 > 0){
            let rem = num%10;
            vector::push_back(&mut v1, (rem+48 as u8));
            num = num/10;
        };
        vector::push_back(&mut v1, (num+48 as u8));
        vector::reverse(&mut v1);
        string::utf8(v1)
    }
    fun pseudo_random(add:address,remaining:u64):u64
    {
        let x = bcs::to_bytes<address>(&add);
        let y = bcs::to_bytes<u64>(&remaining);
        let z = bcs::to_bytes<u64>(&timestamp::now_seconds());
        vector::append(&mut x,y);
        vector::append(&mut x,z);
        let tmp = hash::sha2_256(x);

        let data = vector<u8>[];
        let i =24;
        while (i < 32)
        {
            let x =vector::borrow(&tmp,i);
            vector::append(&mut data,vector<u8>[*x]);
            i= i+1;
        };
        assert!(remaining>0,999);

        let random = from_bcs::to_u64(data) % remaining + 1;
        random
    }

    fun initialize_whitelist(account: signer){
        move_to(&account, Whitelist {
            minters: bucket_table::new<address, u64>(4),
        })
    }

    fun add_public_minter(candy_data: &mut CandyMachine,receiver_addr: address,candy_obj:address)acquires PublicMinters{
            let public_minters= borrow_global_mut<PublicMinters>(candy_obj);
            if (!bucket_table::contains(&public_minters.minters, &receiver_addr)) {
                    bucket_table::add(&mut public_minters.minters, receiver_addr, candy_data.public_mint_limit);
            };
            // add check for public mint limit
            let public_minters_limit= bucket_table::borrow_mut(&mut public_minters.minters, receiver_addr);
            assert!(*public_minters_limit != 0, MINT_LIMIT_EXCEED);
            *public_minters_limit = *public_minters_limit - 1;
    }
}