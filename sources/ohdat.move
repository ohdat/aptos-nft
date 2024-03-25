
module mint_nft::elevtrix_nft {
    // use std::error;
    use std::string;
    use std::vector;

    use aptos_token::token::{Self, TokenDataId};
    use std::signer;
    use std::string::String;
    use aptos_framework::account::SignerCapability;
    use aptos_framework::resource_account;
    use aptos_framework::account;
    use aptos_framework::event;
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
        collection_name: String,
    }

    // DATA STRUCTURES
    struct ConfigData has key {
        signer_cap: SignerCapability,
        collections:SimpleMap<String,CollectionInfo>,
    } 
    struct CollectionInfo has drop,store {
        collection_name: String,
        royalty_payee_address: address,
        base_uri: String,
        last_mint: u64,
    }

    // ERRORS 
    const ENO_AMOUNT_OUT_OF_RANGE:u64=1;

    /// Action not authorized because the signer is not the admin of this module
    const ENOT_AUTHORIZED: u64 = 1;
    /// The collection minting is expired
    const ECOLLECTION_EXPIRED: u64 = 2;
    /// The collection minting is disabled
    const EMINTING_DISABLED: u64 = 3;

    /// `init_module` is automatically called when publishing the module.
    /// In this function, we create an example NFT collection and an example token.
    fun init_module(resource_signer: &signer) {
        // store the token data id within the module, so we can refer to it later
        // when we're minting the NFT
        let resource_signer_cap = resource_account::retrieve_resource_account_cap(resource_signer, @source_addr);
        move_to(resource_signer, ConfigData {
            signer_cap: resource_signer_cap,
            collections: simple_map::create<String, CollectionInfo>(),
        });
    }


    ///=============

    /// In this function, we create an example NFT collection and an example token.
    public entry fun deploy(_signer: &signer,collection_name:String,description:String) 
    acquires ConfigData
    {
       // This means that the supply of the token will not be tracked.
        let maximum_supply = 0;
        // This variable sets if we want to allow mutation for collection description, uri, and maximum.
        // Here, we are setting all of them to false, which means that we don't allow mutations to any CollectionData fields.
        let mutate_setting = vector<bool>[ false, false, false ];

        let config_data = borrow_global_mut<ConfigData>(@mint_nft);
        let resource_signer = account::create_signer_with_capability(&config_data.signer_cap);
        //todo add base uri to the collection
        let collection_uri = collection_name;
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

    public entry fun mint(receiver: &signer,collection_name: String,amount: u64,price: u64) acquires ConfigData {
        
        let config_data = borrow_global_mut<ConfigData>(@mint_nft);
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
        simple_map::upsert<String,CollectionInfo>(&mut config_data.collections, collection_info.collection_name,CollectionInfo{
            collection_name: collection_info.collection_name,
            base_uri:  collection_info.base_uri,
            royalty_payee_address:collection_info.royalty_payee_address,
            last_mint: mint_position,
        } );

        event::emit(
            Minted{
                receiver: signer::address_of(receiver),
                amount: mint_amout,
                collection_name: collection_name,
            }
        );

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
}
  