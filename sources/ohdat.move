
module mint_nft::elevtrix_nft {
    // use std::error;
    use std::string;
    use std::vector;
    use std::error;
    use aptos_token::token::{Self, TokenDataId};
    use std::signer;
    use std::string::String;
    use aptos_framework::account::SignerCapability;
    use aptos_framework::resource_account;
    use aptos_framework::account;
    use aptos_framework::event;
    use aptos_std::ed25519;
    use aptos_std::ed25519::ValidatedPublicKey;
    use aptos_std::simple_map::{Self, SimpleMap};
    #[test_only]
    use aptos_std::debug;

    use aptos_framework::coin::{Self};
    use aptos_framework::aptos_coin::AptosCoin;
    #[event]
    struct CollectionCreated has drop, store {
        creator: address,
        name: String,
    }
    #[event]
    struct TokenMinted has drop, store {
        receiver: address,
        token_data_id: TokenDataId,
    }
    #[event]
    struct Minted has drop, store {
        receiver: address,
        amount: u64,
        start_token_id: u64,
        mint_type: u64,
        collection_name: String,
    }

    // DATA STRUCTURES
    struct ConfigData has key {
        signer_cap: SignerCapability,
        collections:SimpleMap<String,CollectionInfo>,
        public_key: ed25519::ValidatedPublicKey,
        base_uri: String,
    } 
    struct CollectionInfo has drop,store {
        collection_name: String,
        royalty_payee_address: address,
        base_uri: String,
        last_mint: u64,
    }

    // This struct stores the challenge message that proves that the resource signer wants to mint this token
    // to the receiver. This struct will need to be signed by the resource signer to pass the verification.
    struct DeployChallenge has drop {
        receiver: address,
        collection_name: String,
    }

    struct MintProofChallenge has drop {
        receiver: address,
        collection_name: String,
        price: u64,
        amount: u64,
        max_count: u64,
        allow_mint_count: u64,
        mint_type: u64,
        nonce: String,
    }


    // ERRORS 

    /// Action not authorized because the signer is not the admin of this module
    const ENOT_AUTHORIZED: u64 = 1;
    /// The collection minting is expired
    const ECOLLECTION_EXPIRED: u64 = 2;
    /// The collection minting is disabled
    const EMINTING_DISABLED: u64 = 3;
    /// Specified proof of knowledge required to prove ownership of a public key is invalid
    const EINVALID_PROOF_OF_KNOWLEDGE: u64 = 4;
    const E_PUBLIC_KEY_NOT_SIGNER : u64 = 5;

    /// `init_module` is automatically called when publishing the module.
    /// In this function, we create an example NFT collection and an example token.
    fun init_module(resource_signer: &signer) {
        // store the token data id within the module, so we can refer to it later
        // when we're minting the NFT
        let resource_signer_cap = resource_account::retrieve_resource_account_cap(resource_signer, @source_addr);

        // hardcoded public key - we will update it to the real one by calling `set_public_key` from the admin account
        let pk_bytes = x"c2b321b74cd43d3b5de2ced01a247b93ad7811a6d2173743dbaef99d08e3a07c";
        let public_key = std::option::extract(&mut ed25519::new_validated_public_key_from_bytes(pk_bytes));
        move_to(resource_signer, ConfigData {
            public_key,
            signer_cap: resource_signer_cap,
            collections: simple_map::create<String, CollectionInfo>(),
            base_uri: string::utf8(b"https://creator.dev.catgpt.chat/v1/token/"),
        });
    }

    ///=============

    /// In this function, we create an example NFT collection and an example token.
    public entry fun deploy(_signer: &signer,collection_name:String,description:String,_signature: vector<u8>) 
    acquires ConfigData
    {
        let config_data = borrow_global_mut<ConfigData>(@mint_nft);
        // Verify the signature of the deployer
        // verify_of_deploy(signer::address_of(_signer), collection_name, _signature, config_data.public_key);
       // This means that the supply of the token will not be tracked.
        let maximum_supply = 0;
        // This variable sets if we want to allow mutation for collection description, uri, and maximum.
        // Here, we are setting all of them to false, which means that we don't allow mutations to any CollectionData fields.
        let mutate_setting = vector<bool>[ false, false, false ];
        let resource_signer = account::create_signer_with_capability(&config_data.signer_cap);
        //todo add base uri to the collection
        let collection_uri = config_data.base_uri;
        string::append(&mut collection_uri,collection_name);
        // Create the nft collection.
        token::create_collection(&resource_signer, collection_name, description, collection_uri, maximum_supply, mutate_setting);
        simple_map::add<String, CollectionInfo>(&mut config_data.collections, collection_name, CollectionInfo{
            collection_name: collection_name,
            base_uri: collection_uri,
            royalty_payee_address: signer::address_of(_signer),
            last_mint: 0,
        });
        event::emit(
            CollectionCreated{
                creator: signer::address_of(_signer),
                name: collection_name,
            }
        );        
    }

    public entry fun mint(receiver: &signer,collection_name: String,amount: u64,price: u64,max_count:u64,allow_mint_count:u64,mint_type:u64,nonce:String,_signature: vector<u8>) acquires ConfigData {
        let config_data = borrow_global_mut<ConfigData>(@mint_nft);

        // verify_of_mint(signer::address_of(receiver), collection_name, price, amount, max_count, allow_mint_count, mint_type, nonce, _signature, config_data.public_key);

        let collection_info = simple_map::borrow(&mut config_data.collections, &collection_name);
        // exists!(token_data_id, error::from_code(1));
        let resource_signer = account::create_signer_with_capability(&config_data.signer_cap);
        let mint_position = collection_info.last_mint;
        // Mint token to the receiver.
        let total_amount = price * amount * 10000000;
        coin::transfer<AptosCoin>(receiver,collection_info.royalty_payee_address , total_amount); 
        let mint_amout = amount;
        while (amount > 0) {
          
            mint_position = mint_position + 1;
            let token_name = collection_name;
            let token_uri = collection_info.base_uri;
            string::append(&mut token_name,string::utf8(b" #"));
            string::append(&mut token_name,num2str(mint_position));
            string::append(&mut token_uri,string::utf8(b"/")); 
            string::append(&mut token_uri,num2str(mint_position)); 
            let token_data_id = token::create_tokendata(
                &resource_signer,
                collection_name,
                token_name,
                string::utf8(b""),
                0,
                token_uri,
                collection_info.royalty_payee_address,
                1,
                0,
                // This variable sets if we want to allow mutation for token maximum, uri, royalty, description, and properties.
                // Here we enable mutation for properties by setting the last boolean in the vector to true.
                token::create_token_mutability_config(
                    &vector<bool>[ false, false, false, false, true ]
                ),
                // We can use property maps to record attributes related to the token.
                // In this example, we are using it to record the receiver's address.
                // We will mutate this field to record the user's address
                // when a user successfully mints a token in the `mint_nft()` function.
                vector<String>[string::utf8(b"given_to")],
                vector<vector<u8>>[b""],
                vector<String>[ string::utf8(b"address") ],
            );

            let token_id =token::mint_token(&resource_signer, token_data_id, 1);
            token::direct_transfer(&resource_signer, receiver, token_id, 1);
            amount = amount - 1;
            event::emit(
                TokenMinted{
                    receiver: signer::address_of(receiver),
                    token_data_id: token_data_id,
                }
            );
        };
          event::emit(
            Minted{
                receiver: signer::address_of(receiver),
                amount: mint_amout,
                mint_type: mint_type,
                collection_name: collection_name,
                start_token_id: collection_info.last_mint + 1,
            }
        );

        simple_map::upsert<String,CollectionInfo>(&mut config_data.collections, collection_info.collection_name,CollectionInfo{
            collection_name: collection_info.collection_name,
            base_uri:  collection_info.base_uri,
            royalty_payee_address:collection_info.royalty_payee_address,
            last_mint: mint_position,
        } );

      

    }
    fun num2str(num: u64): String
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

  /// Set the public key of this minting contract
    public entry fun set_public_key(caller: &signer, pk_bytes: vector<u8>) acquires ConfigData {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        let module_data = borrow_global_mut<ConfigData>(@mint_nft);
        module_data.public_key = std::option::extract(&mut ed25519::new_validated_public_key_from_bytes(pk_bytes));
    }

    public entry fun set_base_url(caller: &signer, url: String) acquires ConfigData {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        let module_data = borrow_global_mut<ConfigData>(@mint_nft);
        module_data.base_uri = url;
    }

     entry fun testclaim(
        receiver: &signer,
        collection_name: String,
        sender_public_key_bytes: vector<u8>,
        signature_bytes: vector<u8>
    )  {
        let receiver_address = signer::address_of(receiver);
        // Verify that the public key bytes, match the onchcain authentication key
        let public_key = ed25519::new_unvalidated_public_key_from_bytes(sender_public_key_bytes);
        // let authentication_key = ed25519::unvalidated_public_key_to_authentication_key(&public_key);
        // let sender_auth_key = account::get_authentication_key(sender);
        // assert!(sender_auth_key == authentication_key, error::unauthenticated(E_PUBLIC_KEY_NOT_SIGNER));

        // Verify signature
       let deploy_challenge = DeployChallenge {
            collection_name: collection_name,
            receiver: receiver_address,
        };
        let signature = ed25519::new_signature_from_bytes(signature_bytes);
        assert!(
            ed25519::signature_verify_strict_t(&signature, &public_key, deploy_challenge),
            std::error::invalid_argument(EINVALID_PROOF_OF_KNOWLEDGE)
        );
    }


    /// Verify that the collection token minter intends to mint the given token_data_id to the receiver
    fun verify_of_deploy(
        receiver_addr: address,
        collection_name: String,
        deploy_signature: vector<u8>,
        public_key: ValidatedPublicKey
    ) {
        // let sequence_number = account::get_sequence_number(receiver_addr);
        let deploy_challenge = DeployChallenge {
            collection_name: collection_name,
            receiver: receiver_addr,
        };

        let signature = ed25519::new_signature_from_bytes(deploy_signature);
        let unvalidated_public_key = ed25519::public_key_to_unvalidated(&public_key);
        assert!(
            ed25519::signature_verify_strict_t(&signature, &unvalidated_public_key, deploy_challenge),
            error::invalid_argument(EINVALID_PROOF_OF_KNOWLEDGE)
        );
    }


    fun verify_of_mint(
        receiver_addr: address,
        collection_name: String,
        price: u64,
        amount: u64,
        max_count: u64,
        allow_mint_count: u64,
        mint_type: u64,
        nonce: String,
        mint_signature: vector<u8>,
        public_key: ValidatedPublicKey
    ) {
        let mint_proof_challenge = MintProofChallenge {
            receiver: receiver_addr,
            collection_name: collection_name,
            price: price,
            amount: amount,
            max_count: max_count,
            allow_mint_count: allow_mint_count,
            mint_type: mint_type,
            nonce: nonce,
        };
        let signature = ed25519::new_signature_from_bytes(mint_signature);
        let unvalidated_public_key = ed25519::public_key_to_unvalidated(&public_key);
        assert!(
            ed25519::signature_verify_strict_t(&signature, &unvalidated_public_key, mint_proof_challenge),
            error::invalid_argument(EINVALID_PROOF_OF_KNOWLEDGE)
        );
    }

    ){

    }


    // test 7890
      #[test (
        origin_account = @0xcafe,
        resource_account = @0xc3bb8488ab1a5815a9d543d7e41b0e0df46a7396f89b22821f07a4362f75ddc5,
        admin = @admin_addr,
        nft_receiver = @0x123,
        aptos_framework = @aptos_framework
    )]
    #[expected_failure(abort_code = 0x50002, location = mint_nft::elevtrix_nft)]
    public entry fun test_update_expiration_time(
        origin_account: signer,
        resource_account: signer,
        admin: signer,
        nft_receiver: signer,
        aptos_framework: signer
    )  {
        let (admin_sk, admin_pk) = ed25519::generate_keys();
        debug::print(&admin_pk);
        debug::print(&admin_sk);
        // debug::print("admin_sk: ", ed25519::private_key_to_bytes(&admin_sk));
        // set_up_test(origin_account, &resource_account, &admin_pk, aptos_framework, &nft_receiver, 10);
        let receiver_addr = signer::address_of(&nft_receiver);
        let proof_challenge = MintProofChallenge {
            receiver_account_sequence_number: 0,
            // receiver_account_address: receiver_addr,
            // token_data_id: borrow_global<ModuleData>(@mint_nft).token_data_id,
        };

        let sig = ed25519::sign_struct(&admin_sk, proof_challenge);
                debug::print(&sig);

        // debug::print( ed25519::signature_to_bytes(&sig));
        // set the expiration time of the minting to be earlier than the current time
    }

}
  