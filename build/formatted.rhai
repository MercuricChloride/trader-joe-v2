const FACTORY_ADDRESS = address("0x1886D09C9Ade0c5DB822D85D21678Db67B6c2982");
const DEX_LENS_ADDRESS = address("0x0A5077D8dc51e27Ad536847b0CF558165BA9AD1b");
const WAVAX_ADDRESS = address("0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c");

fn map_events(BLOCK) {
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

fn pair_count(map_events,s) {
    let pairs_created = map_events?.lb_factory?.pairs_created ?? [];

    for pair in pairs_created {
        s.add("pair_count", 1);
    }
}

fn ignored_pairs(map_events,s) {
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

fn avax_price(map_events,s) {
    let swaps = map_events?.lb_pair?.swaps ?? [];
    // todo!
}

fn token_meta(map_events,s) {
    let swaps = map_events?.lb_pair?.swaps ?? [];

    for swap in swaps {
        let token = swap.tx.address;
        let meta = get_token_meta(token);
        if type_of(meta) != "()" {
            s.set(token, meta);
        }
    }
}

fn token_numeric_data(map_events,s) {
    let swaps = map_events?.lb_pair?.swaps ?? [];

    for swap in swaps {
        let token = swap.tx.address;
        let meta = get_token_meta(token);
        if type_of(meta) != "()" {
            s.set(token, meta);
        }
    }
}

fn create_pair_params(events) {
    let fees_set = events?.fee_param_set ?? [];

    for fee in fees_set {
        let id = fee.lb_pair;
        output.push(
create_entity("LbPairParameterSet", id, [
  field_change("sender", fee.sender, "Address!"),
  field_change("binStep", fee.bin_step, "BigInt!"),
  field_change("baseFactor", fee.base_factor, "BigInt!"),
  field_change("filterPeriod", fee.filter_period, "BigInt!"),
  field_change("decayPeriod", fee.decay_period, "BigInt!"),
  field_change("reductionFactor", fee.reduction_factor, "BigInt!"),
  field_change("variableFeeControl", fee.variable_fee_control, "BigInt!"),
  field_change("protocolShare", fee.protocol_share, "BigInt!"),
  field_change("maxVolatilityAccumulated", fee.max_volatility_accumulated, "BigInt!"),
])
        );
    }
}

fn set_pair_count(count) {
    let id = global::FACTORY_ADDRESS;
    output.push(
update_entity("LbFactory", id, [
  field_change("pairCount", count, "BigInt!"),
])
    );
}

fn set_ignored_pairs(pairs) {
    for pair in pairs {
        let id = pair.id;
        let value = pair.value;
        output.push(
update_entity("LbPair", id, [
  field_change("ignored", value, "Bool!"),
])
        );
    }
}

fn graph_out(map_events,pair_count,ignored_pairs) {
    let output = [];

    let count = pair_count.get("pair_count");
    set_pair_count!(count);

    create_pair_params!(map_events?.lb_factory);

    let pair_changes = ignored_pairs.deltas.map(|e| #{ ignored: e.newValue, id: e.key });
    set_ignored_pairs(pair_changes);

    return output;
}

fn get_avax_price_usd(token) {
    let price = dex_lens::getTokenPriceNative(global::DEX_LENS,token) ?? 0;

    if type_of(price) == "BigInt" {
        // parse_units works like in Ethers.js
        return parse_units(price, 18);
    } else {
        return price;
    }
}

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
if in_repl() {

  add_mfn("map_events", ["BLOCK"]);

  add_sfn("pair_count", ["map_events","s:add"]);

  add_sfn("ignored_pairs", ["map_events","s:set"]);

  add_sfn("avax_price", ["map_events","s:set"]);

  add_sfn("token_meta", ["map_events","s:setOnce"]);

  add_sfn("token_numeric_data", ["map_events","s:setOnce"]);

  add_mfn("graph_out", ["map_events","pair_count:get","ignored_pairs:deltas"]);
}
if in_repl() {generate_yaml("/home/goose/workdir/streamline/streamline-template-repository/streamline.yaml");generate_rust("/home/goose/workdir/streamline/streamline-template-repository/src/streamline.rs");}
