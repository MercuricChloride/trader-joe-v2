
# Table of Contents

1.  [Trader Joe Substream](#org87658b2)
    1.  [Constants](#org6af666f)
    2.  [Map Modules](#org61a2d40)
        1.  [Map Events](#org7fb79bb)
    3.  [Store Modules](#org58f5ad7)
        1.  [Store Pairs Created](#org78015d2)
        2.  [Store Ignored Pairs](#org0b39b05)
        3.  [Store Avax Price](#org579bc4a)
        4.  [Token Stores](#orgfbb2059)
    4.  [Sinks](#orgaf1785a)
        1.  [Graph Out](#orgb1a2dc3)
    5.  [Helpers](#org10d697f)
        1.  [get<sub>avax</sub><sub>price</sub><sub>usd</sub>](#orgdc9ba0b)
        2.  [get<sub>token</sub><sub>meta</sub>](#orgf66c2c4)
2.  [FAQ](#org0c31f1b)
    1.  [Why is BLOCK written like that?](#orgfe94826)
    2.  [Whats the deal with \`mfn\` and \`sfn\`?](#orga4fb8bb)
    3.  [How can I figure out what types are available?](#orgdc23d6f)
    4.  [Where are these modules being created?](#orgb7ec278)
    5.  [Where does the schema come from?](#org27a60e2)
    6.  [Where are the config files?](#org3704780)
    7.  [What does it mean when a function is called like foo!()](#org580a10e)
3.  [Language Reference](#org51bf1b8)
    1.  [Built-in Types](#orgca545ac)
        1.  [BLOCK](#org8f61b8d)
        2.  [CLOCK](#orgb92f7ac)
    2.  [ABIS](#orgf4a364a)
        1.  [Extracting Events](#org6678b20)
    3.  [Subgraph Schema](#org289fda0)
    4.  [Macro like functions](#org054389f)
        1.  [Include Examples](#orgc78f9eb)



<a id="org87658b2"></a>

# Trader Joe Substream


<a id="org6af666f"></a>

## Constants

Just some globally available constants we have available

All constants can be accessed in function bodies by reading from the \`global\` module. Like: \`global::foo\` to access a constant called foo.

    const FACTORY_ADDRESS = 0x1886D09C9Ade0c5DB822D85D21678Db67B6c2982;
    const DEX_LENS_ADDRESS = 0x0A5077D8dc51e27Ad536847b0CF558165BA9AD1b;
    const WAVAX_ADDRESS = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;


<a id="org61a2d40"></a>

## Map Modules


<a id="org7fb79bb"></a>

### Map Events

This module is the start of the data pipeline. It takes a block in, and returns a map containing all of the events we are tracking.

    mfn map_events(BLOCK) {
        let lb_factory_events = #{
            pairs_created: lb_factory::LbPairCreated(BLOCK, []),
            flash_loan_fee_set: lb_factory::FlashLoanFeeSet(BLOCK, []),
            fee_param_set: lb_factory::FeeParametersSet(BLOCK, []),
            ignored_pair_changes: lb_factory::LbPairIgnoredStateChanged(BLOCK, []),
        };
    
        let lb_pair_events = #{
            swaps: lb_pair::Swap(BLOCK, []),
        };
    
        #{
            lb_factory: lb_factory_events,
            lb_pair: lb_pair_events,
        }
    }


<a id="org58f5ad7"></a>

## Store Modules


<a id="org78015d2"></a>

### Store Pairs Created

    sfn pair_count(map_events,s:add) {
        let pairs_created = map_events?.lb_factory?.pairs_created ?? [];
    
        for pair in pairs_created {
            s.add("pair_count", 1);
        }
    }


<a id="org0b39b05"></a>

### Store Ignored Pairs

    sfn ignored_pairs(map_events,s:set) {
        let pair_changes = map_events?.lb_factory?.ignored_pair_changes ?? [];
    
        for pair in pair_changes {
            let id = pair.LbPair;
            if pair.ignored {
                s.set(id, true);
            } else {
                s.set(id, false);
            }
        }
    }


<a id="org579bc4a"></a>

### Store Avax Price

    sfn avax_price(map_events,s:set) {
        let swaps = map_events?.lb_pair?.swaps ?? [];
        // todo!
    }


<a id="orgfbb2059"></a>

### Token Stores

There are a number of token fields we need to index, but we don&rsquo;t want to put them into a single store bc it will blow up.

1.  Store Meta

        sfn token_meta(map_events,s:setOnce) {
            let swaps = map_events?.lb_pair?.swaps ?? [];
        
            for swap in swaps {
                let token = swap.tx.address;
                let meta = get_token_meta(token);
                if type_of(meta) != "()" {
                    s.set(token, meta);
                }
            }
        }

2.  Store Numeric

        sfn token_numeric_data(map_events,s:setOnce) {
            let swaps = map_events?.lb_pair?.swaps ?? [];
        
            for swap in swaps {
                let token = swap.tx.address;
                let meta = get_token_meta(token);
                if type_of(meta) != "()" {
                    s.set(token, meta);
                }
            }
        }


<a id="orgaf1785a"></a>

## Sinks


<a id="orgb1a2dc3"></a>

### Graph Out

This module is responsible for outputting to the subgraph.

The way this module works is we have an output array, which is responsible for emitting the entity changes to take in the database. So this module is a lot of not interesting code that just updates entities.

However we do use the helper functions in a weird way here. [See macro like functions for reference.](#org054389f)

1.  Helpers

    This function assumes the following are in scope:
    
    -   \`output\`: A list of the entity changes to take
    -   \`map<sub>events</sub>\`: The output of the map<sub>events</sub> module
    
    1.  create<sub>pair</sub><sub>params</sub>
    
            fn create_pair_params(events) {
                let fees_set = events?.fee_param_set ?? [];
            
                for fee in fees_set {
                    let id = fee.lb_pair;
                    output.push(
                        new LbPairParameterSet id {
                            sender: fee.sender as Address!
                            binStep: fee.bin_step as BigInt!
                            baseFactor: fee.base_factor as BigInt!
                            filterPeriod: fee.filter_period as BigInt!
                            decayPeriod: fee.decay_period as BigInt!
                            reductionFactor: fee.reduction_factor as BigInt!
                            variableFeeControl: fee.variable_fee_control as BigInt!
                            protocolShare: fee.protocol_share as BigInt!
                            maxVolatilityAccumulated: fee.max_volatility_accumulated as BigInt!
                        }
                    );
                }
            }
    
    2.  set<sub>pair</sub><sub>count</sub>
    
        -   \`output\`: A list of the entity changes to take
        
            fn set_pair_count(count) {
                let id = global::FACTORY_ADDRESS;
                output.push(
                    update LbFactory id {
                        pairCount: count as BigInt!
                    }
                );
            }
    
    3.  set<sub>ignored</sub><sub>pairs</sub>
    
        -   \`output\`: A list of the entity changes to take
        
            fn set_ignored_pairs(pairs) {
                for pair in pairs {
                    let id = pair.id;
                    let value = pair.value;
                    output.push(
                            update LbPair id {
                                ignored: value as Bool!
                            }
                    );
                }
            }

2.  Module Code

    The module required to sink to a subgraph.
    Emits a list of entity changes to take in the database.
    
        mfn graph_out(map_events,pair_count:get,ignored_pairs:deltas) {
            let output = [];
        
            let count = pair_count.get("pair_count");
            set_pair_count!(count);
        
            create_pair_params!(map_events?.lb_factory);
        
            let pair_changes = ignored_pairs.deltas.map(|e| #{ ignored: e.newValue, id: e.key });
            set_ignored_pairs(pair_changes);
        
            return output;
        }


<a id="org10d697f"></a>

## Helpers


<a id="orgdc9ba0b"></a>

### get<sub>avax</sub><sub>price</sub><sub>usd</sub>

    fn get_avax_price_usd(token) {
        let price = dex_lens::getTokenPriceNative(global::DEX_LENS,token) ?? 0;
    
        if type_of(price) == "BigInt" {
            // parse_units works like in Ethers.js
            return parse_units(price, 18);
        } else {
            return price;
        }
    }


<a id="orgf66c2c4"></a>

### get<sub>token</sub><sub>meta</sub>

Makes the RPC calls 🤢 to get the token data. Slow! But at least it&rsquo;s only once.

    fn get_token_meta(token) {
        let symbol = erc20::symbol(token) ?? "";
        let name = erc20::name(token) ?? "";
        let decimals = erc20::decimals(token) ?? 0;
        let totalSupply = erc20::totalSupply(token) ?? 0;
    
        #{
            name: name,
            symbol: symbol,
            decimals: decimals,
            totalSupply: totalSupply
        }
    }


<a id="org0c31f1b"></a>

# FAQ

This area contains questions and answers for them.


<a id="orgfe94826"></a>

## Why is BLOCK written like that?

It&rsquo;s because it&rsquo;s a built in type. So we visually want it to look distinct!
[See: Built-in Types](#orgca545ac)


<a id="orga4fb8bb"></a>

## Whats the deal with \`mfn\` and \`sfn\`?

The reason is that I feel it&rsquo;s the simplest syntax to describe what that thing is, without being &ldquo;magical&rdquo;.

Modules in substreams are super similar to functions, however they are not exactly the same. So we have syntax that reflects this, mfn and sfn is similar to fn. However it tells us that this function is a Map module (mfn) or a Store module (sfn).


<a id="orgdc23d6f"></a>

## How can I figure out what types are available?

[See: Built-in Types](#orgca545ac)


<a id="orgb7ec278"></a>

## Where are these modules being created?

[See: ABIS](#orgf4a364a)


<a id="org27a60e2"></a>

## Where does the schema come from?

[See: Subgraph Schema](#org289fda0)


<a id="org3704780"></a>

## Where are the config files?

With Streamline, one design goal is to avoid writing needless config files. This is because config files:

1.  Are often not needed
    
    We can do a lot of what a config file is doing by just analyzing the source code directly. In Streamline, we automate as much of these steps as possible, without sacrificing expressivity.

2.  Config files can get out of sync with your written program and introduce bugs.
    
    By having our configuration be a function of our source program, we can eliminate an entire class of bugs that stem from mismatches between configuration files and their usage. This means you will never have your subgraph blow up because you used a field that doesn&rsquo;t exist, or was spelled wrong in your program.

3.  Force you to define your program before it&rsquo;s done
    
    This is a stylistic choice, but personally when I am doing something difficult. The program I am building grows from an initial idea, and changes quite a bit during the development process.
    As such I think that good tools allow you to figure out what you are building dynamically. Which is why I have chosen to build this as a feature of the language.


<a id="org580a10e"></a>

## What does it mean when a function is called like foo!()

[See: Macro like functions](#org054389f)


<a id="org51bf1b8"></a>

# Language Reference


<a id="orgca545ac"></a>

## Built-in Types

Streamline has some built in types, these are some of them!


<a id="org8f61b8d"></a>

### BLOCK

This represents a literal ethereum block. This is the source of most substreams.

1.  Methods:

        // Returns the Block Number
        fn number(self) -> uint;
        // Returns a list of the logs in the block
        fn logs(self) -> Log[]


<a id="orgb92f7ac"></a>

### CLOCK

This represents a clock. It&rsquo;s pretty cool.

1.  Methods:


<a id="orgf4a364a"></a>

## ABIS

By default, Streamline looks for a \`./abis/\` directory to load in the files from.

If they are found, they are automatically included in the runtime. This adds almost no runtime overhead because of how the rhai interpreter works. However it does slow down compilation a bit.

For each of the abis found in the abi dir, there is a new globally available module created. Read for the contents of the module.


<a id="org6678b20"></a>

### Extracting Events

For each event in the abi json, a function is defined with the same name that allows for us to extract the events of that type from a block.

The signature looks like:

    fn <EVENT_NAME>(BLOCK) -> Event[]
    fn <EVENT_NAME>(BLOCK, ADDRESS_LIST) -> Event[]

Params:

-   Block: An Ethereum Block
-   ADDRESS<sub>LIST</sub>: A list of addresses to extract events from. If it is empty, skip filtering and grab all matching events of that type, regardless of the emitting address.

Optionally, you can also call this function with a single param of the block. This does the same thing as calling the function with an empty address list.


<a id="org289fda0"></a>

## Subgraph Schema

The subgraph schema is dynamically generated from the usage of the entity syntax.

This might seem kind of weird because it is very different. And you don&rsquo;t have to use this feature if you don&rsquo;t want to. But it does unlock a lot nice things that make me suggest it, as well as eliminate an entire class of annoying bugs.

[See: Where are the config files?](#org3704780)


<a id="org054389f"></a>

## Macro like functions

Most of the time, streamline functions are pure. Meaning they have no side effects. But we can modify how functions operate by calling them with a bang at the end. We visually show this with the ! syntax.

What this does is calls the function, with the scope of the caller.

This means that any function can modify and mutate values that are present where we are calling the function from.

We refer to these are macro like functions, because they operate as though the function body was expanded inline to where it was called.

<span class="underline">!!!THIS IS A TERRIBLE IDEA IN ALMOST EVERY SITUATION!!!</span>

The one exception I have found is to manage complexity in the graph<sub>out</sub> function.

We need to modify a single array called \`outputs\`, and as such it&rsquo;s nice to have access to that directly, and not have to pass a setter or something.

So please think twice before using this feature! You have been warned!


<a id="orgc78f9eb"></a>

### TODO Include Examples

